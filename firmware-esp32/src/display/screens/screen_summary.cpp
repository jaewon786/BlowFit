// 결과 화면 (Summary / 훈련 완료) — implementation.
//
// 설계: BlowFit.html device-display.jsx ScrComplete (기기 07).
//   그린 세로 gradient (#EAFBF0 → #CFEFDC), 상단 status bar,
//   270° green ring (100%) + 중앙 큰 아이콘(디자인 👍, 폰트 미지원이라 ✓ 대체),
//   "훈련 완료!" 텍스트. 통계는 기기에 표시하지 않음 (앱에서 확인).

#include "display/screens/screen_summary.h"
#include "display/screens/status_bar.h"
#include "display/theme.h"
#include "battery.h"

#include <lvgl.h>

namespace screens {

void summary_show(const SummaryData& data) {
  (void)data;   // 디자인 ScrComplete 는 통계 미표시 — 상세는 앱에서 확인.

  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  // 디자인 ScrComplete — 그린 세로 gradient.
  lv_obj_set_style_bg_color(scr, theme::color(0xEAFBF0), 0);
  lv_obj_set_style_bg_grad_color(scr, theme::color(0xCFEFDC), 0);
  lv_obj_set_style_bg_grad_dir(scr, LV_GRAD_DIR_VER, 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // ---------- 1. 상단 status bar ----------
  make_status_bar(scr, /*connected=*/true, /*battery=*/battery::percent());

  // ---------- 2. 완료 ring (270° green, 100%) ----------
  lv_obj_t* arc = lv_arc_create(scr);
  lv_obj_set_size(arc, 120, 120);
  lv_obj_align(arc, LV_ALIGN_TOP_MID, 0, 64);
  lv_arc_set_range(arc, 0, 100);
  lv_arc_set_value(arc, 100);
  lv_arc_set_bg_angles(arc, 135, 45);   // 270° 호 (위쪽 gap) — 디자인 기본 LvArc
  lv_arc_set_angles(arc, 135, 45);      // value=100% → 전체 채움
  lv_arc_set_rotation(arc, 0);
  lv_obj_set_style_arc_color(arc, theme::color(theme::DEV_DIVIDER), LV_PART_MAIN);
  lv_obj_set_style_arc_width(arc, 9, LV_PART_MAIN);
  lv_obj_set_style_arc_color(arc, theme::color(theme::DEV_GREEN), LV_PART_INDICATOR);
  lv_obj_set_style_arc_width(arc, 9, LV_PART_INDICATOR);
  lv_obj_remove_style(arc, NULL, LV_PART_KNOB);
  lv_obj_clear_flag(arc, LV_OBJ_FLAG_CLICKABLE);

  // ring 중앙 아이콘 — 디자인은 👍(이모지). LVGL 폰트에 글리프 없어 그린 ✓ 로 대체.
  lv_obj_t* lbl_icon = lv_label_create(scr);
  lv_label_set_text(lbl_icon, LV_SYMBOL_OK);
  lv_obj_set_style_text_font(lbl_icon, &lv_font_montserrat_48, 0);
  lv_obj_set_style_text_color(lbl_icon, theme::color(theme::DEV_GREEN), 0);
  lv_obj_align_to(lbl_icon, arc, LV_ALIGN_CENTER, 0, 0);

  // ---------- 3. "훈련 완료!" (ring 아래) ----------
  lv_obj_t* lbl_title = lv_label_create(scr);
  lv_label_set_text(lbl_title, "훈련 완료!");
  // "훈련 준비" 화면 타이틀과 동일 크기/굵기 (Pretendard Bold 28).
  lv_obj_set_style_text_font(lbl_title, theme::font_28(), 0);
  lv_obj_set_style_text_color(lbl_title, theme::color(theme::DEV_TEXT), 0);
  lv_obj_align_to(lbl_title, arc, LV_ALIGN_OUT_BOTTOM_MID, 0, 14);
}

}  // namespace screens
