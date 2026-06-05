// 충전 화면 (Charging) — device-display.jsx ScrCharging.
// green 세로 gradient + 채워지는 애니메이션 arc + 충전 심볼 + "충전 중".
//
// ⚠️ 충전 중에는 VBAT 가 부풀려져(~4.3V) 실제 잔량을 알 수 없으므로 % 숫자를
//    표시하지 않는다(거짓 100% 방지). 대신 반복 채움 애니메이션으로 "충전 진행"
//    만 전달. 정확한 잔량은 USB 분리 후 대기 화면에서 확인.

#include "display/screens/screen_charging.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>

namespace screens {

namespace {
  // arc 의 rotation 을 0→360 으로 돌려 green 세그먼트가 한 방향으로 회전.
  void arcRotateCb(void* obj, int32_t v) {
    lv_arc_set_rotation(static_cast<lv_obj_t*>(obj), static_cast<uint16_t>(v));
  }
}

void charging_show() {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  lv_obj_set_style_bg_color(scr, theme::color(0xEAFBF0), 0);
  lv_obj_set_style_bg_grad_color(scr, theme::color(0xCFEFDC), 0);
  lv_obj_set_style_bg_grad_dir(scr, LV_GRAD_DIR_VER, 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // 채워지는 arc (잔량 숫자 아님 — 충전 진행 애니메이션).
  lv_obj_t* arc = lv_arc_create(scr);
  lv_obj_set_size(arc, 150, 150);
  lv_obj_align(arc, LV_ALIGN_TOP_MID, 0, 56);
  lv_arc_set_range(arc, 0, 100);
  lv_arc_set_value(arc, 25);  // 고정 길이 세그먼트(1/4 원) — 회전 스피너.
  lv_arc_set_bg_angles(arc, 0, 360);
  lv_obj_set_style_arc_color(arc, theme::color(theme::DEV_DIVIDER), LV_PART_MAIN);
  lv_obj_set_style_arc_width(arc, 10, LV_PART_MAIN);
  lv_obj_set_style_arc_color(arc, theme::color(theme::DEV_GREEN), LV_PART_INDICATOR);
  lv_obj_set_style_arc_width(arc, 10, LV_PART_INDICATOR);
  lv_obj_remove_style(arc, NULL, LV_PART_KNOB);
  lv_obj_clear_flag(arc, LV_OBJ_FLAG_CLICKABLE);

  // 한 방향 회전 스피너 — rotation 0→360 반복. 360==0 이라 이음새 없음.
  // (arc 삭제 시 LVGL 이 anim 자동 정리.)
  lv_anim_t a;
  lv_anim_init(&a);
  lv_anim_set_var(&a, arc);
  lv_anim_set_exec_cb(&a, arcRotateCb);
  lv_anim_set_values(&a, 0, 360);
  lv_anim_set_time(&a, 1800);
  lv_anim_set_repeat_count(&a, LV_ANIM_REPEAT_INFINITE);
  lv_anim_start(&a);

  // 가운데 충전 심볼 (Montserrat).
  lv_obj_t* icon = lv_label_create(scr);
  lv_label_set_text(icon, LV_SYMBOL_CHARGE);
  lv_obj_set_style_text_font(icon, &lv_font_montserrat_48, 0);
  lv_obj_set_style_text_color(icon, theme::color(theme::DEV_GREEN), 0);
  lv_obj_align_to(icon, arc, LV_ALIGN_CENTER, 0, 0);

  // "충전 중" (강조). 충전 중엔 정확한 잔량을 알 수 없어 % 는 표시하지 않음.
  lv_obj_t* title = lv_label_create(scr);
  lv_label_set_text(title, "충전 중");
  lv_obj_set_style_text_font(title, theme::font_28(), 0);
  lv_obj_set_style_text_color(title, theme::color(theme::DEV_TEXT), 0);
  lv_obj_align(title, LV_ALIGN_TOP_MID, 0, 240);
}

}  // namespace screens
