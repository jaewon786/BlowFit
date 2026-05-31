// 페어링 대기 화면 (PairWait) — implementation.

#include "display/screens/screen_pairwait.h"
#include "display/screens/status_bar.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>

namespace screens {

void pairwait_show() {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  // 디자인 ScrPairWait — 흰 배경.
  lv_obj_set_style_bg_color(scr, theme::color(theme::DEV_SURFACE), 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // ---------- 1. 상단 status bar (BT 아이콘 + 배터리) ----------
  // 페어링 대기 = 미연결 → BT 아이콘 muted. (배터리는 placeholder, 추후 실값)
  make_status_bar(scr, /*connected=*/false, /*battery=*/76);

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
  lv_label_set_text(title, "페어링 대기 중");
  lv_obj_set_style_text_font(title, theme::font_20(), 0);
  lv_obj_set_style_text_color(title, theme::color(theme::DEV_TEXT), 0);
  lv_obj_align(title, LV_ALIGN_CENTER, 0, 42);

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
