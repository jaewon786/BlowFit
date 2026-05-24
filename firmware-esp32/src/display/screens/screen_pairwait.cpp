// 페어링 대기 화면 (PairWait) — implementation.

#include "display/screens/screen_pairwait.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>

namespace screens {

void pairwait_show() {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  lv_obj_set_style_bg_color(scr, theme::color(theme::DEV_BG), 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // ---------- 1. 상단 status bar (BT off — gray dot) ----------
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
  lv_obj_set_style_bg_color(bt_dot, theme::color(theme::DEV_TEXT_MUTE), 0);
  lv_obj_set_style_border_width(bt_dot, 0, 0);
  lv_obj_set_style_radius(bt_dot, LV_RADIUS_CIRCLE, 0);
  lv_obj_clear_flag(bt_dot, LV_OBJ_FLAG_SCROLLABLE);

  // ---------- 2. 중앙 80×80 파란 원 + BT 심볼 (glow) ----------
  lv_obj_t* circle = lv_obj_create(scr);
  lv_obj_set_size(circle, 80, 80);
  lv_obj_align(circle, LV_ALIGN_CENTER, 0, -32);
  lv_obj_set_style_bg_color(circle, theme::color(theme::DEV_PRIMARY), 0);
  lv_obj_set_style_bg_opa(circle, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(circle, 0, 0);
  lv_obj_set_style_radius(circle, LV_RADIUS_CIRCLE, 0);
  lv_obj_set_style_pad_all(circle, 0, 0);
  // glow 효과
  lv_obj_set_style_shadow_color(circle, theme::color(theme::DEV_PRIMARY), 0);
  lv_obj_set_style_shadow_opa(circle, LV_OPA_60, 0);
  lv_obj_set_style_shadow_width(circle, 28, 0);
  lv_obj_set_style_shadow_spread(circle, 2, 0);
  lv_obj_clear_flag(circle, LV_OBJ_FLAG_SCROLLABLE);

  // BT 심볼 (LVGL 내장 FontAwesome subset)
  lv_obj_t* bt_sym = lv_label_create(circle);
  lv_label_set_text(bt_sym, LV_SYMBOL_BLUETOOTH);
  lv_obj_set_style_text_font(bt_sym, &lv_font_montserrat_48, 0);
  lv_obj_set_style_text_color(bt_sym, theme::color(0xFFFFFF), 0);
  lv_obj_center(bt_sym);

  // ---------- 3. 텍스트 ----------
  lv_obj_t* title = lv_label_create(scr);
  lv_label_set_text(title, "연결 대기 중");
  lv_obj_set_style_text_font(title, theme::font_20(), 0);
  lv_obj_set_style_text_color(title, theme::color(theme::DEV_TEXT), 0);
  lv_obj_align(title, LV_ALIGN_CENTER, 0, 42);

  lv_obj_t* sub = lv_label_create(scr);
  lv_label_set_text(sub, "BlowFit");
  lv_obj_set_style_text_font(sub, theme::font_14(), 0);
  lv_obj_set_style_text_color(sub, theme::color(theme::DEV_TEXT_SUB), 0);
  lv_obj_align(sub, LV_ALIGN_CENTER, 0, 72);

  // ---------- 4. 하단 spinner (ripple 애니메이션 대체) ----------
  lv_obj_t* spinner = lv_spinner_create(scr);
  lv_obj_set_size(spinner, 28, 28);
  lv_obj_align(spinner, LV_ALIGN_BOTTOM_MID, 0, -32);
  lv_obj_set_style_arc_color(spinner, theme::color(theme::DEV_DIVIDER), LV_PART_MAIN);
  lv_obj_set_style_arc_width(spinner, 3, LV_PART_MAIN);
  lv_obj_set_style_arc_opa(spinner, LV_OPA_40, LV_PART_MAIN);
  lv_obj_set_style_arc_color(spinner, theme::color(theme::DEV_PRIMARY_LT), LV_PART_INDICATOR);
  lv_obj_set_style_arc_width(spinner, 3, LV_PART_INDICATOR);
}

}  // namespace screens
