// Power management — Deep sleep + 외부 전원 버튼.

#include "power.h"
#include "config.h"
#include "session.h"

#include <Arduino.h>
#include <esp_sleep.h>

namespace power {

namespace {

  // long-press 감지 상태.
  uint32_t g_boot_press_start_ms = 0;  // BOOT 버튼 누름 시작 시점 (0 = not pressed)
  bool     g_boot_long_fired     = false;  // 한 번 fire 후 release 까지 무시

  // PWR_BUTTON (외부, ETP164L) — debounce + falling edge 감지.
  bool     g_pwr_last_raw     = HIGH;
  bool     g_pwr_stable       = HIGH;
  uint32_t g_pwr_last_change  = 0;
  constexpr uint32_t PWR_DEBOUNCE_MS = 30;

  /// Wakeup reason 시리얼 출력.
  void printWakeupReason() {
    const esp_sleep_wakeup_cause_t reason = esp_sleep_get_wakeup_cause();
    switch (reason) {
      case ESP_SLEEP_WAKEUP_EXT0:
        Serial.println("[power] wakeup: EXT0 button");
        break;
      case ESP_SLEEP_WAKEUP_EXT1:
        Serial.println("[power] wakeup: EXT1 button mask");
        break;
      case ESP_SLEEP_WAKEUP_TIMER:
        Serial.println("[power] wakeup: TIMER");
        break;
      case ESP_SLEEP_WAKEUP_UNDEFINED:
      default:
        Serial.println("[power] wakeup: normal boot (power-on or RST)");
        break;
    }
  }

}  // anonymous namespace

void begin() {
  printWakeupReason();

  // 외부 전원 버튼 + LED 핀 설정.
  pinMode(pins::PWR_BUTTON, INPUT_PULLUP);
  pinMode(pins::PWR_LED, OUTPUT);
  digitalWrite(pins::PWR_LED, HIGH);  // ON 상태 표시
  Serial.printf("[power] PWR_LED ON (GPIO%u), PWR_BUTTON ready (GPIO%u)\n",
                (unsigned)pins::PWR_LED, (unsigned)pins::PWR_BUTTON);
}

void tick(uint32_t now_ms) {
  // ---------- BOOT 버튼 long-press 감지 (2초) ----------
  // BOOT 버튼은 short-press 가 startSession (main.cpp 의 btn 핸들러).
  // long-press 만 deep sleep 트리거. main.cpp 의 short edge detection 과
  // 충돌 없도록 raw read 만 사용 (debounced state 불필요).
  const bool boot_pressed = (digitalRead(pins::BUTTON_BOOT) == LOW);
  if (boot_pressed) {
    if (g_boot_press_start_ms == 0) {
      g_boot_press_start_ms = now_ms;
    } else if (!g_boot_long_fired &&
               (now_ms - g_boot_press_start_ms >= LONG_PRESS_MS)) {
      g_boot_long_fired = true;
      Serial.println("[power] BOOT long-press detected -> deep sleep");
      enterDeepSleep();   // [[noreturn]]
    }
  } else {
    g_boot_press_start_ms = 0;
    g_boot_long_fired = false;
  }

  // ---------- 외부 PWR_BUTTON short-press 감지 (debounced) ----------
  // ETP164L 같은 외부 tact 버튼. short-press 만으로 deep sleep (켜고 끄기).
  const bool pwr_raw = (digitalRead(pins::PWR_BUTTON) == LOW);
  if (pwr_raw != g_pwr_last_raw) {
    g_pwr_last_raw = pwr_raw;
    g_pwr_last_change = now_ms;
  }
  if ((now_ms - g_pwr_last_change >= PWR_DEBOUNCE_MS) &&
      g_pwr_stable != pwr_raw) {
    g_pwr_stable = pwr_raw;
    if (pwr_raw) {  // falling edge (press)
      Serial.println("[power] PWR_BUTTON pressed -> deep sleep");
      enterDeepSleep();   // [[noreturn]]
    }
  }
}

[[noreturn]] void enterDeepSleep() {
  Serial.println("[power] preparing for deep sleep...");

  // 1. 진행 중 session 정리 — Summary 단계 거치지 않고 즉시 Standby 로.
  session::stopSession();

  // 2. PWR_LED OFF — 시각적 OFF 표시.
  digitalWrite(pins::PWR_LED, LOW);

  // 3. 디스플레이 LDO OFF — 화면 즉시 어두워짐.
  digitalWrite(pins::TFT_POWER_ON, LOW);

  // 4. EXT0 wakeup 등록 — BOOT 버튼 또는 PWR_BUTTON 누름 시 wakeup.
  // ESP32-S3 의 EXT0 는 단일 GPIO 만 가능. 두 버튼 둘 다 사용하려면 EXT1
  // (mask) 사용. 우리 케이스 — PWR_BUTTON 우선 (외부 케이스에 노출되는
  // 메인 버튼). BOOT 도 같이 등록하려면 EXT1.
  const uint64_t wake_mask = (1ULL << pins::PWR_BUTTON) |
                             (1ULL << pins::BUTTON_BOOT);
  esp_sleep_enable_ext1_wakeup(wake_mask, ESP_EXT1_WAKEUP_ALL_LOW);

  // 5. 시리얼 flush + 잠시 대기.
  Serial.println("[power] entering deep sleep now (zzz)");
  Serial.flush();
  delay(50);

  // 6. Deep sleep 진입 — 이 함수는 return 안 함.
  esp_deep_sleep_start();

  // unreachable
  while (true) { delay(1000); }
}

}  // namespace power
