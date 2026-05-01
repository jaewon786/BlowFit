#include "ui_tft.h"
#include "config.h"

#if defined(ARDUINO) && HAS_TFT
  // TFT_eSPI 가 nRF52 mbed BSP 와 호환 안 되는 이슈로 Adafruit_ST7735 사용.
  // Adafruit_GFX (의존성) + SPI 도 자동으로 import.
  #include <Adafruit_GFX.h>
  #include <Adafruit_ST7735.h>
  #include <SPI.h>
  // Hardware SPI: SCK=D8, MOSI=D10 자동. CS/DC/RST 만 명시.
  static Adafruit_ST7735 tft(pins::TFT_CS, pins::TFT_DC, pins::TFT_RST);
#endif

namespace ui_tft {

namespace {

constexpr int16_t SCREEN_W = 80;
constexpr int16_t SCREEN_H = 160;
constexpr int16_t BAR_X = 14;
constexpr int16_t BAR_W = 20;
constexpr int16_t BAR_TOP_Y = 30;
constexpr int16_t BAR_BOT_Y = 130;
constexpr float MAX_CMH2O = 40.0f;

bool g_dirty = true;
DeviceState g_lastState = DeviceState::Boot;
int16_t g_lastBarHeight = 0;

#if defined(ARDUINO) && HAS_TFT
uint16_t colorForPressure(float p, float low, float high) {
  if (p < low - 5) return ST77XX_RED;
  if (p < low)     return ST77XX_YELLOW;
  if (p <= high)   return ST77XX_GREEN;
  return ST77XX_ORANGE;
}
#endif

int16_t pressureToY(float p) {
  if (p < 0) p = 0;
  if (p > MAX_CMH2O) p = MAX_CMH2O;
  return BAR_BOT_Y - (int16_t)((p / MAX_CMH2O) * (BAR_BOT_Y - BAR_TOP_Y));
}

void drawStandby(uint8_t batteryPct) {
#if defined(ARDUINO) && HAS_TFT
  tft.fillScreen(ST77XX_BLACK);
  tft.setTextColor(ST77XX_WHITE, ST77XX_BLACK);
  tft.setTextSize(1);
  tft.setCursor(8, 30);
  tft.println("BlowFit");
  tft.setCursor(8, 140);
  tft.print("BAT ");
  tft.print(batteryPct);
  tft.print("%");
#else
  (void)batteryPct;
#endif
}

void drawTrainBase(float low, float high) {
#if defined(ARDUINO) && HAS_TFT
  tft.fillScreen(ST77XX_BLACK);
  // Y-axis ticks + labels
  const uint16_t darkGrey = tft.color565(64, 64, 64);
  tft.setTextColor(darkGrey, ST77XX_BLACK);
  tft.setTextSize(1);
  for (int val = 0; val <= 40; val += 10) {
    int16_t y = pressureToY((float)val);
    tft.drawFastHLine(BAR_X - 4, y, 4, darkGrey);
    tft.setCursor(42, y - 3);
    tft.print(val);
  }
  // Target zone background band
  int16_t yLow  = pressureToY(low);
  int16_t yHigh = pressureToY(high);
  tft.fillRect(BAR_X, yHigh, BAR_W, yLow - yHigh, tft.color565(0, 48, 0));
#else
  (void)low; (void)high;
#endif
}

void drawTrain(float current, const state_machine::Metrics& m, uint32_t nowMs,
               float low, float high) {
#if defined(ARDUINO) && HAS_TFT
  int16_t yNow = pressureToY(current);
  int16_t newHeight = BAR_BOT_Y - yNow;

  // Erase old top portion if shrinking
  if (newHeight < g_lastBarHeight) {
    int16_t eraseTop = BAR_BOT_Y - g_lastBarHeight;
    tft.fillRect(BAR_X, eraseTop, BAR_W, g_lastBarHeight - newHeight, ST77XX_BLACK);
  }
  // Redraw target band on restored area
  int16_t yLow  = pressureToY(low);
  int16_t yHigh = pressureToY(high);
  tft.fillRect(BAR_X, yHigh, BAR_W, yLow - yHigh, tft.color565(0, 48, 0));
  // Draw new bar
  uint16_t col = colorForPressure(current, low, high);
  tft.fillRect(BAR_X, yNow, BAR_W, newHeight, col);
  g_lastBarHeight = newHeight;

  // Numeric readouts (dirty-rect)
  tft.fillRect(0, 0, SCREEN_W, 24, ST77XX_BLACK);
  tft.setTextColor(ST77XX_WHITE, ST77XX_BLACK);
  tft.setTextSize(2);
  tft.setCursor(4, 4);
  tft.print((int)current);
  tft.setTextSize(1);
  tft.print(" cmH2O");

  tft.fillRect(0, 140, SCREEN_W, 20, ST77XX_BLACK);
  tft.setTextColor(ST77XX_WHITE, ST77XX_BLACK);
  tft.setCursor(2, 142);
  uint32_t secs = (nowMs - m.sessionStartMs) / 1000;
  tft.print("T ");
  tft.print(secs / 60);
  tft.print(":");
  if ((secs % 60) < 10) tft.print("0");
  tft.print(secs % 60);
  tft.setCursor(2, 152);
  tft.print("Hold ");
  tft.print(m.enduranceMs / 1000);
  tft.print("s");
#else
  (void)current; (void)m; (void)nowMs; (void)low; (void)high;
#endif
}

void drawSummary(const state_machine::Metrics& m) {
#if defined(ARDUINO) && HAS_TFT
  tft.fillScreen(ST77XX_BLACK);
  tft.setTextColor(ST77XX_WHITE, ST77XX_BLACK);
  tft.setTextSize(1);
  tft.setCursor(4, 10);  tft.println("SUMMARY");
  tft.setCursor(4, 30);  tft.print("MAX "); tft.print((int)m.maxPressure); tft.println(" cmH2O");
  tft.setCursor(4, 44);  tft.print("AVG "); tft.print((int)m.avgPressure()); tft.println(" cmH2O");
  tft.setCursor(4, 58);  tft.print("HOLD "); tft.print(m.enduranceMs / 1000); tft.println(" s");
  tft.setCursor(4, 72);  tft.print("HITS "); tft.println(m.targetHits);
  tft.setCursor(4, 86);  tft.print("TIME "); tft.print(m.sessionDurationMs / 1000); tft.println(" s");
#else
  (void)m;
#endif
}

}  // namespace

void begin() {
#if defined(ARDUINO) && HAS_TFT
  // 80x160 IPS ST7735 패널: INITR_MINI160x80 가 표준.
  // 색이 반전되어 보이면 INITR_MINI160x80_PLUGIN 또는 _GREENTAB 시도.
  tft.initR(INITR_MINI160x80);
  tft.setRotation(0);   // portrait 80x160
  tft.fillScreen(ST77XX_BLACK);
#endif
  g_dirty = true;
}

void invalidate() { g_dirty = true; }

void render(DeviceState s, float currentCmH2O, const state_machine::Metrics& m,
            uint32_t nowMs, uint8_t batteryPct) {
  if (s != g_lastState) {
    g_dirty = true;
    g_lastState = s;
    g_lastBarHeight = 0;
  }

  if (g_dirty) {
    switch (s) {
      case DeviceState::Standby: drawStandby(batteryPct); break;
      case DeviceState::Train:
      case DeviceState::Prep:
      case DeviceState::Rest:
        drawTrainBase(state_machine::targetLow(), state_machine::targetHigh());
        break;
      case DeviceState::Summary: drawSummary(m); break;
      default: break;
    }
    g_dirty = false;
  }

  if (s == DeviceState::Train) {
    drawTrain(currentCmH2O, m, nowMs,
              state_machine::targetLow(), state_machine::targetHigh());
  }
}

}  // namespace ui_tft
