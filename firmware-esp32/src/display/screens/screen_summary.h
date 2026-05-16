// 결과 화면 (Summary) — 세션 완료 후 통계 표시.
//
// 구성:
//   상단 "훈련 완료!" + 체크 아이콘 컬러
//   통계 4행: 평균 / 최대 / 지속 / 성공률
//   하단 안내문 ("잘하셨어요" 또는 5초 자동 복귀 안내)

#pragma once

#include <stdint.h>

namespace screens {

  struct SummaryData {
    float    avg_pressure;
    float    max_pressure;
    uint16_t duration_sec;
    uint8_t  hit_percent;
    uint8_t  completed_sets;
    uint8_t  total_sets;
  };

  /// 화면 렌더링 + 통계 표시.
  void summary_show(const SummaryData& data);

}  // namespace screens
