// 배터리 잔량 측정 — T-Display-S3 내장 VBAT 분압 (GPIO4, 2:1).
//
// 추가 하드웨어 불필요. 보드가 VBAT 을 2:1 로 분압해 GPIO4(ADC1_CH3) 로 노출.
//   Vbat_mV = analogReadMilliVolts(GPIO4) × 2
// LiPo 단일 셀 방전 곡선으로 전압 → 잔량(%) 근사.
//
// ⚠️ USB 연결(충전) 중에는 VBAT 가 충전 전압(~4.2V+)으로 올라가 잔량이 높게
//    표시됨 — 정상. 정확한 잔량은 USB 분리 상태에서 측정됨.

#pragma once

#include <stdint.h>

namespace battery {

  /// ADC 설정 + 최초 1회 측정. setup() 에서 호출.
  void begin();

  /// 새로 측정해 캐시 갱신 (loop 에서 주기적으로 호출).
  void update();

  /// 마지막 측정 VBAT (mV).
  uint16_t milliVolts();

  /// 마지막 측정 잔량 (0~100). begin 전이면 -1.
  int8_t percent();

}  // namespace battery
