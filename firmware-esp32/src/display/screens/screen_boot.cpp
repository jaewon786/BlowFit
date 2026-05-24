// 부팅 / 로딩 화면 (Boot) — implementation.

#include "display/screens/screen_boot.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>

namespace screens {

void boot_show() {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  // 설계의 radial gradient (#002a7a → #0a0c14) 를 단색으로 단순화.
  lv_obj_set_style_bg_color(scr, theme::color(0x0a0c14), 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // ---------- 1. 80×80 파랑 로고 원 (중앙 상단) ----------
  lv_obj_t* circle = lv_obj_create(scr);
  lv_obj_set_size(circle, 80, 80);
  lv_obj_align(circle, LV_ALIGN_CENTER, 0, -42);
  lv_obj_set_style_bg_color(circle, theme::color(theme::DEV_PRIMARY), 0);
  lv_obj_set_style_bg_opa(circle, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(circle, 0, 0);
  lv_obj_set_style_radius(circle, LV_RADIUS_CIRCLE, 0);
  lv_obj_set_style_pad_all(circle, 0, 0);
  // 빛 효과 — 외곽선 (glow 대체)
  lv_obj_set_style_shadow_color(circle, theme::color(theme::DEV_PRIMARY), 0);
  lv_obj_set_style_shadow_opa(circle, LV_OPA_50, 0);
  lv_obj_set_style_shadow_width(circle, 24, 0);
  lv_obj_set_style_shadow_spread(circle, 2, 0);
  lv_obj_clear_flag(circle, LV_OBJ_FLAG_SCROLLABLE);

  // ---------- 2. 가운데 흰 폐 모양 (좌/우 둥근 직사각형 + 중앙 기관지) ----------
  // 설계의 SVG path 를 LVGL primitive 로 단순 재현.
  // 기관지 (중앙 세로 작은 막대)
  lv_obj_t* trachea = lv_obj_create(circle);
  lv_obj_set_size(trachea, 4, 16);
  lv_obj_align(trachea, LV_ALIGN_TOP_MID, 0, 16);
  lv_obj_set_style_bg_color(trachea, theme::color(0xFFFFFF), 0);
  lv_obj_set_style_border_width(trachea, 0, 0);
  lv_obj_set_style_radius(trachea, 2, 0);
  lv_obj_set_style_pad_all(trachea, 0, 0);
  lv_obj_clear_flag(trachea, LV_OBJ_FLAG_SCROLLABLE);

  // 좌 폐엽
  lv_obj_t* left = lv_obj_create(circle);
  lv_obj_set_size(left, 18, 30);
  lv_obj_align(left, LV_ALIGN_CENTER, -12, 6);
  lv_obj_set_style_bg_color(left, theme::color(0xFFFFFF), 0);
  lv_obj_set_style_border_width(left, 0, 0);
  lv_obj_set_style_radius(left, 9, 0);
  lv_obj_set_style_pad_all(left, 0, 0);
  lv_obj_clear_flag(left, LV_OBJ_FLAG_SCROLLABLE);

  // 우 폐엽
  lv_obj_t* right = lv_obj_create(circle);
  lv_obj_set_size(right, 18, 30);
  lv_obj_align(right, LV_ALIGN_CENTER, 12, 6);
  lv_obj_set_style_bg_color(right, theme::color(0xFFFFFF), 0);
  lv_obj_set_style_border_width(right, 0, 0);
  lv_obj_set_style_radius(right, 9, 0);
  lv_obj_set_style_pad_all(right, 0, 0);
  lv_obj_clear_flag(right, LV_OBJ_FLAG_SCROLLABLE);

  // ---------- 3. "BlowFit" 텍스트 ----------
  lv_obj_t* title = lv_label_create(scr);
  lv_label_set_text(title, "BlowFit");
  lv_obj_set_style_text_font(title, theme::font_28(), 0);
  lv_obj_set_style_text_color(title, theme::color(theme::DEV_TEXT), 0);
  lv_obj_align(title, LV_ALIGN_CENTER, 0, 30);

  // ---------- 4. 하단 LVGL spinner ----------
  lv_obj_t* spinner = lv_spinner_create(scr);
  lv_obj_set_size(spinner, 28, 28);
  lv_obj_align(spinner, LV_ALIGN_BOTTOM_MID, 0, -32);
  // 트랙 (안 보이게 어둡게)
  lv_obj_set_style_arc_color(spinner, theme::color(theme::DEV_DIVIDER), LV_PART_MAIN);
  lv_obj_set_style_arc_width(spinner, 3, LV_PART_MAIN);
  lv_obj_set_style_arc_opa(spinner, LV_OPA_40, LV_PART_MAIN);
  // indicator (회전하는 호)
  lv_obj_set_style_arc_color(spinner, theme::color(theme::DEV_PRIMARY_LT), LV_PART_INDICATOR);
  lv_obj_set_style_arc_width(spinner, 3, LV_PART_INDICATOR);
}

}  // namespace screens
