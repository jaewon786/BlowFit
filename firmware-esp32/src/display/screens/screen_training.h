// 훈련 화면 (Training) — 호흡 훈련 진행 중 메인 화면.
//
// 구성:
//   상단 Phase header — 호기/흡기 라벨 + 남은 카운트다운 + 컬러 강조
//   중앙 Arc 게이지 — 현재 압력 (-30~+30 cmH2O) + 목표 zone 강조
//   게이지 내부 — 큰 압력 숫자 (+25.0) + "cmH2O"
//   하단 안내문 — "강하게 내쉬세요" / "천천히 들이마시세요" / "잠시 쉬어요"
//   최하단 진행 bar — 세션 진행률 + "세트 N/M"

#pragma once

#include <stdint.h>

namespace screens {

  /// Phase 종류 (M7 의 state_machine 과 별도 — UI 표시용).
  enum class TrainingPhase : uint8_t {
    Exhale = 0,   // 호기 (파랑)
    Inhale = 1,   // 흡기 (보라)
    Rest   = 2,   // 휴식 (회색)
  };

  /// 훈련 화면 렌더링 — 호출 후 lv_screen_active() 가 training 화면이 됨.
  void training_show();

  /// 현재 압력 갱신 (cmH2O). 호출자가 100Hz 로 호출해도 LVGL 의 partial
  /// render 가 효율적으로 처리. 양수 = 호기, 음수 = 흡기.
  void training_set_pressure(float cmH2O);

  /// Phase 변경 — header 컬러 / 라벨 / 안내문 동시 갱신.
  void training_set_phase(TrainingPhase phase, uint16_t remaining_sec);

  /// 카운트다운만 갱신 (1초 단위).
  void training_set_remaining(uint16_t remaining_sec);

  /// 세션 진행률 갱신 (0~100%). 세트 표시도 같이 갱신.
  void training_set_progress(uint8_t percent, uint8_t current_set, uint8_t total_sets);

  /// 목표 압력 zone 갱신 (cmH2O). 양수 zone — 흡기 시 [-high, -low] 자동 거울.
  void training_set_target(float low, float high);

}  // namespace screens
