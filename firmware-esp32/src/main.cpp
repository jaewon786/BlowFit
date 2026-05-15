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

// ----- 전역 LVGL 위젯 핸들 (M3 부터 screens/ 모듈로 분리 예정) -----
namespace {
  lv_obj_t* g_label_pressure = nullptr;
  lv_obj_t* g_label_status   = nullptr;
}

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
static void buildHelloScreen() {
#if HAS_LVGL
  lv_obj_t* scr = lv_screen_active();
  lv_obj_set_style_bg_color(scr, theme::color(theme::GRAY_900), 0);

  // Title — BlowFit (영문, Pretendard Bold 28pt)
  lv_obj_t* lbl_title = lv_label_create(scr);
  lv_label_set_text(lbl_title, "BlowFit");
  lv_obj_set_style_text_font(lbl_title, theme::font_28(), 0);
  lv_obj_set_style_text_color(lbl_title, theme::color(0xFFFFFF), 0);
  lv_obj_align(lbl_title, LV_ALIGN_TOP_MID, 0, 16);

  // Subtitle — v4.0 (Pretendard Bold 20pt)
  lv_obj_t* lbl_ver = lv_label_create(scr);
  lv_label_set_text(lbl_ver, "v4.0");
  lv_obj_set_style_text_font(lbl_ver, theme::font_20(), 0);
  lv_obj_set_style_text_color(lbl_ver, theme::color(theme::BLUE_400), 0);
  lv_obj_align(lbl_ver, LV_ALIGN_TOP_MID, 0, 52);

  // M3 한글 status label — Pretendard
  g_label_status = lv_label_create(scr);
  lv_label_set_text(g_label_status, "준비 중");
  lv_obj_set_style_text_font(g_label_status, theme::font_20(), 0);
  lv_obj_set_style_text_color(g_label_status, theme::color(theme::GREEN_500), 0);
  lv_obj_align(g_label_status, LV_ALIGN_TOP_MID, 0, 84);

  // 한글 안내문 — 14pt
  lv_obj_t* lbl_hint = lv_label_create(scr);
  lv_label_set_text(lbl_hint, "강하게 내쉬세요");
  lv_obj_set_style_text_font(lbl_hint, theme::font_14(), 0);
  lv_obj_set_style_text_color(lbl_hint, theme::color(theme::GRAY_400), 0);
  lv_obj_align(lbl_hint, LV_ALIGN_TOP_MID, 0, 116);

  // Pressure live label — 가운데 큰 영문/숫자 (Montserrat 48pt)
  g_label_pressure = lv_label_create(scr);
  lv_label_set_text(g_label_pressure, "+0.0");
  lv_obj_set_style_text_font(g_label_pressure, theme::font_big(), 0);
  lv_obj_set_style_text_color(g_label_pressure, theme::color(theme::BLUE_400), 0);
  lv_obj_align(g_label_pressure, LV_ALIGN_CENTER, 0, 20);

  // cmH2O unit (영문/숫자)
  lv_obj_t* lbl_unit = lv_label_create(scr);
  lv_label_set_text(lbl_unit, "cmH2O");
  lv_obj_set_style_text_font(lbl_unit, theme::font_14(), 0);
  lv_obj_set_style_text_color(lbl_unit, theme::color(theme::GRAY_400), 0);
  lv_obj_align(lbl_unit, LV_ALIGN_CENTER, 0, 78);

  // 하단 한글 — "실시간 압력"
  lv_obj_t* lbl_caption = lv_label_create(scr);
  lv_label_set_text(lbl_caption, "실시간 압력");
  lv_obj_set_style_text_font(lbl_caption, theme::font_14(), 0);
  lv_obj_set_style_text_color(lbl_caption, theme::color(theme::INK_3), 0);
  lv_obj_align(lbl_caption, LV_ALIGN_BOTTOM_MID, 0, -34);

  // Footer — build time (영문)
  lv_obj_t* lbl_build = lv_label_create(scr);
  lv_label_set_text(lbl_build, __DATE__ " " __TIME__);
  lv_obj_set_style_text_font(lbl_build, theme::font_14(), 0);
  lv_obj_set_style_text_color(lbl_build, theme::color(theme::INK_3), 0);
  lv_obj_align(lbl_build, LV_ALIGN_BOTTOM_MID, 0, -10);
#endif
}

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
  buildHelloScreen();
#endif

  // 센서 영점 보정 (5초)
  Serial.println("Calibrating zero (5s)...");
  sensor::calibrateZero();
  Serial.printf("Zero offset = %.2f cmH2O\n", sensor::zeroOffset());

  pinMode(pins::VIBRATION, OUTPUT);
  pinMode(pins::LED_STATUS, OUTPUT);

#if HAS_LVGL
  if (g_label_status) {
    lv_label_set_text(g_label_status, "대기");
  }
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

  // 5Hz 시리얼 + LVGL label 갱신.
  static uint32_t lastUpdateMs = 0;
  if (now - lastUpdateMs >= 200) {
    lastUpdateMs = now;
    const float p = sensor::currentCmH2O();
    Serial.printf("[%lu] P=%+6.2f cmH2O\n", now, p);

#if HAS_LVGL
    if (g_label_pressure) {
      char buf[16];
      snprintf(buf, sizeof(buf), "%+5.1f", p);
      lv_label_set_text(g_label_pressure, buf);
      // 부호에 따라 컬러 변경 — 호기=파랑, 흡기=보라
      const uint32_t hex = (p >= 0) ? theme::BLUE_400 : theme::PURPLE_400;
      lv_obj_set_style_text_color(g_label_pressure, theme::color(hex), 0);
    }
#endif
  }

  // LVGL tick — 60FPS 목표.
#if HAS_LVGL
  lvgl_port::tick();
#endif

  delay(2);
}
