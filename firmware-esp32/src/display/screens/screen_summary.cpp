// 결과 화면 (Summary) — implementation.
//
// 설계: BlowFit.html ScrComplete — 다크 + 상단 어두운 청색 그라데이션 효과
// (단색으로 대체), 상단 status bar, Arc 100% (green) + 큰 체크 심볼,
// "훈련 완료" 텍스트, 호기/흡기 평균 2-column grid, 하단 안내문.

#include "display/screens/screen_summary.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>
#include <cstdio>

namespace screens {

void summary_show(const SummaryData& data) {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  lv_obj_set_style_bg_color(scr, theme::color(theme::DEV_BG), 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // ---------- 1. 상단 status bar ----------
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
  lv_obj_set_style_bg_color(bt_dot, theme::color(theme::DEV_PRIMARY_LT), 0);
  lv_obj_set_style_border_width(bt_dot, 0, 0);
  lv_obj_set_style_radius(bt_dot, LV_RADIUS_CIRCLE, 0);
  lv_obj_clear_flag(bt_dot, LV_OBJ_FLAG_SCROLLABLE);

  lv_obj_t* batt = lv_label_create(bar);
  lv_label_set_text(batt, "73%");
  lv_obj_set_style_text_font(batt, theme::font_14(), 0);
  lv_obj_set_style_text_color(batt, theme::color(theme::DEV_TEXT_SUB), 0);
  lv_obj_align(batt, LV_ALIGN_RIGHT_MID, 0, 0);

  // ---------- 2. 완료 Arc (100% green) ----------
  lv_obj_t* arc = lv_arc_create(scr);
  lv_obj_set_size(arc, 120, 120);
  lv_obj_align(arc, LV_ALIGN_TOP_MID, 0, 26);
  lv_arc_set_range(arc, 0, 100);
  lv_arc_set_value(arc, 100);
  lv_arc_set_bg_angles(arc, 0, 360);
  lv_arc_set_angles(arc, 0, 360);
  lv_arc_set_rotation(arc, 0);
  lv_obj_set_style_arc_color(arc, theme::color(theme::DEV_DIVIDER), LV_PART_MAIN);
  lv_obj_set_style_arc_width(arc, 9, LV_PART_MAIN);
  lv_obj_set_style_arc_color(arc, theme::color(theme::DEV_GREEN), LV_PART_INDICATOR);
  lv_obj_set_style_arc_width(arc, 9, LV_PART_INDICATOR);
  lv_obj_remove_style(arc, NULL, LV_PART_KNOB);
  lv_obj_clear_flag(arc, LV_OBJ_FLAG_CLICKABLE);

  // Arc 중앙 — 체크 심볼 (LVGL 내장)
  lv_obj_t* lbl_check = lv_label_create(scr);
  lv_label_set_text(lbl_check, LV_SYMBOL_OK);
  lv_obj_set_style_text_font(lbl_check, &lv_font_montserrat_48, 0);
  lv_obj_set_style_text_color(lbl_check, theme::color(theme::DEV_GREEN), 0);
  lv_obj_align_to(lbl_check, arc, LV_ALIGN_CENTER, 0, 0);

  // ---------- 3. "훈련 완료" ----------
  lv_obj_t* lbl_title = lv_label_create(scr);
  lv_label_set_text(lbl_title, "훈련 완료");
  lv_obj_set_style_text_font(lbl_title, theme::font_20(), 0);
  lv_obj_set_style_text_color(lbl_title, theme::color(theme::DEV_TEXT), 0);
  lv_obj_align(lbl_title, LV_ALIGN_TOP_MID, 0, 156);

  // ---------- 4. 통계 grid (호기 / 흡기 평균) ----------
  // 현재 SummaryData 는 avg_pressure (단일) 만 보유 — 호기/흡기 동일값 표시
  // 후속 마일스톤에서 SummaryData 에 avg_exhale / avg_inhale 분리 시 갱신.
  char buf_avg[12], buf_max[12], buf_hit[12];
  std::snprintf(buf_avg, sizeof(buf_avg), "%.1f", data.avg_pressure);
  std::snprintf(buf_max, sizeof(buf_max), "%.1f", data.max_pressure);
  std::snprintf(buf_hit, sizeof(buf_hit), "%u%%",
                (unsigned)data.hit_percent);

  auto make_stat_card = [&](int x_align_off, const char* cap,
                            const char* val, uint32_t val_color) {
    lv_obj_t* card = lv_obj_create(scr);
    lv_obj_set_size(card, 68, 42);
    lv_obj_align(card, LV_ALIGN_TOP_MID, x_align_off, 186);
    lv_obj_set_style_bg_color(card, theme::color(theme::DEV_SURFACE), 0);
    lv_obj_set_style_bg_opa(card, LV_OPA_COVER, 0);
    lv_obj_set_style_border_width(card, 0, 0);
    lv_obj_set_style_radius(card, 8, 0);
    lv_obj_set_style_pad_hor(card, 8, 0);
    lv_obj_set_style_pad_ver(card, 4, 0);
    lv_obj_clear_flag(card, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t* lbl_cap = lv_label_create(card);
    lv_label_set_text(lbl_cap, cap);
    lv_obj_set_style_text_font(lbl_cap, theme::font_14(), 0);
    lv_obj_set_style_text_color(lbl_cap, theme::color(theme::DEV_TEXT_MUTE), 0);
    lv_obj_align(lbl_cap, LV_ALIGN_TOP_MID, 0, 0);

    lv_obj_t* lbl_val = lv_label_create(card);
    lv_label_set_text(lbl_val, val);
    lv_obj_set_style_text_font(lbl_val, theme::font_20(), 0);
    lv_obj_set_style_text_color(lbl_val, theme::color(val_color), 0);
    lv_obj_align(lbl_val, LV_ALIGN_BOTTOM_MID, 0, -2);
  };

  // 좌: 호기 평균 (BLUE_LT), 우: 흡기 평균 (CYAN). 둘 다 avg_pressure 사용.
  make_stat_card(-36, "호기 평균", buf_avg, theme::DEV_PRIMARY_LT);
  make_stat_card(+36, "흡기 평균", buf_avg, theme::DEV_CYAN);

  // ---------- 5. 추가 통계 (성공률 / 최대) — 더 작은 라인 ----------
  char buf_extra[32];
  std::snprintf(buf_extra, sizeof(buf_extra), "max %s   성공률 %s",
                buf_max, buf_hit);
  lv_obj_t* lbl_extra = lv_label_create(scr);
  lv_label_set_text(lbl_extra, buf_extra);
  lv_obj_set_style_text_font(lbl_extra, theme::font_14(), 0);
  lv_obj_set_style_text_color(lbl_extra,
                              data.hit_percent >= 60
                                  ? theme::color(theme::DEV_GREEN)
                                  : theme::color(theme::DEV_AMBER), 0);
  lv_obj_align(lbl_extra, LV_ALIGN_TOP_MID, 0, 234);

  // ---------- 6. 하단 안내문 ("앱/스/를/우" 폰트 미포함 → 영문) ----------
  lv_obj_t* lbl_hint = lv_label_create(scr);
  lv_label_set_text(lbl_hint, "Check app for details");
  lv_obj_set_style_text_font(lbl_hint, theme::font_14(), 0);
  lv_obj_set_style_text_color(lbl_hint, theme::color(theme::DEV_TEXT_MUTE), 0);
  lv_obj_align(lbl_hint, LV_ALIGN_BOTTOM_MID, 0, -14);
}

}  // namespace screens
