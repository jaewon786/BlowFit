// 부팅 / 로딩 화면 (Boot) — implementation.

#include "display/screens/screen_boot.h"
#include "display/theme.h"
#include "display/assets/brelow_mascot.h"
#include "config.h"

#include <lvgl.h>

namespace screens {

void boot_show() {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  // 디자인 boot — 흰→연하늘 세로 gradient (#FFFFFF → #EDF4FB).
  lv_obj_set_style_bg_color(scr, theme::color(0xFFFFFF), 0);
  lv_obj_set_style_bg_grad_color(scr, theme::color(0xEDF4FB), 0);
  lv_obj_set_style_bg_grad_dir(scr, LV_GRAD_DIR_VER, 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // ---------- 마스코트 + wordmark 를 세로 컬럼으로 묶어 화면 정중앙 정렬 ----------
  lv_obj_t* col = lv_obj_create(scr);
  lv_obj_set_size(col, LV_SIZE_CONTENT, LV_SIZE_CONTENT);
  lv_obj_center(col);
  lv_obj_set_style_bg_opa(col, LV_OPA_TRANSP, 0);
  lv_obj_set_style_border_width(col, 0, 0);
  lv_obj_set_style_pad_all(col, 0, 0);
  lv_obj_set_flex_flow(col, LV_FLEX_FLOW_COLUMN);
  lv_obj_set_flex_align(col, LV_FLEX_ALIGN_CENTER,
                        LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);
  lv_obj_set_style_pad_row(col, 18, 0);   // 마스코트 ↔ wordmark 간격
  lv_obj_clear_flag(col, LV_OBJ_FLAG_SCROLLABLE);

  // 1. BRELOW 마스코트 이미지 (112×112).
  lv_obj_t* mascot = lv_image_create(col);
  lv_image_set_src(mascot, &brelow_mascot);
  lv_obj_clear_flag(mascot, LV_OBJ_FLAG_SCROLLABLE);

  // 2. BRELOW wordmark — BREL(검정) + O(파랑) + W(검정), O 만 파랑 강조.
  lv_obj_t* row = lv_obj_create(col);
  lv_obj_set_size(row, LV_SIZE_CONTENT, LV_SIZE_CONTENT);
  lv_obj_set_style_bg_opa(row, LV_OPA_TRANSP, 0);
  lv_obj_set_style_border_width(row, 0, 0);
  lv_obj_set_style_pad_all(row, 0, 0);
  lv_obj_set_flex_flow(row, LV_FLEX_FLOW_ROW);
  lv_obj_set_flex_align(row, LV_FLEX_ALIGN_CENTER,
                        LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);
  lv_obj_set_style_pad_column(row, 0, 0);
  lv_obj_clear_flag(row, LV_OBJ_FLAG_SCROLLABLE);

  struct Part { const char* t; uint32_t c; };
  const Part parts[] = {
    {"BREL", 0x0A0A0A}, {"O", 0x0A84FF}, {"W", 0x0A0A0A},
  };
  for (auto& p : parts) {
    lv_obj_t* l = lv_label_create(row);
    lv_label_set_text(l, p.t);
    lv_obj_set_style_text_font(l, theme::font_28(), 0);
    lv_obj_set_style_text_color(l, theme::color(p.c), 0);
  }
  // 하단 로딩 spinner 제거 (요청) — 마스코트 + wordmark 만 표시.
}

}  // namespace screens
