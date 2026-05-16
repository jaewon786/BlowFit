// 휴식 화면 (Rest) — implementation.

#include "display/screens/screen_rest.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>
#include <cstdio>

namespace screens {

namespace {
  lv_obj_t* g_lbl_remaining = nullptr;
  lv_obj_t* g_lbl_next      = nullptr;
}

void rest_show() {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  lv_obj_set_style_bg_color(scr, theme::color(theme::GRAY_900), 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // 상단 — "휴식"
  lv_obj_t* lbl_title = lv_label_create(scr);
  lv_label_set_text(lbl_title, "휴식");
  lv_obj_set_style_text_font(lbl_title, theme::font_28(), 0);
  lv_obj_set_style_text_color(lbl_title, theme::color(theme::BLUE_400), 0);
  lv_obj_align(lbl_title, LV_ALIGN_TOP_MID, 0, 30);

  // 가운데 — 큰 카운트다운 (Pretendard 28pt — 한글 안 쓰니까 ASCII)
  g_lbl_remaining = lv_label_create(scr);
  lv_label_set_text(g_lbl_remaining, "10");
  lv_obj_set_style_text_font(g_lbl_remaining, theme::font_28(), 0);
  lv_obj_set_style_text_color(g_lbl_remaining, theme::color(0xFFFFFF), 0);
  lv_obj_align(g_lbl_remaining, LV_ALIGN_CENTER, 0, -10);

  // "초"
  lv_obj_t* lbl_unit = lv_label_create(scr);
  lv_label_set_text(lbl_unit, "초");
  lv_obj_set_style_text_font(lbl_unit, theme::font_20(), 0);
  lv_obj_set_style_text_color(lbl_unit, theme::color(theme::GRAY_400), 0);
  lv_obj_align(lbl_unit, LV_ALIGN_CENTER, 0, 30);

  // 안내문
  lv_obj_t* lbl_hint = lv_label_create(scr);
  lv_label_set_text(lbl_hint, "잠시 쉬어요");
  lv_obj_set_style_text_font(lbl_hint, theme::font_20(), 0);
  lv_obj_set_style_text_color(lbl_hint, theme::color(0xFFFFFF), 0);
  lv_obj_align(lbl_hint, LV_ALIGN_BOTTOM_MID, 0, -56);

  // 다음 세트
  g_lbl_next = lv_label_create(scr);
  lv_label_set_text(g_lbl_next, "다음 세트 2/3");
  lv_obj_set_style_text_font(g_lbl_next, theme::font_14(), 0);
  lv_obj_set_style_text_color(g_lbl_next, theme::color(theme::GRAY_400), 0);
  lv_obj_align(g_lbl_next, LV_ALIGN_BOTTOM_MID, 0, -24);
}

void rest_set_remaining(uint16_t remaining_sec) {
  if (!g_lbl_remaining) return;
  char buf[8];
  std::snprintf(buf, sizeof(buf), "%u", (unsigned)remaining_sec);
  lv_label_set_text(g_lbl_remaining, buf);
}

void rest_set_next_set(uint8_t next_set, uint8_t total_sets) {
  if (!g_lbl_next) return;
  char buf[20];
  std::snprintf(buf, sizeof(buf), "다음 세트 %u/%u",
                (unsigned)next_set, (unsigned)total_sets);
  lv_label_set_text(g_lbl_next, buf);
}

}  // namespace screens
