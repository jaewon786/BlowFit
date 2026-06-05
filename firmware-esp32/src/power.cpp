// Power management — Deep sleep + 외부 전원 버튼.

#include "power.h"
#include "config.h"
#include "session.h"
#include "haptic.h"

#include <Arduino.h>
#include <esp_sleep.h>

namespace power {

namespace {

  // long-press 감지 상태.
  uint32_t g_boot_press_start_ms = 0;  // BOOT 버튼 누름 시작 시점 (0 = not pressed)
  bool     g_boot_long_fired     = false;  // 한 번 fire 후 release 까지 무시

  // PWR_BUTTON (외부, PB61412L) — long-press(deep sleep) + short-press(훈련 시작).
  uint32_t g_pwr_press_start_ms = 0;      // 누름 시작 시점 (0 = not pressed)
  bool     g_pwr_long_fired     = false;  // long-press fire 후 release 까지 무시
  constexpr uint32_t PWR_DEBOUNCE_MS = 30;  // short-press 최소 유지 (노이즈 무시)

  bool     g_woke_from_button   = false;  // 이번 부팅이 EXT1(버튼) wake 인지

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

  /// 전원 버튼만 wake 소스로 EXT1 재등록 후 즉시 deep sleep (wakeGate 중단용).
  /// 버튼이 떼진(HIGH) 상태에서만 호출해야 즉시 재-wake 안 됨.
  [[noreturn]] void reSleep() {
    esp_sleep_enable_ext1_wakeup(1ULL << pins::PWR_BUTTON, ESP_EXT1_WAKEUP_ANY_LOW);
    Serial.flush();
    delay(50);
    esp_deep_sleep_start();
    while (true) { delay(1000); }
  }

}  // anonymous namespace

void wakeGate() {
  // deep sleep 에서 EXT1(전원 버튼)로 깨어난 경우만 게이트 적용.
  if (esp_sleep_get_wakeup_cause() != ESP_SLEEP_WAKEUP_EXT1) {
    g_woke_from_button = false;
    return;  // 정상 부팅 (USB/RST) — 그대로 진행.
  }
  g_woke_from_button = true;

  // 전원 버튼을 WAKE_HOLD_MS(3초) 연속으로 눌러야 부팅 진행.
  pinMode(pins::PWR_BUTTON, INPUT_PULLUP);
  delay(10);  // 핀 안정화
  Serial.println("[power] EXT1 wake — hold PWR button 3s to power on...");
  const uint32_t start = millis();
  while (millis() - start < WAKE_HOLD_MS) {
    if (digitalRead(pins::PWR_BUTTON) != LOW) {
      // 3초 전에 뗌 → 켜지 않고 다시 deep sleep.
      Serial.println("[power] released < 3s -> back to deep sleep");
      reSleep();  // [[noreturn]]
    }
    delay(10);
  }
  Serial.println("[power] hold confirmed (3s) -> powering on");

  // 이후 로직(tick 의 short/long 감지)이 깨끗한 상태에서 시작하도록 release 대기.
  while (digitalRead(pins::PWR_BUTTON) == LOW) {
    delay(10);
  }
}

bool wokeFromButton() { return g_woke_from_button; }

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

  // ---------- 외부 PWR_BUTTON (PB61412L) ----------
  // 짧게 누름(뗄 때) → 훈련 시작. 길게 3초 → deep sleep (끄기).
  const bool pwr_pressed = (digitalRead(pins::PWR_BUTTON) == LOW);
  if (pwr_pressed) {
    if (g_pwr_press_start_ms == 0) {
      g_pwr_press_start_ms = now_ms;
    } else if (!g_pwr_long_fired &&
               (now_ms - g_pwr_press_start_ms >= PWR_LONG_PRESS_MS)) {
      g_pwr_long_fired = true;
      Serial.println("[power] PWR_BUTTON long-press (3s) -> deep sleep");
      enterDeepSleep();   // [[noreturn]]
    }
  } else {
    // 떼는 순간 — long press 가 아니었고 debounce 이상 눌렸으면 short = 훈련 시작.
    if (g_pwr_press_start_ms != 0 && !g_pwr_long_fired &&
        (now_ms - g_pwr_press_start_ms >= PWR_DEBOUNCE_MS)) {
      Serial.println("[power] PWR_BUTTON short-press -> startSession");
      session::startSession();  // Standby/Summary 에서만 동작 (내부 가드)
    }
    g_pwr_press_start_ms = 0;
    g_pwr_long_fired = false;
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

  // 3-1. 전원 꺼짐 진동 + 재생 시간 확보 (sleep 전이라 blocking delay OK).
  haptic::play(haptic::POWER_OFF);
  delay(1000);

  // 4. 버튼을 누른 채 sleep 하면 EXT1 조건이 이미 충족돼 즉시 다시 깨어남.
  //    → 전원/BOOT 버튼이 모두 떼질(HIGH) 때까지 대기 후 sleep.
  while (digitalRead(pins::PWR_BUTTON) == LOW ||
         digitalRead(pins::BUTTON_BOOT) == LOW) {
    delay(10);
  }
  delay(50);  // debounce

  // 5. EXT1 wakeup 등록 — 전원 버튼만 wake 소스. 실제 wake 여부는 wakeGate()
  //    에서 3초 hold 로 게이트. (BOOT 는 wake 소스에서 제외.)
  esp_sleep_enable_ext1_wakeup(1ULL << pins::PWR_BUTTON, ESP_EXT1_WAKEUP_ANY_LOW);

  // 6. 시리얼 flush + 잠시 대기.
  Serial.println("[power] entering deep sleep now (zzz)");
  Serial.flush();
  delay(50);

  // 7. Deep sleep 진입 — 이 함수는 return 안 함.
  esp_deep_sleep_start();

  // unreachable
  while (true) { delay(1000); }
}

}  // namespace power
