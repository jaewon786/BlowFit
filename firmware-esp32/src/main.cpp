// BlowFit v4.0 펌웨어 — M1 milestone (PlatformIO + TFT_eSPI hello world).
//
// 이 단계 (M1) 의 목표:
//   - PlatformIO 빌드 통과
//   - T-Display S3 세로 화면 (170×320) 켜짐
//   - "BlowFit v4.0" + 빌드 시각 표시
//   - 100Hz 센서 tick 동작 + 시리얼로 현재 압력 출력
//
// 다음 단계 (M2): LVGL 통합 — flush 콜백 + 더블 버퍼 + perf monitor.

#include <Arduino.h>
#include "config.h"
#include "sensor.h"

#if HAS_DISPLAY
  #include <TFT_eSPI.h>
  static TFT_eSPI tft;
#endif

#if HAS_BLE
  // M8 에서 ble_service.cpp 로 분리. 지금은 placeholder.
  // #include <BLEDevice.h>
#endif

// ----- 시리얼 + 디스플레이 전원 부트 보조 -----
static void bootHardware() {
#if HAS_DISPLAY
  // 1. LDO 전원 enable (GPIO15 HIGH) — 배터리 모드 필수.
  //    USB 전원만 쓸 때는 이미 HIGH 일 수 있지만 명시적으로 한다.
  pinMode(pins::TFT_POWER_ON, OUTPUT);
  digitalWrite(pins::TFT_POWER_ON, HIGH);
  delay(50);  // LDO 안정화 대기

  // 2. TFT 초기화 + 세로 모드.
  tft.init();
  tft.setRotation(display::ROTATION);
  tft.fillScreen(TFT_BLACK);

  // 3. 백라이트는 TFT_eSPI 가 Setup206 의 TFT_BL 핀으로 자동 ON.
#endif
}

// ----- 디버그 화면 그리기 (M2 에서 LVGL 로 대체) -----
static void drawBootScreen() {
#if HAS_DISPLAY
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setTextSize(2);
  tft.setTextDatum(TC_DATUM);  // top-center

  const int cx = display::SCREEN_W / 2;

  tft.drawString("BlowFit", cx, 24);
  tft.drawString("v4.0", cx, 50);

  tft.setTextSize(1);
  tft.drawString("M1: TFT_eSPI OK", cx, 90);
  tft.drawString(__DATE__, cx, 110);
  tft.drawString(__TIME__, cx, 124);

  tft.drawString("Calibrating zero...", cx, 160);
#endif
}

// ----- Setup -----
void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println();
  Serial.println("=========================================");
  Serial.println("BlowFit v4.0 — ESP32-S3 / T-Display S3");
  Serial.println("Build: " __DATE__ " " __TIME__);
  Serial.println("=========================================");

  bootHardware();
  drawBootScreen();

  // 센서 영점 보정 (5초, 사용자가 마우스피스 안 물고 있어야 함)
  Serial.println("Calibrating zero (5s, do not breathe into mouthpiece)...");
  sensor::calibrateZero();
  Serial.printf("Zero offset = %.2f cmH2O\n", sensor::zeroOffset());

  pinMode(pins::VIBRATION, OUTPUT);
  pinMode(pins::LED_STATUS, OUTPUT);

#if HAS_DISPLAY
  tft.fillRect(0, 150, display::SCREEN_W, 50, TFT_BLACK);
  tft.setTextDatum(TC_DATUM);
  tft.setTextSize(1);
  tft.setTextColor(TFT_GREEN, TFT_BLACK);
  tft.drawString("Ready.", display::SCREEN_W / 2, 160);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
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

  // 5Hz 시리얼 출력 + 디스플레이 디버그.
  static uint32_t lastDrawMs = 0;
  if (now - lastDrawMs >= 200) {
    lastDrawMs = now;
    const float p = sensor::currentCmH2O();
    Serial.printf("[%lu] P=%+6.2f cmH2O\n", now, p);

#if HAS_DISPLAY
    // 화면 가운데에 큰 글씨로 현재 압력 표시 (M2 LVGL 도착 전 임시).
    tft.fillRect(0, 200, display::SCREEN_W, 60, TFT_BLACK);
    tft.setTextDatum(MC_DATUM);
    tft.setTextSize(3);
    tft.setTextColor(p >= 0 ? TFT_CYAN : TFT_PINK, TFT_BLACK);
    char buf[16];
    snprintf(buf, sizeof(buf), "%+5.1f", p);
    tft.drawString(buf, display::SCREEN_W / 2, 230);
    tft.setTextSize(1);
    tft.setTextColor(TFT_WHITE, TFT_BLACK);
    tft.drawString("cmH2O", display::SCREEN_W / 2, 260);
#endif
  }

  // 짧은 delay — BLE / WiFi 스택 시간 양보.
  delay(2);
}
