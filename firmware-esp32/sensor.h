// 양방향 압력 센서 모듈 (XGZP6847A010KPGPN33, ±102 cmH₂O).
// v3.2 의 양압 전용 센서와 달리 음압도 측정 가능.
//
// API 는 v3.2 sensor.h 와 호환되도록 설계 — state_machine.cpp 등 상위
// 모듈은 거의 그대로 포팅 가능.

#pragma once

#include <stdint.h>

namespace sensor {

  /// 부팅 시 영점 보정 (대기압 측정). 첫 N 샘플 평균을 zero offset 으로
  /// 저장. 사용자는 마우스피스 입에 물기 전이어야 함.
  void calibrateZero();

  /// 사용자 트리거 영점 재보정 — Settings UI 또는 BLE opcode 0x04 에서 호출.
  /// 10초간 측정 후 저장. 성공 시 true.
  bool recalibrateZero();

  /// 가장 최근 측정값 (cmH₂O). 양수=호기, 음수=흡기, |값|<5 정도면 정지.
  float currentCmH2O();

  /// raw ADC → cmH2O 변환 (영점 offset 적용 후). 호스트 테스트용 pure 함수.
  float adcToCmH2O(int adc, float zeroOffsetCmH2O);

  /// 메인 루프에서 100Hz 로 호출. EMA 필터 적용 후 internal buffer 업데이트.
  void tick();

  /// 영점 offset 직접 read — 디버그/캘리브레이션 UI 용.
  float zeroOffset();

}  // namespace sensor
