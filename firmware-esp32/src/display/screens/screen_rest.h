// 휴식 화면 (Rest) — 세트 사이 휴식.
//
// 구성:
//   "휴식" 라벨 (큰 글씨)
//   큰 카운트다운 숫자 (남은 초)
//   "잠시 쉬어요" 안내문
//   "다음 세트 N/M" 정보

#pragma once

#include <stdint.h>

namespace screens {

  /// 화면 렌더링.
  void rest_show();

  /// 카운트다운 갱신 (1초 단위).
  void rest_set_remaining(uint16_t remaining_sec);

  /// 다음 세트 정보.
  void rest_set_next_set(uint8_t next_set, uint8_t total_sets);

}  // namespace screens
