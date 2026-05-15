// BlowFit v4.0 펌웨어 — M2 milestone (LVGL 통합).
//
// 이 단계 (M2) 의 목표:
//   - lvgl_port 모듈로 LVGL <-> TFT_eSPI 결합
//   - 더블 버퍼링 (PSRAM 우선) + 60FPS 목표
//   - "BlowFit v4.0 / Hello LVGL" 라벨 위젯 표시
//   - 실시간 압력값을 LVGL label 로 갱신 (5Hz)
//   - 우상단 LVGL perf monitor (FPS / CPU%) 표시
//
// 다음 단계 (M3): 한글 폰트 (Pretendard subset) + theme tokens + screen 모듈화.

#include <Arduino.h>
#include <lvgl.h>

#include "config.h"
#include "sensor.h"
#include "display/lvgl_port.h"
#include "display/theme.h"
#include "display/screens/screen_standby.h"
#include "display/screens/screen_training.h"

// ----- 전역 상태 -----

// 간이 state machine — M7 의 정식 state_machine 도입 전까지의 placeholder.
// boot 후 standby 화면, 영점 보정 끝나면 일정 시간 후 자동으로 training 화면.
enum class AppPhase : uint8_t { Standby, Training };
static AppPhase g_app_phase = AppPhase::Standby;
static uint32_t g_phase_started_ms = 0;

// Training 화면 데모용 — 호기/흡기 turn 30s 씩 사이클.
constexpr uint32_t TURN_EXHALE_MS = 30000;
constexpr uint32_t TURN_INHALE_MS = 30000;
constexpr uint32_t CYCLE_MS = TURN_EXHALE_MS + TURN_INHALE_MS;

// ----- 시리얼 + 디스플레이 전원 부트 보조 -----
static void bootHardware() {
#if HAS_DISPLAY
  // LDO 전원 enable (GPIO15 HIGH) — 배터리 모드 필수.
  pinMode(pins::TFT_POWER_ON, OUTPUT);
  digitalWrite(pins::TFT_POWER_ON, HIGH);
  delay(50);  // LDO 안정화 대기
#endif
}

// ----- LVGL 초기 화면 빌드 -----
// buildHelloScreen() 는 M3 까지의 데모 화면. M4 부터는 screens/screen_standby
// 가 담당. 이 함수는 호출하지 않음 (삭제 대신 reference 로 history 유지하려면
// 별도 archive). 현재는 제거.

// ----- Setup -----
void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println();
  Serial.println("=========================================");
  Serial.println("BlowFit v4.0 - ESP32-S3 / T-Display S3");
  Serial.println("Build: " __DATE__ " " __TIME__);
  Serial.println("M2: LVGL integration");
  Serial.println("=========================================");

  bootHardware();

#if HAS_LVGL
  lvgl_port::begin();
  screens::standby_show();
  // 부팅 직후엔 BLE 연결 없음, 배터리 측정 전 — 기본값.
  screens::standby_set_connected(false);
  screens::standby_set_battery(-1);
#endif

  // 센서 영점 보정 (5초)
  Serial.println("Calibrating zero (5s)...");
  sensor::calibrateZero();
  Serial.printf("Zero offset = %.2f cmH2O\n", sensor::zeroOffset());

  pinMode(pins::VIBRATION, OUTPUT);
  pinMode(pins::LED_STATUS, OUTPUT);

#if HAS_LVGL
  // 영점 보정 끝나면 바로 training 화면으로 전환 (데모 — M7 의 정식 state
  // machine 이 도착하면 사용자 트리거 / BLE start_session opcode 로 전환).
  screens::training_show();
  screens::training_set_target(20.0f, 30.0f);
  screens::training_set_phase(screens::TrainingPhase::Exhale, TURN_EXHALE_MS / 1000);
  screens::training_set_progress(0, 1, 3);
  g_app_phase = AppPhase::Training;
  g_phase_started_ms = millis();
#endif

  Serial.println("Setup complete.");
}

// ----- Loop -----
void loop() {
  const uint32_t now = millis();

  // 100Hz 압력 샘플링.
  static uint32_t lastSampleMs = 0;
  if (now - lastSampleMs >= 10) {
    lastSampleMs = now;
    sensor::tick();
  }

  // 20Hz 압력 라벨/게이지 갱신 — LVGL 의 partial render 가 부드럽게 처리.
  static uint32_t lastUpdateMs = 0;
  if (now - lastUpdateMs >= 50) {
    lastUpdateMs = now;
    const float p = sensor::currentCmH2O();
#if HAS_LVGL
    if (g_app_phase == AppPhase::Training) {
      screens::training_set_pressure(p);
    }
#endif
  }

  // 1Hz 시리얼 디버그 + phase 사이클 처리.
  static uint32_t lastSecMs = 0;
  if (now - lastSecMs >= 1000) {
    lastSecMs = now;
    const float p = sensor::currentCmH2O();
    Serial.printf("[%lu] P=%+6.2f cmH2O\n", now, p);

#if HAS_LVGL
    // 호기/흡기 cycle + 카운트다운 + 진행률.
    if (g_app_phase == AppPhase::Training) {
      const uint32_t elapsed = now - g_phase_started_ms;
      const uint32_t in_cycle = elapsed % CYCLE_MS;
      const bool is_exhale = in_cycle < TURN_EXHALE_MS;
      const uint32_t remaining_ms = is_exhale
          ? (TURN_EXHALE_MS - in_cycle)
          : (CYCLE_MS - in_cycle);

      // phase 전환 검지
      static bool last_was_exhale = true;
      if (is_exhale != last_was_exhale) {
        last_was_exhale = is_exhale;
        screens::training_set_phase(
            is_exhale ? screens::TrainingPhase::Exhale
                      : screens::TrainingPhase::Inhale,
            remaining_ms / 1000);
      } else {
        screens::training_set_remaining(remaining_ms / 1000);
      }

      // 데모용 진행률 — 전체 4분 (240s) 의 % 로 가정.
      uint32_t total_demo = 240000;
      uint32_t pct = (elapsed * 100) / total_demo;
      if (pct > 100) pct = 100;
      screens::training_set_progress((uint8_t)pct, 1, 3);
    }
#endif
  }

  // LVGL tick — 60FPS 목표.
#if HAS_LVGL
  lvgl_port::tick();
#endif

  delay(2);
}
