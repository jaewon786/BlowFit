// 휴식 화면 (Rest) — implementation.
//
// 설계: BlowFit.html ScrRest — 다크 테마, 상단 status bar + REST chip,
// 중앙 amber Arc 카운트다운 (큰 숫자 + "SECONDS"), 안내문, 하단 다음 세트
// 카드.

#include "display/screens/screen_rest.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>
#include <cstdio>

namespace screens {

namespace {

  lv_obj_t* g_arc           = nullptr;
  lv_obj_t* g_lbl_remaining = nullptr;
  lv_obj_t* g_lbl_next      = nullptr;

  constexpr int REST_TOTAL_SEC = 30;   // ScrRest 의 30/30 기준

}  // anonymous namespace

void rest_show() {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  lv_obj_set_style_bg_color(scr, theme::color(theme::DEV_BG), 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // ---------- 1. 상단 status bar ----------
  lv_obj_t* bar = lv_obj_create(scr);
  lv_obj_set_size(bar, display::SCREEN_W, 20);
  lv_obj_align(bar, LV_ALIGN_TOP_MID, 0, 0);
  lv_obj_set_style_bg_opa(bar, LV_OPA_TRANSP, 0);
  lv_obj_set_style_border_width(bar, 0, 0);
  lv_obj_set_style_pad_all(bar, 4, 0);
  lv_obj_clear_flag(bar, LV_OBJ_FLAG_SCROLLABLE);

  lv_obj_t* bt_dot = lv_obj_create(bar);
  lv_obj_set_size(bt_dot, 8, 8);
  lv_obj_align(bt_dot, LV_ALIGN_LEFT_MID, 0, 0);
  lv_obj_set_style_bg_color(bt_dot, theme::color(theme::DEV_PRIMARY_LT), 0);
  lv_obj_set_style_border_width(bt_dot, 0, 0);
  lv_obj_set_style_radius(bt_dot, LV_RADIUS_CIRCLE, 0);
  lv_obj_clear_flag(bt_dot, LV_OBJ_FLAG_SCROLLABLE);

  lv_obj_t* batt = lv_label_create(bar);
  lv_label_set_text(batt, "74%");
  lv_obj_set_style_text_font(batt, theme::font_14(), 0);
  lv_obj_set_style_text_color(batt, theme::color(theme::DEV_TEXT_SUB), 0);
  lv_obj_align(batt, LV_ALIGN_RIGHT_MID, 0, 0);

  // ---------- 2. REST chip ----------
  lv_obj_t* chip = lv_obj_create(scr);
  lv_obj_set_size(chip, LV_SIZE_CONTENT, 20);
  lv_obj_align(chip, LV_ALIGN_TOP_MID, 0, 32);
  lv_obj_set_style_bg_color(chip, theme::color(theme::DEV_SURFACE), 0);
  lv_obj_set_style_bg_opa(chip, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(chip, 0, 0);
  lv_obj_set_style_radius(chip, LV_RADIUS_CIRCLE, 0);
  lv_obj_set_style_pad_hor(chip, 12, 0);
  lv_obj_set_style_pad_ver(chip, 0, 0);
  lv_obj_clear_flag(chip, LV_OBJ_FLAG_SCROLLABLE);

  lv_obj_t* lbl_chip = lv_label_create(chip);
  lv_label_set_text(lbl_chip, "REST");
  lv_obj_set_style_text_font(lbl_chip, theme::font_14(), 0);
  lv_obj_set_style_text_color(lbl_chip, theme::color(theme::DEV_AMBER), 0);
  lv_obj_center(lbl_chip);

  // ---------- 3. amber Arc 카운트다운 ----------
  g_arc = lv_arc_create(scr);
  lv_obj_set_size(g_arc, 130, 130);
  lv_obj_align(g_arc, LV_ALIGN_TOP_MID, 0, 64);
  lv_arc_set_range(g_arc, 0, REST_TOTAL_SEC);
  lv_arc_set_value(g_arc, 0);
  lv_arc_set_bg_angles(g_arc, 135, 45);    // 270도 호 (위쪽 비움)
  lv_arc_set_angles(g_arc, 135, 135);      // value=0 → 시작점
  lv_arc_set_rotation(g_arc, 0);
  // 트랙 (amber 12% opacity 대체)
  lv_obj_set_style_arc_color(g_arc, theme::color(theme::DEV_AMBER), LV_PART_MAIN);
  lv_obj_set_style_arc_opa(g_arc, LV_OPA_20, LV_PART_MAIN);
  lv_obj_set_style_arc_width(g_arc, 10, LV_PART_MAIN);
  // indicator
  lv_obj_set_style_arc_color(g_arc, theme::color(theme::DEV_AMBER), LV_PART_INDICATOR);
  lv_obj_set_style_arc_width(g_arc, 10, LV_PART_INDICATOR);
  // knob 숨김
  lv_obj_remove_style(g_arc, NULL, LV_PART_KNOB);
  lv_obj_clear_flag(g_arc, LV_OBJ_FLAG_CLICKABLE);

  // Arc 중앙 큰 숫자 (남은 초)
  g_lbl_remaining = lv_label_create(scr);
  lv_label_set_text(g_lbl_remaining, "30");
  lv_obj_set_style_text_font(g_lbl_remaining, theme::font_28(), 0);
  lv_obj_set_style_text_color(g_lbl_remaining, theme::color(theme::DEV_AMBER), 0);
  lv_obj_align_to(g_lbl_remaining, g_arc, LV_ALIGN_CENTER, 0, -8);

  // "SECONDS"
  lv_obj_t* lbl_sec = lv_label_create(scr);
  lv_label_set_text(lbl_sec, "SECONDS");
  lv_obj_set_style_text_font(lbl_sec, theme::font_14(), 0);
  lv_obj_set_style_text_color(lbl_sec, theme::color(theme::DEV_TEXT_MUTE), 0);
  lv_obj_align_to(lbl_sec, g_arc, LV_ALIGN_CENTER, 0, 22);

  // ---------- 4. 안내문 ----------
  lv_obj_t* hint = lv_label_create(scr);
  lv_label_set_text(hint, "잠시 휴식하세요");
  lv_obj_set_style_text_font(hint, theme::font_14(), 0);
  lv_obj_set_style_text_color(hint, theme::color(theme::DEV_TEXT_SUB), 0);
  lv_obj_align(hint, LV_ALIGN_TOP_MID, 0, 216);

  // ---------- 5. 하단 — 다음 세트 카드 ----------
  lv_obj_t* card = lv_obj_create(scr);
  lv_obj_set_size(card, 142, 38);
  lv_obj_align(card, LV_ALIGN_BOTTOM_MID, 0, -14);
  lv_obj_set_style_bg_color(card, theme::color(theme::DEV_SURFACE), 0);
  lv_obj_set_style_bg_opa(card, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(card, 0, 0);
  lv_obj_set_style_radius(card, 10, 0);
  lv_obj_set_style_pad_hor(card, 12, 0);
  lv_obj_set_style_pad_ver(card, 6, 0);
  lv_obj_clear_flag(card, LV_OBJ_FLAG_SCROLLABLE);

  lv_obj_t* lbl_cap = lv_label_create(card);
  lv_label_set_text(lbl_cap, "다음 세트");
  lv_obj_set_style_text_font(lbl_cap, theme::font_14(), 0);
  lv_obj_set_style_text_color(lbl_cap, theme::color(theme::DEV_TEXT_MUTE), 0);
  lv_obj_align(lbl_cap, LV_ALIGN_LEFT_MID, 0, 0);

  g_lbl_next = lv_label_create(card);
  lv_label_set_text(g_lbl_next, "2 / 3");
  lv_obj_set_style_text_font(g_lbl_next, theme::font_20(), 0);
  lv_obj_set_style_text_color(g_lbl_next, theme::color(theme::DEV_PRIMARY_LT), 0);
  lv_obj_align(g_lbl_next, LV_ALIGN_RIGHT_MID, 0, 0);
}

void rest_set_remaining(uint16_t remaining_sec) {
  if (g_lbl_remaining) {
    char buf[8];
    std::snprintf(buf, sizeof(buf), "%u", (unsigned)remaining_sec);
    lv_label_set_text(g_lbl_remaining, buf);
  }
  if (g_arc) {
    // Arc 는 경과 (REST_TOTAL_SEC - remaining) 으로 채움 — 시계방향 진행.
    int elapsed = REST_TOTAL_SEC - (int)remaining_sec;
    if (elapsed < 0) elapsed = 0;
    if (elapsed > REST_TOTAL_SEC) elapsed = REST_TOTAL_SEC;
    lv_arc_set_value(g_arc, elapsed);
  }
}

void rest_set_next_set(uint8_t next_set, uint8_t total_sets) {
  if (!g_lbl_next) return;
  char buf[12];
  std::snprintf(buf, sizeof(buf), "%u / %u",
                (unsigned)next_set, (unsigned)total_sets);
  lv_label_set_text(g_lbl_next, buf);
}

}  // namespace screens
