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
  lv_obj_t* g_bt_dot      = nullptr;   // BT 아이콘 (off/connect/pairing)
  lv_obj_t* g_batt_fill   = nullptr;   // 배터리 아이콘 내부 fill

  /// 작은 알약 chip (둥근 끝, 컬러 텍스트, 반투명 배경).
  lv_obj_t* make_chip(lv_obj_t* parent, const char* text,
                      uint32_t color, uint32_t bg) {
    lv_obj_t* chip = lv_obj_create(parent);
    lv_obj_set_size(chip, LV_SIZE_CONTENT, 30);
    lv_obj_set_style_bg_color(chip, theme::color(bg), 0);
    lv_obj_set_style_bg_opa(chip, LV_OPA_COVER, 0);
    lv_obj_set_style_border_width(chip, 0, 0);
    lv_obj_set_style_radius(chip, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_pad_hor(chip, 14, 0);
    lv_obj_set_style_pad_ver(chip, 0, 0);
    lv_obj_clear_flag(chip, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t* lbl = lv_label_create(chip);
    lv_label_set_text(lbl, text);
    lv_obj_set_style_text_font(lbl, theme::font_20(), 0);
    lv_obj_set_style_text_color(lbl, theme::color(color), 0);
    lv_obj_center(lbl);
    return chip;
  }

  /// 상단 status bar (170 × 20) — BT (좌) + 배터리 (우).
  void make_status_bar(lv_obj_t* scr) {
    lv_obj_t* bar = lv_obj_create(scr);
    lv_obj_set_size(bar, display::SCREEN_W, 26);
    lv_obj_align(bar, LV_ALIGN_TOP_MID, 0, 0);
    lv_obj_set_style_bg_opa(bar, LV_OPA_TRANSP, 0);
    lv_obj_set_style_border_width(bar, 0, 0);
    lv_obj_set_style_pad_hor(bar, 8, 0);
    lv_obj_set_style_pad_ver(bar, 3, 0);
    lv_obj_clear_flag(bar, LV_OBJ_FLAG_SCROLLABLE);

    // 좌측 — BT 아이콘 (Montserrat 심볼). 연결 상태에 따라 색 갱신.
    g_bt_dot = lv_label_create(bar);
    lv_label_set_text(g_bt_dot, LV_SYMBOL_BLUETOOTH);
    lv_obj_set_style_text_font(g_bt_dot, &lv_font_montserrat_20, 0);
    lv_obj_set_style_text_color(g_bt_dot, theme::color(theme::DEV_TEXT_MUTE), 0);
    lv_obj_align(g_bt_dot, LV_ALIGN_LEFT_MID, 0, 2);

    // 우측 — 배터리 아이콘 = 본체 박스 + 우측 단자 nub.
    // 단자 nub (작은 돌기) — 가장 오른쪽, 본체에 붙임.
    lv_obj_t* batt_nub = lv_obj_create(bar);
    lv_obj_set_size(batt_nub, 2, 5);
    lv_obj_align(batt_nub, LV_ALIGN_RIGHT_MID, -2, 0);
    lv_obj_set_style_bg_color(batt_nub, theme::color(theme::DEV_TEXT_SUB), 0);
    lv_obj_set_style_bg_opa(batt_nub, LV_OPA_COVER, 0);
    lv_obj_set_style_border_width(batt_nub, 0, 0);
    lv_obj_set_style_radius(batt_nub, 1, 0);
    lv_obj_clear_flag(batt_nub, LV_OBJ_FLAG_SCROLLABLE);

    // 본체 외곽 박스 (숫자 % 표기 없음, 아이콘만)
    lv_obj_t* batt_box = lv_obj_create(bar);
    lv_obj_set_size(batt_box, 22, 11);
    lv_obj_align(batt_box, LV_ALIGN_RIGHT_MID, -4, 0);
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
    lv_obj_set_style_bg_opa(g_batt_fill, LV_OPA_COVER, 0);
    lv_obj_set_style_border_width(g_batt_fill, 0, 0);
    lv_obj_set_style_radius(g_batt_fill, 1, 0);
    lv_obj_clear_flag(g_batt_fill, LV_OBJ_FLAG_SCROLLABLE);
  }

}  // anonymous namespace

void standby_show() {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  // 디자인 ScrIdle — 흰 배경, 화면 중앙에 "훈련 준비" + 위에 READY chip.
  lv_obj_set_style_bg_color(scr, theme::color(theme::DEV_SURFACE), 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // 1. 상단 status bar.
  make_status_bar(scr);

  // 2. 중앙 hero — READY chip (위) + "훈련 준비" (정중앙).
  lv_obj_t* chip = make_chip(scr, "READY",
                              theme::DEV_GREEN,
                              theme::DEV_SURFACE2);
  lv_obj_align(chip, LV_ALIGN_CENTER, 0, -50);

  lv_obj_t* lbl_title = lv_label_create(scr);
  lv_label_set_text(lbl_title, "훈련 준비");
  lv_obj_set_style_text_font(lbl_title, theme::font_28(), 0);
  lv_obj_set_style_text_color(lbl_title, theme::color(theme::DEV_TEXT), 0);
  lv_obj_align(lbl_title, LV_ALIGN_CENTER, 0, 0);
}

void standby_set_connected(bool connected) {
  if (g_bt_dot) {
    const uint32_t c = connected ? theme::DEV_PRIMARY_LT : theme::DEV_TEXT_MUTE;
    lv_obj_set_style_text_color(g_bt_dot, theme::color(c), 0);
  }
}

void standby_set_battery(int8_t percent) {
  if (!g_batt_fill) return;
  // 배터리 fill 폭 (0~14px) + 색상. 숫자 % 표기는 없음.
  const int p = percent < 0 ? 0 : (percent > 100 ? 100 : percent);
  int w = (p * 14) / 100;
  if (w < 1 && p > 0) w = 1;
  lv_obj_set_width(g_batt_fill, w);
  const uint32_t c = (p <= 15) ? theme::DEV_RED
                   : (p <= 30) ? theme::DEV_AMBER
                               : theme::DEV_GREEN;
  lv_obj_set_style_bg_color(g_batt_fill, theme::color(c), 0);
}

}  // namespace screens
