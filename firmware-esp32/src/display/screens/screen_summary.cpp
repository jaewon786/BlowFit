// 결과 화면 (Summary) — implementation.

#include "display/screens/screen_summary.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>
#include <cstdio>

namespace screens {

namespace {

  /// 한 행의 통계 — 라벨 + 값 좌우 정렬.
  void make_stat_row(lv_obj_t* parent, int y_offset, const char* label,
                     const char* value, uint32_t value_color) {
    lv_obj_t* lbl = lv_label_create(parent);
    lv_label_set_text(lbl, label);
    lv_obj_set_style_text_font(lbl, theme::font_14(), 0);
    lv_obj_set_style_text_color(lbl, theme::color(theme::GRAY_400), 0);
    lv_obj_align(lbl, LV_ALIGN_TOP_LEFT, 16, y_offset);

    lv_obj_t* val = lv_label_create(parent);
    lv_label_set_text(val, value);
    lv_obj_set_style_text_font(val, theme::font_20(), 0);
    lv_obj_set_style_text_color(val, theme::color(value_color), 0);
    lv_obj_align(val, LV_ALIGN_TOP_RIGHT, -16, y_offset - 4);
  }

}  // anonymous namespace

void summary_show(const SummaryData& data) {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  lv_obj_set_style_bg_color(scr, theme::color(theme::GRAY_900), 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // 상단 — "훈련 완료"
  lv_obj_t* lbl_title = lv_label_create(scr);
  lv_label_set_text(lbl_title, "훈련 완료");
  lv_obj_set_style_text_font(lbl_title, theme::font_28(), 0);
  lv_obj_set_style_text_color(lbl_title, theme::color(theme::GREEN_500), 0);
  lv_obj_align(lbl_title, LV_ALIGN_TOP_MID, 0, 20);

  // 통계 4행.
  char buf_avg[16], buf_max[16], buf_dur[16], buf_hit[16];
  std::snprintf(buf_avg, sizeof(buf_avg), "%.1f", data.avg_pressure);
  std::snprintf(buf_max, sizeof(buf_max), "%.1f", data.max_pressure);
  // duration mm:ss
  const uint16_t mm = data.duration_sec / 60;
  const uint16_t ss = data.duration_sec % 60;
  std::snprintf(buf_dur, sizeof(buf_dur), "%u:%02u", (unsigned)mm, (unsigned)ss);
  std::snprintf(buf_hit, sizeof(buf_hit), "%u%%", (unsigned)data.hit_percent);

  make_stat_row(scr, 78,  "평균",   buf_avg, theme::BLUE_400);
  make_stat_row(scr, 118, "최대",   buf_max, theme::BLUE_400);
  make_stat_row(scr, 158, "지속",   buf_dur, 0xFFFFFF);
  make_stat_row(scr, 198, "성공률", buf_hit,
                data.hit_percent >= 60 ? theme::GREEN_500 : theme::AMBER_500);

  // 하단 안내문 — 응원 + 자동 복귀 안내.
  lv_obj_t* lbl_hint = lv_label_create(scr);
  lv_label_set_text(lbl_hint, "잘하셨어요");
  lv_obj_set_style_text_font(lbl_hint, theme::font_20(), 0);
  lv_obj_set_style_text_color(lbl_hint, theme::color(0xFFFFFF), 0);
  lv_obj_align(lbl_hint, LV_ALIGN_BOTTOM_MID, 0, -32);

  // 세트 정보 (작게)
  char buf_set[16];
  std::snprintf(buf_set, sizeof(buf_set), "세트 %u/%u 완료",
                (unsigned)data.completed_sets, (unsigned)data.total_sets);
  lv_obj_t* lbl_set = lv_label_create(scr);
  lv_label_set_text(lbl_set, buf_set);
  lv_obj_set_style_text_font(lbl_set, theme::font_14(), 0);
  lv_obj_set_style_text_color(lbl_set, theme::color(theme::GRAY_400), 0);
  lv_obj_align(lbl_set, LV_ALIGN_BOTTOM_MID, 0, -10);
}

}  // namespace screens
