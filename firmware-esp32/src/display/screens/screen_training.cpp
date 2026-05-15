// 훈련 화면 (Training) — implementation.

#include "display/screens/screen_training.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>
#include <cstdio>
#include <cmath>

namespace screens {

namespace {

  // 화면 위젯 핸들.
  lv_obj_t* g_header        = nullptr;
  lv_obj_t* g_lbl_phase     = nullptr;
  lv_obj_t* g_lbl_remaining = nullptr;
  lv_obj_t* g_arc           = nullptr;     // Arc 게이지 — 압력 표시
  lv_obj_t* g_lbl_value     = nullptr;     // 게이지 중앙 큰 숫자
  lv_obj_t* g_lbl_unit      = nullptr;     // cmH2O
  lv_obj_t* g_lbl_hint      = nullptr;     // "강하게 내쉬세요" 안내문
  lv_obj_t* g_progress_bar  = nullptr;
  lv_obj_t* g_lbl_set       = nullptr;

  // 상태.
  TrainingPhase g_phase = TrainingPhase::Exhale;
  float g_target_low    = 20.0f;
  float g_target_high   = 30.0f;

  // Arc 범위 = -30 ~ +30 cmH2O. LVGL arc 는 int16 라 ×10 으로 변환.
  // -300 ~ +300 range. value = pressure * 10.
  constexpr int16_t ARC_MIN = -300;
  constexpr int16_t ARC_MAX = +300;

  /// Phase 별 색상 결정.
  uint32_t phase_color(TrainingPhase p) {
    switch (p) {
      case TrainingPhase::Exhale: return theme::BLUE_500;
      case TrainingPhase::Inhale: return theme::PURPLE_500;
      case TrainingPhase::Rest:   return theme::GRAY_500;
    }
    return theme::GRAY_500;
  }

  const char* phase_label(TrainingPhase p) {
    switch (p) {
      case TrainingPhase::Exhale: return "호기 차례";
      case TrainingPhase::Inhale: return "흡기 차례";
      case TrainingPhase::Rest:   return "휴식";
    }
    return "";
  }

  const char* phase_hint(TrainingPhase p) {
    switch (p) {
      case TrainingPhase::Exhale: return "강하게 내쉬세요";
      case TrainingPhase::Inhale: return "천천히 들이마시세요";
      case TrainingPhase::Rest:   return "잠시 쉬어요";
    }
    return "";
  }

}  // anonymous namespace

void training_show() {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  lv_obj_set_style_bg_color(scr, theme::color(theme::GRAY_900), 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // ---------- 상단 Phase header (170 × 56) ----------
  g_header = lv_obj_create(scr);
  lv_obj_set_size(g_header, display::SCREEN_W, 56);
  lv_obj_align(g_header, LV_ALIGN_TOP_MID, 0, 0);
  lv_obj_set_style_bg_color(g_header, theme::color(phase_color(g_phase)), 0);
  lv_obj_set_style_border_width(g_header, 0, 0);
  lv_obj_set_style_radius(g_header, 0, 0);
  lv_obj_set_style_pad_all(g_header, 8, 0);
  lv_obj_clear_flag(g_header, LV_OBJ_FLAG_SCROLLABLE);

  g_lbl_phase = lv_label_create(g_header);
  lv_label_set_text(g_lbl_phase, phase_label(g_phase));
  lv_obj_set_style_text_font(g_lbl_phase, theme::font_20(), 0);
  lv_obj_set_style_text_color(g_lbl_phase, theme::color(0xFFFFFF), 0);
  lv_obj_align(g_lbl_phase, LV_ALIGN_LEFT_MID, 4, 0);

  g_lbl_remaining = lv_label_create(g_header);
  lv_label_set_text(g_lbl_remaining, "--초");
  lv_obj_set_style_text_font(g_lbl_remaining, theme::font_28(), 0);
  lv_obj_set_style_text_color(g_lbl_remaining, theme::color(0xFFFFFF), 0);
  lv_obj_align(g_lbl_remaining, LV_ALIGN_RIGHT_MID, -4, 0);

  // ---------- Arc 게이지 (140 × 140, 중앙 가깝게) ----------
  g_arc = lv_arc_create(scr);
  lv_obj_set_size(g_arc, 150, 150);
  lv_obj_align(g_arc, LV_ALIGN_TOP_MID, 0, 64);
  lv_arc_set_range(g_arc, ARC_MIN, ARC_MAX);
  lv_arc_set_value(g_arc, 0);
  // 270도 호 (위쪽 -45도 ~ +45도 빈 공간 — 안내 라벨 자리)
  lv_arc_set_bg_angles(g_arc, 135, 45);    // 시계방향 위쪽 비움
  lv_arc_set_angles(g_arc, 135, 270);      // initial indicator (0 위치)
  lv_arc_set_rotation(g_arc, 0);
  // 스타일 - 배경 트랙
  lv_obj_set_style_arc_color(g_arc, theme::color(theme::GRAY_700), LV_PART_MAIN);
  lv_obj_set_style_arc_width(g_arc, 8, LV_PART_MAIN);
  // 스타일 - indicator (현재 값)
  lv_obj_set_style_arc_color(g_arc, theme::color(theme::BLUE_400), LV_PART_INDICATOR);
  lv_obj_set_style_arc_width(g_arc, 10, LV_PART_INDICATOR);
  // 손잡이 (knob) 숨김
  lv_obj_remove_style(g_arc, NULL, LV_PART_KNOB);
  lv_obj_clear_flag(g_arc, LV_OBJ_FLAG_CLICKABLE);

  // 게이지 중앙 큰 압력 숫자
  g_lbl_value = lv_label_create(scr);
  lv_label_set_text(g_lbl_value, "+0.0");
  lv_obj_set_style_text_font(g_lbl_value, theme::font_28(), 0);
  lv_obj_set_style_text_color(g_lbl_value, theme::color(0xFFFFFF), 0);
  lv_obj_align_to(g_lbl_value, g_arc, LV_ALIGN_CENTER, 0, -6);

  g_lbl_unit = lv_label_create(scr);
  lv_label_set_text(g_lbl_unit, "cmH2O");
  lv_obj_set_style_text_font(g_lbl_unit, theme::font_14(), 0);
  lv_obj_set_style_text_color(g_lbl_unit, theme::color(theme::GRAY_400), 0);
  lv_obj_align_to(g_lbl_unit, g_arc, LV_ALIGN_CENTER, 0, 24);

  // ---------- 하단 안내문 ----------
  g_lbl_hint = lv_label_create(scr);
  lv_label_set_text(g_lbl_hint, phase_hint(g_phase));
  lv_obj_set_style_text_font(g_lbl_hint, theme::font_20(), 0);
  lv_obj_set_style_text_color(g_lbl_hint, theme::color(0xFFFFFF), 0);
  lv_obj_align(g_lbl_hint, LV_ALIGN_BOTTOM_MID, 0, -52);

  // ---------- 진행 bar + 세트 ----------
  g_progress_bar = lv_bar_create(scr);
  lv_obj_set_size(g_progress_bar, display::SCREEN_W - 24, 6);
  lv_obj_align(g_progress_bar, LV_ALIGN_BOTTOM_MID, 0, -26);
  lv_bar_set_range(g_progress_bar, 0, 100);
  lv_bar_set_value(g_progress_bar, 0, LV_ANIM_OFF);
  lv_obj_set_style_bg_color(g_progress_bar, theme::color(theme::GRAY_700), LV_PART_MAIN);
  lv_obj_set_style_bg_color(g_progress_bar, theme::color(theme::BLUE_500), LV_PART_INDICATOR);
  lv_obj_set_style_radius(g_progress_bar, 3, LV_PART_MAIN);
  lv_obj_set_style_radius(g_progress_bar, 3, LV_PART_INDICATOR);

  g_lbl_set = lv_label_create(scr);
  lv_label_set_text(g_lbl_set, "세트 1/3");
  lv_obj_set_style_text_font(g_lbl_set, theme::font_14(), 0);
  lv_obj_set_style_text_color(g_lbl_set, theme::color(theme::GRAY_400), 0);
  lv_obj_align(g_lbl_set, LV_ALIGN_BOTTOM_MID, 0, -8);
}

void training_set_pressure(float cmH2O) {
  if (!g_arc || !g_lbl_value) return;

  // arc 값 — clamp & scale.
  int v = (int)std::lround(cmH2O * 10.0f);
  if (v > ARC_MAX) v = ARC_MAX;
  if (v < ARC_MIN) v = ARC_MIN;
  lv_arc_set_value(g_arc, v);

  // 중앙 숫자.
  char buf[16];
  std::snprintf(buf, sizeof(buf), "%+.1f", cmH2O);
  lv_label_set_text(g_lbl_value, buf);

  // 목표 zone 안인지 판정 (양압/음압 모두).
  const bool in_zone =
      (cmH2O >= g_target_low  && cmH2O <= g_target_high) ||
      (cmH2O <= -g_target_low && cmH2O >= -g_target_high);

  // indicator 컬러 — zone 안이면 초록, 밖이면 phase 컬러.
  const uint32_t color = in_zone ? theme::GREEN_500 : phase_color(g_phase);
  lv_obj_set_style_arc_color(g_arc, theme::color(color), LV_PART_INDICATOR);
  lv_obj_set_style_text_color(g_lbl_value, theme::color(color), 0);
}

void training_set_phase(TrainingPhase phase, uint16_t remaining_sec) {
  g_phase = phase;
  if (g_header) {
    lv_obj_set_style_bg_color(g_header, theme::color(phase_color(phase)), 0);
  }
  if (g_lbl_phase) {
    lv_label_set_text(g_lbl_phase, phase_label(phase));
  }
  if (g_lbl_hint) {
    lv_label_set_text(g_lbl_hint, phase_hint(phase));
  }
  training_set_remaining(remaining_sec);
}

void training_set_remaining(uint16_t remaining_sec) {
  if (!g_lbl_remaining) return;
  char buf[12];
  std::snprintf(buf, sizeof(buf), "%u초", (unsigned)remaining_sec);
  lv_label_set_text(g_lbl_remaining, buf);
}

void training_set_progress(uint8_t percent, uint8_t current_set, uint8_t total_sets) {
  if (g_progress_bar) {
    lv_bar_set_value(g_progress_bar, percent, LV_ANIM_ON);
  }
  if (g_lbl_set) {
    char buf[16];
    std::snprintf(buf, sizeof(buf), "세트 %u/%u",
                  (unsigned)current_set, (unsigned)total_sets);
    lv_label_set_text(g_lbl_set, buf);
  }
}

void training_set_target(float low, float high) {
  g_target_low  = low;
  g_target_high = high;
  // M6+ 에서 arc 의 zone 강조 area 추가 예정 (lv_arc 의 secondary indicator).
}

}  // namespace screens
