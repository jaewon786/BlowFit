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

  /// 충전 중(외부 USB 전원) 여부 추정. VBAT 가 무부하 만충(4.2V)을 넘으면
  /// 외부 전원으로 판단 — 구동 중 배터리 단독은 부하 sag 로 ~4.0V 이하라 구분됨.
  /// hysteresis 로 경계 flicker 방지. ⚠️ 저전압 배터리 충전 초기(4.15V 미만)엔
  /// 감지 못 할 수 있음(전압 기반 한계). update() 마다 갱신.
  bool isCharging();

}  // namespace battery
