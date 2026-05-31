// 오류 화면 (Error) — implementation. device-display.jsx ScrError.
// red 세로 gradient + red 원 아이콘 + 제목 + 안내문.

#include "display/screens/screen_error.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>

namespace screens {

void error_show(ErrorKind kind) {
  const bool disc = (kind == ErrorKind::Disconnect);

  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  lv_obj_set_style_bg_color(scr, theme::color(0xFFF0EF), 0);
  lv_obj_set_style_bg_grad_color(scr, theme::color(0xFFDAD7), 0);
  lv_obj_set_style_bg_grad_dir(scr, LV_GRAD_DIR_VER, 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // red 원 + 흰 아이콘 (BT / 배터리).
  lv_obj_t* circle = lv_obj_create(scr);
  lv_obj_set_size(circle, 88, 88);
  lv_obj_align(circle, LV_ALIGN_TOP_MID, 0, 60);
  lv_obj_set_style_bg_color(circle, theme::color(theme::DEV_RED), 0);
  lv_obj_set_style_radius(circle, LV_RADIUS_CIRCLE, 0);
  lv_obj_set_style_border_width(circle, 0, 0);
  lv_obj_set_style_shadow_color(circle, theme::color(theme::DEV_RED), 0);
  lv_obj_set_style_shadow_opa(circle, LV_OPA_40, 0);
  lv_obj_set_style_shadow_width(circle, 20, 0);
  lv_obj_clear_flag(circle, LV_OBJ_FLAG_SCROLLABLE);

  lv_obj_t* icon = lv_label_create(circle);
  // LV_SYMBOL_* 는 Montserrat (PUA) 글리프.
  lv_label_set_text(icon, disc ? LV_SYMBOL_BLUETOOTH : LV_SYMBOL_BATTERY_EMPTY);
  lv_obj_set_style_text_font(icon, &lv_font_montserrat_28, 0);
  lv_obj_set_style_text_color(icon, theme::color(0xFFFFFF), 0);
  lv_obj_center(icon);

  lv_obj_t* title = lv_label_create(scr);
  lv_label_set_text(title, disc ? "연결 끊김" : "충전 필요");
  lv_obj_set_style_text_font(title, theme::font_20(), 0);
  lv_obj_set_style_text_color(title, theme::color(theme::DEV_TEXT), 0);
  lv_obj_align(title, LV_ALIGN_TOP_MID, 0, 164);

  lv_obj_t* sub = lv_label_create(scr);
  lv_label_set_text(sub, disc ? "블루투스를\n다시 연결하세요" : "배터리를\n충전하세요");
  lv_obj_set_style_text_font(sub, theme::font_14(), 0);
  lv_obj_set_style_text_color(sub, theme::color(theme::DEV_TEXT_SUB), 0);
  lv_obj_set_style_text_align(sub, LV_TEXT_ALIGN_CENTER, 0);
  lv_obj_align(sub, LV_ALIGN_TOP_MID, 0, 196);
}

}  // namespace screens
