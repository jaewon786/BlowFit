// 훈련 화면 (Training) — implementation.
//
// 설계: BlowFit.html ScrTraining — 다크 테마, 상단 status bar + phase chip
// + SET, 중앙 세로 양방향 bar (음압 위쪽 / 양압 아래쪽) + 큰 압력 숫자 +
// "목표 달성/±20+" chip, 하단 카드 (남은 시간 + set dots + 진행 bar).

#include "display/screens/screen_training.h"
#include "display/screens/status_bar.h"
#include "display/theme.h"
#include "config.h"
#include "battery.h"

#include <lvgl.h>
#include <cstdio>
#include <cmath>

namespace screens {

namespace {

  // 화면 위젯 핸들.
  lv_obj_t* g_scr            = nullptr;     // 화면 root (in-zone 배경 전환용)
  lv_obj_t* g_chip_phase     = nullptr;     // phase 행 컨테이너 (화살표+텍스트)
  lv_obj_t* g_arrow          = nullptr;     // 방향 화살표 (호기↑/흡기↓)
  lv_obj_t* g_lbl_chip_text  = nullptr;
  lv_obj_t* g_lbl_set        = nullptr;     // (미사용 — 단일 세트) setter null-safe

  // 세로 bar.
  lv_obj_t* g_bar_box        = nullptr;
  lv_obj_t* g_bar_active     = nullptr;     // 동적으로 위치/크기 조정
  lv_obj_t* g_lbl_value      = nullptr;
  lv_obj_t* g_lbl_unit       = nullptr;
  lv_obj_t* g_lbl_target     = nullptr;     // (미사용 — target chip 제거) setter null-safe

  // 하단.
  lv_obj_t* g_lbl_remaining  = nullptr;
  lv_obj_t* g_lbl_rem_cap    = nullptr;   // "남은 시간" 캡션 (rest 시 흰색 전환)
  lv_obj_t* g_scale[3]       = {nullptr, nullptr, nullptr};  // 눈금 30/0/30 (rest 시 흰색)
  lv_obj_t* g_set_dots[3]    = {nullptr, nullptr, nullptr};  // (미사용) setter null-safe
  lv_obj_t* g_progress_bar   = nullptr;                       // (미사용) setter null-safe

  // 상태.
  TrainingPhase g_phase  = TrainingPhase::Exhale;
  float g_target_low     = 20.0f;
  float g_target_high    = 30.0f;
  uint8_t g_current_set  = 1;
  uint8_t g_total_sets   = 3;
  uint16_t g_remaining   = 0;
  float g_pressure       = 0.0f;
  uint32_t g_prev_bg     = 0xFFFFFFFF;   // 마지막 적용 배경색 (변할 때만 갱신; 무효값 초기화)
  int g_prev_rest        = -1;           // rest 전환 추적 (보조 텍스트 색 갱신용)

  // 배경 색 — 기본 = 흰색, 호기 목표 = 파랑, 흡기 목표 = 초록, 휴식 = 검정.
  constexpr uint32_t BG_WHITE     = 0xFFFFFF;
  constexpr uint32_t BG_EXHALE_IN = 0x0066FF;
  constexpr uint32_t BG_INHALE_IN = 0x00A838;
  constexpr uint32_t BG_BLACK     = 0x000000;

  // bar 기하 (설계 ScrTraining 의 비례를 170px 폭에 맞춰 조정).
  constexpr int BAR_TOTAL_H  = 168;             // 세로 bar 전체 높이
  constexpr int BAR_CENTER   = BAR_TOTAL_H / 2; // zero line (=84)
  // half < CENTER 라 위/아래에 (84-76=8px) 흰색 여백 → 둥근 모서리(radius 6)에
  // 안 잘리고 호기/흡기 상·하단에 흰 배경이 남음.
  constexpr int BAR_HALF_H   = 76;    // 위/아래 half (full scale ±30 매핑)
  constexpr int BAR_TOP_Y    = 32;    // status bar (20) + chip row (12) 아래
  constexpr int BAR_W        = 26;    // 세로 bar 폭
  constexpr int BAR_LEFT_X   = 14;    // 좌측 margin
  constexpr float MAX_P_CMH2O = 30.0f;   // bar full scale (±30)

  uint32_t phase_accent(TrainingPhase p) {
    switch (p) {
      case TrainingPhase::Exhale: return theme::DEV_PRIMARY;
      case TrainingPhase::Inhale: return theme::DEV_GREEN;
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

  /// 화면 배경색 갱신 — 값이 바뀔 때만 적용 (20Hz 매번 set 방지).
  void apply_bg(uint32_t color) {
    if (!g_scr || color == g_prev_bg) return;
    g_prev_bg = color;
    lv_obj_set_style_bg_color(g_scr, theme::color(color), 0);
  }

  /// phase 행 갱신 — 화살표 방향/색 + 텍스트/색.
  void update_phase_chip(TrainingPhase p) {
    if (!g_lbl_chip_text) return;
    const uint32_t c = phase_accent(p);
    lv_label_set_text(g_lbl_chip_text, phase_label(p));
    lv_obj_set_style_text_color(g_lbl_chip_text, theme::color(c), 0);
    if (g_arrow) {
      // 화살표 방향 반대 표시: 내쉬기=아래(↓), 들이마시기=위(↑).
      const char* sym = (p == TrainingPhase::Exhale) ? LV_SYMBOL_DOWN
                      : (p == TrainingPhase::Inhale) ? LV_SYMBOL_UP : "";
      lv_label_set_text(g_arrow, sym);
      lv_obj_set_style_text_color(g_arrow, theme::color(c), 0);
    }
  }

}  // anonymous namespace

void training_show() {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);
  g_scr = scr;
  g_prev_bg = 0xFFFFFFFF;   // 새 화면 → 배경 상태 재설정.
  g_prev_rest = -1;
  g_phase = TrainingPhase::Exhale;   // 첫 프레임이 휴식(검정)으로 평가되지 않게.
  // 기본 배경 = 흰색 (단색). 목표 도달 시 set_pressure 에서 파랑/초록 전환.
  lv_obj_set_style_bg_color(scr, theme::color(BG_WHITE), 0);
  lv_obj_set_style_bg_grad_dir(scr, LV_GRAD_DIR_NONE, 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // ---------- 1. 상단 status bar (BT 아이콘 + 배터리) ----------
  make_status_bar(scr, /*connected=*/true, /*battery=*/battery::percent());

  // ---------- 2. Phase 행 — 화살표 + 텍스트 (중앙) ----------
  const uint32_t accent = phase_accent(g_phase);
  g_chip_phase = lv_obj_create(scr);
  lv_obj_set_size(g_chip_phase, display::SCREEN_W, 24);
  lv_obj_align(g_chip_phase, LV_ALIGN_TOP_MID, 0, 24);
  lv_obj_set_style_bg_opa(g_chip_phase, LV_OPA_TRANSP, 0);
  lv_obj_set_style_border_width(g_chip_phase, 0, 0);
  lv_obj_set_style_pad_all(g_chip_phase, 0, 0);
  lv_obj_set_flex_flow(g_chip_phase, LV_FLEX_FLOW_ROW);
  lv_obj_set_flex_align(g_chip_phase, LV_FLEX_ALIGN_CENTER,
                        LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);
  lv_obj_set_style_pad_column(g_chip_phase, 5, 0);
  lv_obj_clear_flag(g_chip_phase, LV_OBJ_FLAG_SCROLLABLE);

  g_arrow = lv_label_create(g_chip_phase);
  // 화살표 방향 반대 표시: 내쉬기=아래(↓), 들이마시기=위(↑).
  lv_label_set_text(g_arrow,
      g_phase == TrainingPhase::Exhale ? LV_SYMBOL_DOWN
    : g_phase == TrainingPhase::Inhale ? LV_SYMBOL_UP : "");
  // LV_SYMBOL_* 는 PUA 글리프 → Pretendard subset 에 없음. Montserrat 사용.
  lv_obj_set_style_text_font(g_arrow, &lv_font_montserrat_20, 0);
  lv_obj_set_style_text_color(g_arrow, theme::color(accent), 0);

  g_lbl_chip_text = lv_label_create(g_chip_phase);
  lv_label_set_text(g_lbl_chip_text, phase_label(g_phase));
  lv_obj_set_style_text_font(g_lbl_chip_text, theme::font_20(), 0);
  lv_obj_set_style_text_color(g_lbl_chip_text, theme::color(accent), 0);

  // ---------- 3. 세로 양방향 bar (좌) + 눈금 ----------
  g_bar_box = lv_obj_create(scr);
  lv_obj_set_size(g_bar_box, BAR_W, BAR_TOTAL_H);
  lv_obj_align(g_bar_box, LV_ALIGN_TOP_LEFT, BAR_LEFT_X, BAR_TOP_Y + 36);
  lv_obj_set_style_bg_color(g_bar_box, theme::color(theme::DEV_SURFACE), 0);
  lv_obj_set_style_bg_opa(g_bar_box, LV_OPA_COVER, 0);
  lv_obj_set_style_border_color(g_bar_box, theme::color(theme::DEV_DIVIDER), 0);
  lv_obj_set_style_border_width(g_bar_box, 1, 0);
  lv_obj_set_style_radius(g_bar_box, 6, 0);
  lv_obj_set_style_pad_all(g_bar_box, 0, 0);
  lv_obj_clear_flag(g_bar_box, LV_OBJ_FLAG_SCROLLABLE);

  // zone marker 높이 (target 폭) 와 center 기준 픽셀 오프셋.
  const int zone_h = (int)((g_target_high - g_target_low) /
                            MAX_P_CMH2O * BAR_HALF_H);
  const int px_low  = (int)(g_target_low  / MAX_P_CMH2O * BAR_HALF_H);
  const int px_high = (int)(g_target_high / MAX_P_CMH2O * BAR_HALF_H);

  // 음압 zone marker (위쪽/호기 — green 반투명). center 위로 [low..high].
  lv_obj_t* zone_neg = lv_obj_create(g_bar_box);
  lv_obj_set_size(zone_neg, BAR_W - 4, zone_h);
  lv_obj_set_pos(zone_neg, 2, BAR_CENTER - px_high);
  lv_obj_set_style_bg_color(zone_neg, theme::color(theme::DEV_GREEN), 0);
  lv_obj_set_style_bg_opa(zone_neg, LV_OPA_20, 0);
  lv_obj_set_style_border_width(zone_neg, 0, 0);
  lv_obj_set_style_radius(zone_neg, 2, 0);
  lv_obj_clear_flag(zone_neg, LV_OBJ_FLAG_SCROLLABLE);

  // 양압 zone marker (아래쪽/흡기 — green 반투명). center 아래로 [low..high].
  lv_obj_t* zone_pos = lv_obj_create(g_bar_box);
  lv_obj_set_size(zone_pos, BAR_W - 4, zone_h);
  lv_obj_set_pos(zone_pos, 2, BAR_CENTER + px_low);
  lv_obj_set_style_bg_color(zone_pos, theme::color(theme::DEV_GREEN), 0);
  lv_obj_set_style_bg_opa(zone_pos, LV_OPA_20, 0);
  lv_obj_set_style_border_width(zone_pos, 0, 0);
  lv_obj_set_style_radius(zone_pos, 2, 0);
  lv_obj_clear_flag(zone_pos, LV_OBJ_FLAG_SCROLLABLE);

  // Zero line (중앙 가로선).
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
  lv_obj_set_style_bg_color(g_bar_active, theme::color(accent), 0);
  lv_obj_set_style_bg_opa(g_bar_active, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(g_bar_active, 0, 0);
  lv_obj_set_style_radius(g_bar_active, 2, 0);
  lv_obj_clear_flag(g_bar_active, LV_OBJ_FLAG_SCROLLABLE);

  // 눈금 라벨 30 / 0 / 30 (bar 우측). bar box: x=14, w=26 → 우측 x≈44.
  // center 기준 마크 위치에 맞춰 정렬 (font_14 높이 ≈16 → -8 로 수직 중앙).
  const int bar_top_y = BAR_TOP_Y + 36;
  const struct { const char* t; int y; } scale[] = {
    {"30", bar_top_y + (BAR_CENTER - BAR_HALF_H) - 8},
    {"0",  bar_top_y + BAR_CENTER - 8},
    {"30", bar_top_y + (BAR_CENTER + BAR_HALF_H) - 8},
  };
  for (int i = 0; i < 3; ++i) {
    lv_obj_t* lbl = lv_label_create(scr);
    lv_label_set_text(lbl, scale[i].t);
    lv_obj_set_style_text_font(lbl, theme::font_14(), 0);
    lv_obj_set_style_text_color(lbl, theme::color(theme::DEV_TEXT_MUTE), 0);
    lv_obj_align(lbl, LV_ALIGN_TOP_LEFT, BAR_LEFT_X + BAR_W + 4, scale[i].y);
    g_scale[i] = lbl;
  }

  // ---------- 4. 압력 값 표시 (우, bar 중앙 높이) ----------
  g_lbl_value = lv_label_create(scr);
  lv_label_set_text(g_lbl_value, "0.0");
  lv_obj_set_style_text_font(g_lbl_value, theme::font_28(), 0);
  lv_obj_set_style_text_color(g_lbl_value, theme::color(accent), 0);
  lv_obj_align(g_lbl_value, LV_ALIGN_TOP_LEFT, 78, bar_top_y + 56);

  g_lbl_unit = lv_label_create(scr);
  lv_label_set_text(g_lbl_unit, "cmH2O");
  lv_obj_set_style_text_font(g_lbl_unit, theme::font_14(), 0);
  lv_obj_set_style_text_color(g_lbl_unit, theme::color(theme::DEV_TEXT_MUTE), 0);
  lv_obj_align(g_lbl_unit, LV_ALIGN_TOP_LEFT, 80, bar_top_y + 92);

  // ---------- 5. 하단 — 남은 시간 + 카운트다운 ----------
  // Phase 4 폰트 재생성으로 남/은 글자 추가됨 → 한글 표기.
  g_lbl_rem_cap = lv_label_create(scr);
  lv_label_set_text(g_lbl_rem_cap, "남은 시간");
  lv_obj_set_style_text_font(g_lbl_rem_cap, theme::font_14(), 0);
  lv_obj_set_style_text_color(g_lbl_rem_cap, theme::color(theme::DEV_TEXT_MUTE), 0);
  lv_obj_align(g_lbl_rem_cap, LV_ALIGN_BOTTOM_MID, 0, -48);

  g_lbl_remaining = lv_label_create(scr);
  lv_label_set_text(g_lbl_remaining, "0:00");
  lv_obj_set_style_text_font(g_lbl_remaining, theme::font_28(), 0);
  lv_obj_set_style_text_color(g_lbl_remaining, theme::color(theme::DEV_TEXT), 0);
  lv_obj_align(g_lbl_remaining, LV_ALIGN_BOTTOM_MID, 0, -12);
}

void training_set_pressure(float cmH2O) {
  if (!g_bar_active || !g_lbl_value) return;
  g_pressure = cmH2O;

  // 표시 방향은 **현재 phase** 가 결정 — 압력 부호 무시.
  //   Exhale → bar 위쪽 / Inhale → bar 아래쪽 / Rest → bar 숨김.
  float v = std::fabs(cmH2O);
  if (v > MAX_P_CMH2O) v = MAX_P_CMH2O;
  const int bar_h = (int)(v / MAX_P_CMH2O * BAR_HALF_H);

  // 값 라벨 텍스트 (절댓값, 1자리) — 색은 아래에서 상태별로.
  char buf[12];
  std::snprintf(buf, sizeof(buf), "%.1f", std::fabs(cmH2O));
  lv_label_set_text(g_lbl_value, buf);

  // 보조 텍스트(눈금/캡션/시간) 색은 rest 진입·이탈 시에만 갱신.
  //   rest → 흰색 (검은 배경), 그 외 → 평소 회색/네이비.
  const bool is_rest = (g_phase == TrainingPhase::Rest);
  const int rest_now = is_rest ? 1 : 0;
  if (rest_now != g_prev_rest) {
    g_prev_rest = rest_now;
    const uint32_t cap_c  = is_rest ? 0xFFFFFF : theme::DEV_TEXT_MUTE;
    const uint32_t time_c = is_rest ? 0xFFFFFF : theme::DEV_TEXT;
    if (g_lbl_rem_cap)
      lv_obj_set_style_text_color(g_lbl_rem_cap, theme::color(cap_c), 0);
    if (g_lbl_remaining)
      lv_obj_set_style_text_color(g_lbl_remaining, theme::color(time_c), 0);
    for (int i = 0; i < 3; ++i)
      if (g_scale[i]) lv_obj_set_style_text_color(g_scale[i], theme::color(cap_c), 0);
  }

  // ---- 휴식: bar 숨김, 배경 검정, 모든 글씨 흰색 ----
  if (is_rest) {
    lv_obj_set_size(g_bar_active, BAR_W - 8, 0);
    apply_bg(BG_BLACK);
    const lv_color_t w = theme::color(0xFFFFFF);
    lv_obj_set_style_text_color(g_lbl_value, w, 0);
    if (g_lbl_unit)      lv_obj_set_style_text_color(g_lbl_unit, w, 0);
    if (g_arrow)         lv_obj_set_style_text_color(g_arrow, w, 0);
    if (g_lbl_chip_text) lv_obj_set_style_text_color(g_lbl_chip_text, w, 0);
    return;
  }

  // ---- 호기/흡기: bar 채움 (active bar 는 항상 phase 색) ----
  const int yoff = (g_phase == TrainingPhase::Exhale) ? -bar_h / 2 : bar_h / 2;
  lv_obj_set_size(g_bar_active, BAR_W - 8, bar_h);
  lv_obj_align(g_bar_active, LV_ALIGN_CENTER, 0, yoff);
  lv_obj_set_style_bg_color(g_bar_active, theme::color(phase_accent(g_phase)), 0);

  // zone 판정.
  const bool in_zone =
      (cmH2O >= g_target_low  && cmH2O <= g_target_high) ||
      (cmH2O <= -g_target_low && cmH2O >= -g_target_high);

  // 배경 — 목표 도달 시 호기=파랑 / 흡기=초록, 그 외 흰색.
  uint32_t bg = BG_WHITE;
  if (in_zone)
    bg = (g_phase == TrainingPhase::Exhale) ? BG_EXHALE_IN : BG_INHALE_IN;
  apply_bg(bg);

  // 전경(값/단위/화살표/phase 텍스트) — 컬러 배경에선 흰색, 흰 배경에선 phase 색.
  const uint32_t fg = in_zone ? 0xFFFFFF : phase_accent(g_phase);
  lv_obj_set_style_text_color(g_lbl_value, theme::color(fg), 0);
  if (g_lbl_unit)
    lv_obj_set_style_text_color(g_lbl_unit,
        theme::color(in_zone ? 0xFFFFFF : theme::DEV_TEXT_MUTE), 0);
  if (g_arrow)
    lv_obj_set_style_text_color(g_arrow, theme::color(fg), 0);
  if (g_lbl_chip_text)
    lv_obj_set_style_text_color(g_lbl_chip_text, theme::color(fg), 0);
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
