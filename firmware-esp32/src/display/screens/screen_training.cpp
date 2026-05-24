// 훈련 화면 (Training) — implementation.
//
// 설계: BlowFit.html ScrTraining — 다크 테마, 상단 status bar + phase chip
// + SET, 중앙 세로 양방향 bar (음압 위쪽 / 양압 아래쪽) + 큰 압력 숫자 +
// "목표 달성/±20+" chip, 하단 카드 (남은 시간 + set dots + 진행 bar).

#include "display/screens/screen_training.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>
#include <cstdio>
#include <cmath>

namespace screens {

namespace {

  // 화면 위젯 핸들.
  lv_obj_t* g_chip_phase     = nullptr;
  lv_obj_t* g_lbl_chip_text  = nullptr;
  lv_obj_t* g_lbl_set        = nullptr;     // "SET 1/3"

  // 세로 bar.
  lv_obj_t* g_bar_box        = nullptr;
  lv_obj_t* g_bar_active     = nullptr;     // 동적으로 위치/크기 조정
  lv_obj_t* g_lbl_value      = nullptr;
  lv_obj_t* g_lbl_unit       = nullptr;
  lv_obj_t* g_chip_target    = nullptr;
  lv_obj_t* g_lbl_target     = nullptr;

  // 하단 카드.
  lv_obj_t* g_card_bottom    = nullptr;
  lv_obj_t* g_lbl_remaining  = nullptr;
  lv_obj_t* g_set_dots[3]    = {nullptr, nullptr, nullptr};
  lv_obj_t* g_progress_bar   = nullptr;

  // 상태.
  TrainingPhase g_phase  = TrainingPhase::Exhale;
  float g_target_low     = 20.0f;
  float g_target_high    = 30.0f;
  uint8_t g_current_set  = 1;
  uint8_t g_total_sets   = 3;
  uint16_t g_remaining   = 0;
  float g_pressure       = 0.0f;

  // bar 기하 (설계 ScrTraining 의 비례를 170px 폭에 맞춰 조정).
  constexpr int BAR_TOTAL_H  = 168;   // 세로 bar 전체 높이
  constexpr int BAR_HALF_H   = 82;    // 위/아래 half (zero line 중심)
  constexpr int BAR_TOP_Y    = 32;    // status bar (20) + chip row (12) 아래
  constexpr int BAR_W        = 26;    // 세로 bar 폭
  constexpr int BAR_LEFT_X   = 14;    // 좌측 margin
  constexpr float MAX_P_CMH2O = 30.0f;   // bar full scale (±30)

  uint32_t phase_accent(TrainingPhase p) {
    switch (p) {
      case TrainingPhase::Exhale: return theme::DEV_PRIMARY;
      case TrainingPhase::Inhale: return theme::DEV_CYAN;
      case TrainingPhase::Rest:   return theme::DEV_TEXT_MUTE;
    }
    return theme::DEV_TEXT_MUTE;
  }

  const char* phase_label(TrainingPhase p) {
    switch (p) {
      case TrainingPhase::Exhale: return "내쉬기";
      case TrainingPhase::Inhale: return "들이쉬기";
      case TrainingPhase::Rest:   return "휴식";
    }
    return "";
  }

  /// chip 컬러 갱신 — 색만 변경, 위치/크기는 고정.
  void update_phase_chip(TrainingPhase p) {
    if (!g_chip_phase || !g_lbl_chip_text) return;
    const uint32_t c = phase_accent(p);
    lv_label_set_text(g_lbl_chip_text, phase_label(p));
    lv_obj_set_style_text_color(g_lbl_chip_text, theme::color(c), 0);
    // chip bg = 어두운 surface (반투명 효과 대체)
    lv_obj_set_style_bg_color(g_chip_phase, theme::color(theme::DEV_SURFACE), 0);
  }

}  // anonymous namespace

void training_show() {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  lv_obj_set_style_bg_color(scr, theme::color(theme::DEV_BG), 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // ---------- 1. 상단 status bar (170 × 20) ----------
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
  lv_label_set_text(batt, "74%");
  lv_obj_set_style_text_font(batt, theme::font_14(), 0);
  lv_obj_set_style_text_color(batt, theme::color(theme::DEV_TEXT_SUB), 0);
  lv_obj_align(batt, LV_ALIGN_RIGHT_MID, 0, 0);

  // ---------- 2. Phase chip (좌) + SET (우) ----------
  g_chip_phase = lv_obj_create(scr);
  lv_obj_set_size(g_chip_phase, LV_SIZE_CONTENT, 18);
  lv_obj_align(g_chip_phase, LV_ALIGN_TOP_LEFT, 8, 22);
  lv_obj_set_style_bg_color(g_chip_phase, theme::color(theme::DEV_SURFACE), 0);
  lv_obj_set_style_bg_opa(g_chip_phase, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(g_chip_phase, 0, 0);
  lv_obj_set_style_radius(g_chip_phase, LV_RADIUS_CIRCLE, 0);
  lv_obj_set_style_pad_hor(g_chip_phase, 8, 0);
  lv_obj_set_style_pad_ver(g_chip_phase, 0, 0);
  lv_obj_clear_flag(g_chip_phase, LV_OBJ_FLAG_SCROLLABLE);

  g_lbl_chip_text = lv_label_create(g_chip_phase);
  lv_label_set_text(g_lbl_chip_text, phase_label(g_phase));
  lv_obj_set_style_text_font(g_lbl_chip_text, theme::font_14(), 0);
  lv_obj_set_style_text_color(g_lbl_chip_text,
                              theme::color(phase_accent(g_phase)), 0);
  lv_obj_center(g_lbl_chip_text);

  g_lbl_set = lv_label_create(scr);
  lv_label_set_text(g_lbl_set, "SET 1/3");
  lv_obj_set_style_text_font(g_lbl_set, theme::font_14(), 0);
  lv_obj_set_style_text_color(g_lbl_set, theme::color(theme::DEV_TEXT_SUB), 0);
  lv_obj_align(g_lbl_set, LV_ALIGN_TOP_RIGHT, -8, 24);

  // ---------- 3. 세로 양방향 bar (좌) ----------
  g_bar_box = lv_obj_create(scr);
  lv_obj_set_size(g_bar_box, BAR_W, BAR_TOTAL_H);
  lv_obj_align(g_bar_box, LV_ALIGN_TOP_LEFT, BAR_LEFT_X, BAR_TOP_Y + 12);
  lv_obj_set_style_bg_color(g_bar_box, theme::color(theme::DEV_SURFACE), 0);
  lv_obj_set_style_bg_opa(g_bar_box, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(g_bar_box, 0, 0);
  lv_obj_set_style_radius(g_bar_box, 6, 0);
  lv_obj_set_style_pad_all(g_bar_box, 0, 0);
  lv_obj_clear_flag(g_bar_box, LV_OBJ_FLAG_SCROLLABLE);

  // 음압 zone marker (위쪽 — green 반투명).
  lv_obj_t* zone_neg = lv_obj_create(g_bar_box);
  const int zone_h = (int)((g_target_high - g_target_low) /
                            MAX_P_CMH2O * BAR_HALF_H);
  const int zone_offset_top = BAR_HALF_H -
        (int)(g_target_high / MAX_P_CMH2O * BAR_HALF_H);
  lv_obj_set_size(zone_neg, BAR_W - 4, zone_h);
  lv_obj_align(zone_neg, LV_ALIGN_TOP_MID, 0, zone_offset_top);
  lv_obj_set_style_bg_color(zone_neg, theme::color(theme::DEV_GREEN), 0);
  lv_obj_set_style_bg_opa(zone_neg, LV_OPA_20, 0);
  lv_obj_set_style_border_width(zone_neg, 0, 0);
  lv_obj_set_style_radius(zone_neg, 2, 0);
  lv_obj_clear_flag(zone_neg, LV_OBJ_FLAG_SCROLLABLE);

  // 양압 zone marker (아래쪽 — green 반투명).
  lv_obj_t* zone_pos = lv_obj_create(g_bar_box);
  lv_obj_set_size(zone_pos, BAR_W - 4, zone_h);
  const int zone_offset_bot = BAR_HALF_H +
        (int)(g_target_low / MAX_P_CMH2O * BAR_HALF_H);
  lv_obj_set_pos(zone_pos, 2, zone_offset_bot);
  lv_obj_set_style_bg_color(zone_pos, theme::color(theme::DEV_GREEN), 0);
  lv_obj_set_style_bg_opa(zone_pos, LV_OPA_20, 0);
  lv_obj_set_style_border_width(zone_pos, 0, 0);
  lv_obj_set_style_radius(zone_pos, 2, 0);
  lv_obj_clear_flag(zone_pos, LV_OBJ_FLAG_SCROLLABLE);

  // Zero line (중앙 흰 가로선).
  lv_obj_t* zero = lv_obj_create(g_bar_box);
  lv_obj_set_size(zero, BAR_W, 1);
  lv_obj_align(zero, LV_ALIGN_CENTER, 0, 0);
  lv_obj_set_style_bg_color(zero, theme::color(theme::DEV_TEXT_SUB), 0);
  lv_obj_set_style_bg_opa(zero, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(zero, 0, 0);
  lv_obj_set_style_radius(zero, 0, 0);
  lv_obj_clear_flag(zero, LV_OBJ_FLAG_SCROLLABLE);

  // Active bar (현재 압력 표시 — 위/아래 동적 채움).
  g_bar_active = lv_obj_create(g_bar_box);
  lv_obj_set_size(g_bar_active, BAR_W - 8, 0);   // 초기 0
  lv_obj_align(g_bar_active, LV_ALIGN_CENTER, 0, 0);
  lv_obj_set_style_bg_color(g_bar_active, theme::color(phase_accent(g_phase)), 0);
  lv_obj_set_style_bg_opa(g_bar_active, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(g_bar_active, 0, 0);
  lv_obj_set_style_radius(g_bar_active, 2, 0);
  lv_obj_clear_flag(g_bar_active, LV_OBJ_FLAG_SCROLLABLE);

  // ---------- 4. 압력 값 표시 (우) ----------
  g_lbl_value = lv_label_create(scr);
  lv_label_set_text(g_lbl_value, "0.0");
  lv_obj_set_style_text_font(g_lbl_value, theme::font_28(), 0);
  lv_obj_set_style_text_color(g_lbl_value, theme::color(phase_accent(g_phase)), 0);
  lv_obj_align(g_lbl_value, LV_ALIGN_TOP_LEFT, 70, 80);

  g_lbl_unit = lv_label_create(scr);
  lv_label_set_text(g_lbl_unit, "cmH2O");
  lv_obj_set_style_text_font(g_lbl_unit, theme::font_14(), 0);
  lv_obj_set_style_text_color(g_lbl_unit, theme::color(theme::DEV_TEXT_MUTE), 0);
  lv_obj_align(g_lbl_unit, LV_ALIGN_TOP_LEFT, 70, 118);

  // 목표 chip
  g_chip_target = lv_obj_create(scr);
  lv_obj_set_size(g_chip_target, LV_SIZE_CONTENT, 18);
  lv_obj_align(g_chip_target, LV_ALIGN_TOP_LEFT, 70, 144);
  lv_obj_set_style_bg_color(g_chip_target, theme::color(theme::DEV_SURFACE), 0);
  lv_obj_set_style_bg_opa(g_chip_target, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(g_chip_target, 0, 0);
  lv_obj_set_style_radius(g_chip_target, LV_RADIUS_CIRCLE, 0);
  lv_obj_set_style_pad_hor(g_chip_target, 8, 0);
  lv_obj_set_style_pad_ver(g_chip_target, 0, 0);
  lv_obj_clear_flag(g_chip_target, LV_OBJ_FLAG_SCROLLABLE);

  g_lbl_target = lv_label_create(g_chip_target);
  lv_label_set_text(g_lbl_target, "TARGET 20-30");
  lv_obj_set_style_text_font(g_lbl_target, theme::font_14(), 0);
  lv_obj_set_style_text_color(g_lbl_target, theme::color(theme::DEV_TEXT_MUTE), 0);
  lv_obj_center(g_lbl_target);

  // ---------- 5. 하단 카드 (남은 시간 + set dots + progress) ----------
  g_card_bottom = lv_obj_create(scr);
  lv_obj_set_size(g_card_bottom, display::SCREEN_W, 76);
  lv_obj_align(g_card_bottom, LV_ALIGN_BOTTOM_MID, 0, 0);
  lv_obj_set_style_bg_color(g_card_bottom, theme::color(theme::DEV_SURFACE), 0);
  lv_obj_set_style_bg_opa(g_card_bottom, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(g_card_bottom, 0, 0);
  lv_obj_set_style_radius(g_card_bottom, 0, 0);
  lv_obj_set_style_radius(g_card_bottom, 12, LV_PART_MAIN);  // 상단만 둥글게 (전체)
  lv_obj_set_style_pad_all(g_card_bottom, 12, 0);
  lv_obj_clear_flag(g_card_bottom, LV_OBJ_FLAG_SCROLLABLE);

  // "TIME LEFT" 라벨 (한글 "남은 시간" — "남/은" 폰트 미포함이라 영문화)
  lv_obj_t* lbl_rem_cap = lv_label_create(g_card_bottom);
  lv_label_set_text(lbl_rem_cap, "TIME LEFT");
  lv_obj_set_style_text_font(lbl_rem_cap, theme::font_14(), 0);
  lv_obj_set_style_text_color(lbl_rem_cap, theme::color(theme::DEV_TEXT_MUTE), 0);
  lv_obj_align(lbl_rem_cap, LV_ALIGN_TOP_LEFT, 0, 0);

  // 큰 시간 (0:30 형식)
  g_lbl_remaining = lv_label_create(g_card_bottom);
  lv_label_set_text(g_lbl_remaining, "0:00");
  lv_obj_set_style_text_font(g_lbl_remaining, theme::font_28(), 0);
  lv_obj_set_style_text_color(g_lbl_remaining, theme::color(theme::DEV_TEXT), 0);
  lv_obj_align(g_lbl_remaining, LV_ALIGN_TOP_LEFT, 0, 14);

  // Set dots (우상)
  for (int n = 0; n < 3; ++n) {
    g_set_dots[n] = lv_obj_create(g_card_bottom);
    lv_obj_set_size(g_set_dots[n], 8, 8);
    lv_obj_align(g_set_dots[n], LV_ALIGN_TOP_RIGHT, -(2 - n) * 14, 4);
    lv_obj_set_style_bg_color(g_set_dots[n], theme::color(theme::DEV_DIVIDER), 0);
    lv_obj_set_style_border_width(g_set_dots[n], 0, 0);
    lv_obj_set_style_radius(g_set_dots[n], LV_RADIUS_CIRCLE, 0);
    lv_obj_clear_flag(g_set_dots[n], LV_OBJ_FLAG_SCROLLABLE);
  }

  // 진행 bar (카드 하단)
  g_progress_bar = lv_bar_create(g_card_bottom);
  lv_obj_set_size(g_progress_bar, display::SCREEN_W - 24, 4);
  lv_obj_align(g_progress_bar, LV_ALIGN_BOTTOM_MID, 0, 0);
  lv_bar_set_range(g_progress_bar, 0, 100);
  lv_bar_set_value(g_progress_bar, 0, LV_ANIM_OFF);
  lv_obj_set_style_bg_color(g_progress_bar, theme::color(theme::DEV_DIVIDER), LV_PART_MAIN);
  lv_obj_set_style_bg_color(g_progress_bar, theme::color(phase_accent(g_phase)), LV_PART_INDICATOR);
  lv_obj_set_style_radius(g_progress_bar, 2, LV_PART_MAIN);
  lv_obj_set_style_radius(g_progress_bar, 2, LV_PART_INDICATOR);
}

void training_set_pressure(float cmH2O) {
  if (!g_bar_active || !g_lbl_value) return;
  g_pressure = cmH2O;

  // bar 위치/크기 계산.
  float v = cmH2O;
  if (v >  MAX_P_CMH2O) v =  MAX_P_CMH2O;
  if (v < -MAX_P_CMH2O) v = -MAX_P_CMH2O;
  const int bar_h = (int)(std::fabs(v) / MAX_P_CMH2O * BAR_HALF_H);

  // 음수 → bar 가 zero line 위쪽으로 자람 (yoff 음수).
  // 양수 → bar 가 zero line 아래쪽으로 자람 (yoff 양수).
  // LV_ALIGN_CENTER 기준 yoff 는 중심 기준.
  int yoff;
  if (v >= 0) {
    yoff = bar_h / 2;
  } else {
    yoff = -bar_h / 2;
  }
  lv_obj_set_size(g_bar_active, BAR_W - 8, bar_h);
  lv_obj_align(g_bar_active, LV_ALIGN_CENTER, 0, yoff);

  // 컬러 — zone 안 = green, 밖 = phase 색.
  const bool in_zone =
      (cmH2O >= g_target_low  && cmH2O <= g_target_high) ||
      (cmH2O <= -g_target_low && cmH2O >= -g_target_high);
  const uint32_t bar_color = in_zone ? theme::DEV_GREEN : phase_accent(g_phase);
  lv_obj_set_style_bg_color(g_bar_active, theme::color(bar_color), 0);

  // 값 라벨 (절댓값, 1자리).
  char buf[12];
  std::snprintf(buf, sizeof(buf), "%.1f", std::fabs(cmH2O));
  lv_label_set_text(g_lbl_value, buf);
  lv_obj_set_style_text_color(g_lbl_value, theme::color(bar_color), 0);

  // target chip 텍스트 + 색 갱신. ("목"/"달" 폰트 미포함 → 영문)
  if (g_lbl_target) {
    lv_label_set_text(g_lbl_target, in_zone ? "ON TARGET" : "TARGET 20+");
    lv_obj_set_style_text_color(g_lbl_target,
                                theme::color(in_zone ? theme::DEV_GREEN
                                                     : theme::DEV_TEXT_MUTE), 0);
  }
}

void training_set_phase(TrainingPhase phase, uint16_t remaining_sec) {
  g_phase = phase;
  update_phase_chip(phase);
  // 압력 라벨 / 진행 bar indicator 색도 phase 색으로.
  if (g_progress_bar) {
    lv_obj_set_style_bg_color(g_progress_bar,
                              theme::color(phase_accent(phase)),
                              LV_PART_INDICATOR);
  }
  training_set_remaining(remaining_sec);
}

void training_set_remaining(uint16_t remaining_sec) {
  g_remaining = remaining_sec;
  if (!g_lbl_remaining) return;
  const uint16_t mm = remaining_sec / 60;
  const uint16_t ss = remaining_sec % 60;
  char buf[12];
  std::snprintf(buf, sizeof(buf), "%u:%02u", (unsigned)mm, (unsigned)ss);
  lv_label_set_text(g_lbl_remaining, buf);
}

void training_set_progress(uint8_t percent, uint8_t current_set, uint8_t total_sets) {
  g_current_set = current_set;
  g_total_sets  = total_sets;

  if (g_progress_bar) {
    lv_bar_set_value(g_progress_bar, percent, LV_ANIM_ON);
  }
  if (g_lbl_set) {
    char buf[12];
    std::snprintf(buf, sizeof(buf), "SET %u/%u",
                  (unsigned)current_set, (unsigned)total_sets);
    lv_label_set_text(g_lbl_set, buf);
  }
  // Set dots — n<current=green(완료), n==current=phase accent, n>current=divider.
  const uint32_t accent = phase_accent(g_phase);
  for (int n = 0; n < 3; ++n) {
    if (!g_set_dots[n]) continue;
    const int idx = n + 1;
    uint32_t c;
    if (idx < current_set)       c = theme::DEV_GREEN;
    else if (idx == current_set) c = accent;
    else                         c = theme::DEV_DIVIDER;
    lv_obj_set_style_bg_color(g_set_dots[n], theme::color(c), 0);
  }
}

void training_set_target(float low, float high) {
  g_target_low  = low;
  g_target_high = high;
  if (g_lbl_target) {
    char buf[24];
    std::snprintf(buf, sizeof(buf), "TARGET %d-%d",
                  (int)low, (int)high);
    lv_label_set_text(g_lbl_target, buf);
  }
  // zone marker 들은 _show() 에서 다시 그려지므로 여기선 라벨만 갱신.
}

}  // namespace screens
