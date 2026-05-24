// 대기 화면 (Standby) — implementation.
//
// 설계: BlowFit.html ScrIdle — 다크 테마, 상단 status bar (BT + 배터리),
// 중앙 READY chip + "훈련 준비" 큰 텍스트 + 안내문, 하단 저항 카드.

#include "display/screens/screen_standby.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>
#include <cstdio>

namespace screens {

namespace {

  // 상태 핸들 — set_* 함수에서 갱신.
  lv_obj_t* g_bt_dot      = nullptr;   // BT 컬러 점 (off/connect/pairing)
  lv_obj_t* g_lbl_batt    = nullptr;   // "76%"
  lv_obj_t* g_batt_fill   = nullptr;   // 배터리 아이콘 내부 fill
  lv_obj_t* g_lbl_status  = nullptr;   // "마우스피스를 물어주세요"

  /// 다크 테마 카드 (둥근 모서리 10px, surface 색).
  lv_obj_t* make_card(lv_obj_t* parent, int w, int h) {
    lv_obj_t* card = lv_obj_create(parent);
    lv_obj_set_size(card, w, h);
    lv_obj_set_style_bg_color(card, theme::color(theme::DEV_SURFACE), 0);
    lv_obj_set_style_bg_opa(card, LV_OPA_COVER, 0);
    lv_obj_set_style_border_width(card, 0, 0);
    lv_obj_set_style_radius(card, 10, 0);
    lv_obj_set_style_pad_all(card, 10, 0);
    lv_obj_clear_flag(card, LV_OBJ_FLAG_SCROLLABLE);
    return card;
  }

  /// 작은 알약 chip (둥근 끝, 컬러 텍스트, 반투명 배경).
  lv_obj_t* make_chip(lv_obj_t* parent, const char* text,
                      uint32_t color, uint32_t bg) {
    lv_obj_t* chip = lv_obj_create(parent);
    lv_obj_set_size(chip, LV_SIZE_CONTENT, 18);
    lv_obj_set_style_bg_color(chip, theme::color(bg), 0);
    lv_obj_set_style_bg_opa(chip, LV_OPA_COVER, 0);
    lv_obj_set_style_border_width(chip, 0, 0);
    lv_obj_set_style_radius(chip, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_pad_hor(chip, 8, 0);
    lv_obj_set_style_pad_ver(chip, 0, 0);
    lv_obj_clear_flag(chip, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t* lbl = lv_label_create(chip);
    lv_label_set_text(lbl, text);
    lv_obj_set_style_text_font(lbl, theme::font_14(), 0);
    lv_obj_set_style_text_color(lbl, theme::color(color), 0);
    lv_obj_center(lbl);
    return chip;
  }

  /// 상단 status bar (170 × 20) — BT (좌) + 배터리 (우).
  void make_status_bar(lv_obj_t* scr) {
    lv_obj_t* bar = lv_obj_create(scr);
    lv_obj_set_size(bar, display::SCREEN_W, 20);
    lv_obj_align(bar, LV_ALIGN_TOP_MID, 0, 0);
    lv_obj_set_style_bg_opa(bar, LV_OPA_TRANSP, 0);
    lv_obj_set_style_border_width(bar, 0, 0);
    lv_obj_set_style_pad_hor(bar, 8, 0);
    lv_obj_set_style_pad_ver(bar, 4, 0);
    lv_obj_clear_flag(bar, LV_OBJ_FLAG_SCROLLABLE);

    // 좌측 — BT 컬러 점 (실제 BT 아이콘은 차후 lv_image_t / FontAwesome 으로)
    g_bt_dot = lv_obj_create(bar);
    lv_obj_set_size(g_bt_dot, 8, 8);
    lv_obj_align(g_bt_dot, LV_ALIGN_LEFT_MID, 0, 0);
    lv_obj_set_style_bg_color(g_bt_dot, theme::color(theme::DEV_TEXT_MUTE), 0);
    lv_obj_set_style_border_width(g_bt_dot, 0, 0);
    lv_obj_set_style_radius(g_bt_dot, LV_RADIUS_CIRCLE, 0);
    lv_obj_clear_flag(g_bt_dot, LV_OBJ_FLAG_SCROLLABLE);

    // 우측 — 배터리 % 라벨
    g_lbl_batt = lv_label_create(bar);
    lv_label_set_text(g_lbl_batt, "76%");
    lv_obj_set_style_text_font(g_lbl_batt, theme::font_14(), 0);
    lv_obj_set_style_text_color(g_lbl_batt, theme::color(theme::DEV_TEXT_SUB), 0);
    lv_obj_align(g_lbl_batt, LV_ALIGN_RIGHT_MID, -28, 0);

    // 우측 — 배터리 아이콘 (외곽 사각형)
    lv_obj_t* batt_box = lv_obj_create(bar);
    lv_obj_set_size(batt_box, 22, 11);
    lv_obj_align(batt_box, LV_ALIGN_RIGHT_MID, -2, 0);
    lv_obj_set_style_bg_opa(batt_box, LV_OPA_TRANSP, 0);
    lv_obj_set_style_border_color(batt_box, theme::color(theme::DEV_TEXT_SUB), 0);
    lv_obj_set_style_border_width(batt_box, 1, 0);
    lv_obj_set_style_radius(batt_box, 2, 0);
    lv_obj_set_style_pad_all(batt_box, 1, 0);
    lv_obj_clear_flag(batt_box, LV_OBJ_FLAG_SCROLLABLE);

    // 배터리 내부 fill (정상 = green)
    g_batt_fill = lv_obj_create(batt_box);
    lv_obj_set_size(g_batt_fill, 14, 7);   // 76% 가정
    lv_obj_align(g_batt_fill, LV_ALIGN_LEFT_MID, 0, 0);
    lv_obj_set_style_bg_color(g_batt_fill, theme::color(theme::DEV_GREEN), 0);
    lv_obj_set_style_border_width(g_batt_fill, 0, 0);
    lv_obj_set_style_radius(g_batt_fill, 1, 0);
    lv_obj_clear_flag(g_batt_fill, LV_OBJ_FLAG_SCROLLABLE);
  }

}  // anonymous namespace

void standby_show() {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  lv_obj_set_style_bg_color(scr, theme::color(theme::DEV_BG), 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // 1. 상단 status bar.
  make_status_bar(scr);

  // 2. 중앙 — READY chip + "훈련 준비" + 안내.
  lv_obj_t* chip = make_chip(scr, "READY",
                              theme::DEV_GREEN,
                              theme::DEV_SURFACE);   // 반투명 어두운 배경 대체
  lv_obj_align(chip, LV_ALIGN_TOP_MID, 0, 88);

  lv_obj_t* lbl_title = lv_label_create(scr);
  lv_label_set_text(lbl_title, "훈련 준비");
  lv_obj_set_style_text_font(lbl_title, theme::font_28(), 0);
  lv_obj_set_style_text_color(lbl_title, theme::color(theme::DEV_TEXT), 0);
  lv_obj_align(lbl_title, LV_ALIGN_TOP_MID, 0, 116);

  g_lbl_status = lv_label_create(scr);
  lv_label_set_text(g_lbl_status, "Bite mouthpiece");
  lv_obj_set_style_text_font(g_lbl_status, theme::font_14(), 0);
  lv_obj_set_style_text_color(g_lbl_status, theme::color(theme::DEV_TEXT_SUB), 0);
  lv_obj_align(g_lbl_status, LV_ALIGN_TOP_MID, 0, 160);

  // 3. 하단 — 저항 단계 카드 (142 × 56, 하단 14px 마진).
  lv_obj_t* card = make_card(scr, 142, 56);
  lv_obj_align(card, LV_ALIGN_BOTTOM_MID, 0, -14);

  // 라벨 (좌상) + level dots (우상)
  lv_obj_t* lbl_card = lv_label_create(card);
  lv_label_set_text(lbl_card, "LEVEL");
  lv_obj_set_style_text_font(lbl_card, theme::font_14(), 0);
  lv_obj_set_style_text_color(lbl_card, theme::color(theme::DEV_TEXT_MUTE), 0);
  lv_obj_align(lbl_card, LV_ALIGN_TOP_LEFT, 0, 0);

  // Level dots 3개 (우상) — 현재 단계 2 (보통) 하드코딩
  constexpr int resistance = 2;
  for (int n = 1; n <= 3; ++n) {
    lv_obj_t* dot = lv_obj_create(card);
    lv_obj_set_size(dot, 9, 9);
    lv_obj_align(dot, LV_ALIGN_TOP_RIGHT, -(3 - n) * 13, 1);
    const uint32_t c = (n <= resistance) ? theme::DEV_PRIMARY : theme::DEV_DIVIDER;
    lv_obj_set_style_bg_color(dot, theme::color(c), 0);
    lv_obj_set_style_border_width(dot, 0, 0);
    lv_obj_set_style_radius(dot, 2, 0);
    lv_obj_clear_flag(dot, LV_OBJ_FLAG_SCROLLABLE);
  }

  // 큰 숫자 (좌하) + "/3" + 강도명 (우하)
  lv_obj_t* lbl_num = lv_label_create(card);
  lv_label_set_text(lbl_num, "2");
  lv_obj_set_style_text_font(lbl_num, theme::font_28(), 0);
  lv_obj_set_style_text_color(lbl_num, theme::color(theme::DEV_PRIMARY_LT), 0);
  lv_obj_align(lbl_num, LV_ALIGN_BOTTOM_LEFT, 0, 0);

  lv_obj_t* lbl_div = lv_label_create(card);
  lv_label_set_text(lbl_div, "/ 3");
  lv_obj_set_style_text_font(lbl_div, theme::font_14(), 0);
  lv_obj_set_style_text_color(lbl_div, theme::color(theme::DEV_TEXT_MUTE), 0);
  lv_obj_align(lbl_div, LV_ALIGN_BOTTOM_LEFT, 24, -2);

  lv_obj_t* lbl_lvl = lv_label_create(card);
  lv_label_set_text(lbl_lvl, "보통");
  lv_obj_set_style_text_font(lbl_lvl, theme::font_14(), 0);
  lv_obj_set_style_text_color(lbl_lvl, theme::color(theme::DEV_TEXT_SUB), 0);
  lv_obj_align(lbl_lvl, LV_ALIGN_BOTTOM_RIGHT, 0, -2);
}

void standby_set_connected(bool connected) {
  if (g_bt_dot) {
    const uint32_t c = connected ? theme::DEV_PRIMARY_LT : theme::DEV_TEXT_MUTE;
    lv_obj_set_style_bg_color(g_bt_dot, theme::color(c), 0);
  }
  if (g_lbl_status) {
    lv_label_set_text(g_lbl_status,
                      connected ? "Bite mouthpiece" : "연결 대기 중");
  }
}

void standby_set_battery(int8_t percent) {
  if (!g_lbl_batt) return;
  char buf[8];
  if (percent < 0) {
    lv_label_set_text(g_lbl_batt, "-- %");
    return;
  }
  std::snprintf(buf, sizeof(buf), "%d%%", percent);
  lv_label_set_text(g_lbl_batt, buf);

  if (g_batt_fill) {
    // 배터리 fill 폭 — 1~14px (76% → 11px).
    int w = (percent * 14) / 100;
    if (w < 1) w = 1;
    if (w > 14) w = 14;
    lv_obj_set_width(g_batt_fill, w);

    // 컬러 — 15% 이하 red, 30% 이하 amber, 그 외 green.
    uint32_t c;
    if      (percent <= 15) c = theme::DEV_RED;
    else if (percent <= 30) c = theme::DEV_AMBER;
    else                    c = theme::DEV_GREEN;
    lv_obj_set_style_bg_color(g_batt_fill, theme::color(c), 0);
  }
}

}  // namespace screens
