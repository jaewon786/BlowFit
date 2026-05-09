// BlowFit v4.0 펌웨어 — 진입점.
// LILYGO T-Display S3 + 양방향 차압 센서 + LVGL + BLE.
//
// 현재 상태: scaffold (기본 boot + 센서 + LVGL hello world). 완성 모듈은
// 마이그레이션 진행에 따라 추가:
//   - state_machine: v3.2 firmware/state_machine.cpp 에서 포팅 예정
//   - feedback (진동/LED): v3.2 와 거의 동일 — 포팅 예정
//   - ble_service: ESP32 BLE Arduino 로 재작성 예정
//   - storage: NVS (Preferences) 로 재작성 예정
//   - ui_lvgl: LVGL 위젯 (Arc 게이지, 압력값) — 신규 작성

#include "config.h"
#include "sensor.h"

#if HAS_DISPLAY
  #include <TFT_eSPI.h>
  static TFT_eSPI tft;
#endif

#if HAS_LVGL
  #include <lvgl.h>
  // LVGL display flush callback 등은 ui_lvgl.cpp 에서 처리 예정.
#endif

#if HAS_BLE
  // ESP32 BLE Arduino 헤더 포함. ble_service.cpp 에서 GATT 정의.
  #include <BLEDevice.h>
#endif

// ----- 백라이트 ON 보조 (배터리 모드 시 필수) -----
static void enableBacklight() {
#if HAS_DISPLAY
  pinMode(pins::TFT_BACKLIGHT_ENABLE, OUTPUT);
  digitalWrite(pins::TFT_BACKLIGHT_ENABLE, HIGH);
#endif
}

// ----- Setup -----
void setup() {
  Serial.begin(115200);
  delay(100);
  Serial.println("BlowFit v4.0 boot — ESP32-S3");

  // 백라이트 (배터리 모드 안전)
  enableBacklight();

#if HAS_DISPLAY
  tft.init();
  tft.setRotation(1);  // 가로 모드 (320×170)
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setTextSize(2);
  tft.drawString("BlowFit v4.0", 10, 10);
  tft.drawString("Hello, ESP32-S3!", 10, 40);
#endif

  // 센서 영점 보정 — 사용자 입에 물기 전 대기압 5초 측정.
  // TODO: UI 에 "영점 보정 중..." 표시.
  Serial.println("Calibrating zero (5s, do not breathe into mouthpiece)...");
  sensor::calibrateZero();
  Serial.printf("Zero offset = %.2f cmH2O\n", sensor::zeroOffset());

  pinMode(pins::VIBRATION, OUTPUT);
  pinMode(pins::LED_STATUS, OUTPUT);

#if HAS_LVGL
  // TODO ui_lvgl::begin() — display flush callback + 메인 화면 위젯.
#endif

#if HAS_BLE
  // TODO ble_service::begin() — GATT service + characteristic 등록.
#endif

  Serial.println("Setup complete.");
}

// ----- Loop -----
void loop() {
  // 100Hz 압력 샘플링.
  static uint32_t lastSampleMs = 0;
  const uint32_t now = millis();
  if (now - lastSampleMs >= 10) {
    lastSampleMs = now;
    sensor::tick();

    // TODO state_machine::update(now, sensor::currentCmH2O())
    // TODO ble_service::sendPressure(sensor::currentCmH2O())
  }

#if HAS_DISPLAY
  // 디버그 — 현재 압력값 화면 표시 (LVGL 도착 전 임시).
  static uint32_t lastDrawMs = 0;
  if (now - lastDrawMs >= 100) {
    lastDrawMs = now;
    tft.fillRect(10, 80, 280, 30, TFT_BLACK);
    char buf[32];
    snprintf(buf, sizeof(buf), "P: %+6.1f cmH2O", sensor::currentCmH2O());
    tft.drawString(buf, 10, 80);
  }
#endif

#if HAS_LVGL
  // TODO lv_timer_handler() — LVGL 메인 루프.
#endif

  // 짧은 delay — busy loop 회피, BLE 스택 시간 양보.
  delay(2);
}
