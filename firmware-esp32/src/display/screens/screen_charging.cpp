// 충전 화면 (Charging) — implementation. device-display.jsx ScrCharging.
// green 세로 gradient + 배터리 arc(잔량) + 충전 심볼 + % + "충전 중".

#include "display/screens/screen_charging.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>
#include <cstdio>

namespace screens {

void charging_show(uint8_t battery_pct) {
  if (battery_pct > 100) battery_pct = 100;

  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  lv_obj_set_style_bg_color(scr, theme::color(0xEAFBF0), 0);
  lv_obj_set_style_bg_grad_color(scr, theme::color(0xCFEFDC), 0);
  lv_obj_set_style_bg_grad_dir(scr, LV_GRAD_DIR_VER, 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // 배터리 잔량 arc.
  lv_obj_t* arc = lv_arc_create(scr);
  lv_obj_set_size(arc, 140, 140);
  lv_obj_align(arc, LV_ALIGN_TOP_MID, 0, 44);
  lv_arc_set_range(arc, 0, 100);
  lv_arc_set_value(arc, battery_pct);
  lv_arc_set_bg_angles(arc, 0, 360);
  lv_arc_set_rotation(arc, 270);
  lv_obj_set_style_arc_color(arc, theme::color(theme::DEV_DIVIDER), LV_PART_MAIN);
  lv_obj_set_style_arc_width(arc, 10, LV_PART_MAIN);
  lv_obj_set_style_arc_color(arc, theme::color(theme::DEV_GREEN), LV_PART_INDICATOR);
  lv_obj_set_style_arc_width(arc, 10, LV_PART_INDICATOR);
  lv_obj_remove_style(arc, NULL, LV_PART_KNOB);
  lv_obj_clear_flag(arc, LV_OBJ_FLAG_CLICKABLE);

  // 가운데 충전 심볼 (Montserrat) + %.
  lv_obj_t* icon = lv_label_create(scr);
  lv_label_set_text(icon, LV_SYMBOL_CHARGE);
  lv_obj_set_style_text_font(icon, &lv_font_montserrat_28, 0);
  lv_obj_set_style_text_color(icon, theme::color(theme::DEV_GREEN), 0);
  lv_obj_align_to(icon, arc, LV_ALIGN_CENTER, 0, -16);

  lv_obj_t* pct = lv_label_create(scr);
  char buf[8];
  std::snprintf(buf, sizeof(buf), "%u%%", (unsigned)battery_pct);
  lv_label_set_text(pct, buf);
  lv_obj_set_style_text_font(pct, theme::font_28(), 0);
  lv_obj_set_style_text_color(pct, theme::color(theme::DEV_TEXT), 0);
  lv_obj_align_to(pct, arc, LV_ALIGN_CENTER, 0, 16);

  // "충전 중" (앰버).
  lv_obj_t* title = lv_label_create(scr);
  lv_label_set_text(title, "충전 중");
  lv_obj_set_style_text_font(title, theme::font_20(), 0);
  lv_obj_set_style_text_color(title, theme::color(theme::DEV_AMBER), 0);
  lv_obj_align(title, LV_ALIGN_TOP_MID, 0, 198);
}

}  // namespace screens
