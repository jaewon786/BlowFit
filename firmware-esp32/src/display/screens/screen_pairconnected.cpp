// 연결 완료 화면 (PairConnected) — implementation.

#include "display/screens/screen_pairconnected.h"
#include "display/screens/status_bar.h"
#include "display/theme.h"
#include "config.h"
#include "battery.h"

#include <lvgl.h>

namespace screens {

void pairconnected_show() {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  // 디자인 ScrPairConnected — 흰 배경.
  lv_obj_set_style_bg_color(scr, theme::color(theme::DEV_SURFACE), 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // ---------- 1. 상단 status bar (BT 아이콘 + 배터리) — 연결됨 ----------
  make_status_bar(scr, /*connected=*/true, /*battery=*/battery::percent());

  // ---------- 2. 중앙 80×80 초록 원 + 체크 심볼 (glow) ----------
  lv_obj_t* circle = lv_obj_create(scr);
  lv_obj_set_size(circle, 80, 80);
  lv_obj_align(circle, LV_ALIGN_CENTER, 0, -32);
  lv_obj_set_style_bg_color(circle, theme::color(theme::DEV_GREEN), 0);
  lv_obj_set_style_bg_opa(circle, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(circle, 0, 0);
  lv_obj_set_style_radius(circle, LV_RADIUS_CIRCLE, 0);
  lv_obj_set_style_pad_all(circle, 0, 0);
  lv_obj_set_style_shadow_color(circle, theme::color(theme::DEV_GREEN), 0);
  lv_obj_set_style_shadow_opa(circle, LV_OPA_60, 0);
  lv_obj_set_style_shadow_width(circle, 28, 0);
  lv_obj_set_style_shadow_spread(circle, 2, 0);
  lv_obj_clear_flag(circle, LV_OBJ_FLAG_SCROLLABLE);

  // 체크 심볼
  lv_obj_t* check = lv_label_create(circle);
  lv_label_set_text(check, LV_SYMBOL_OK);
  lv_obj_set_style_text_font(check, &lv_font_montserrat_48, 0);
  lv_obj_set_style_text_color(check, theme::color(0xFFFFFF), 0);
  lv_obj_center(check);

  // ---------- 3. 텍스트 ----------
  lv_obj_t* title = lv_label_create(scr);
  lv_label_set_text(title, "연결 완료");
  lv_obj_set_style_text_font(title, theme::font_28(), 0);
  lv_obj_set_style_text_color(title, theme::color(theme::DEV_TEXT), 0);
  lv_obj_align(title, LV_ALIGN_CENTER, 0, 42);

  lv_obj_t* sub = lv_label_create(scr);
  lv_label_set_text(sub, "훈련 준비가 되었습니다");
  lv_obj_set_style_text_font(sub, theme::font_14(), 0);
  lv_obj_set_style_text_color(sub, theme::color(theme::DEV_TEXT_SUB), 0);
  lv_obj_align(sub, LV_ALIGN_CENTER, 0, 80);
}

}  // namespace screens
