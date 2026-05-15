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

// ----- 전역 상태 -----
// (M3 까지의 hello 화면 전역 핸들은 screens/screen_standby.cpp 로 이동. M5+ 의
// training 화면 등에서 필요시 별도 모듈로 분리.)

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

  // 5Hz 시리얼 로깅 (디버그용). 화면 갱신은 각 screen 모듈이 담당.
  static uint32_t lastUpdateMs = 0;
  if (now - lastUpdateMs >= 200) {
    lastUpdateMs = now;
    const float p = sensor::currentCmH2O();
    Serial.printf("[%lu] P=%+6.2f cmH2O\n", now, p);
  }

  // LVGL tick — 60FPS 목표.
#if HAS_LVGL
  lvgl_port::tick();
#endif

  delay(2);
}
