// BLE GATT 서비스 (BlowFit Training Service).
//
// docs/ble-protocol.md 의 BlowFit Training Service 구현. ESP32 BLE Arduino
// (framework-arduinoespressif32 내장) 기반.
//
// 흐름:
//   setup()       → ble_service::begin()
//   loop()        → 100Hz 압력 sample 수집, 10개 차면 ble_service::pushSamples()
//                  → state 변경 시 ble_service::pushState()
//                  → Summary 진입 시 ble_service::pushSummary()
//   앱 → 기기     → SESSION_CONTROL write 콜백이 session::startSession() 등 호출

#pragma once

#include <stdint.h>

namespace ble_service {

  /// BLE stack 초기화 + 광고 시작. setup() 에서 1회 호출.
  void begin();

  /// loop() 에서 호출 (현재는 no-op — ESP32 BLE Arduino 가 자동 처리).
  void poll();

  /// 앱이 연결되어 있는지 확인. standby 화면 BT dot 색, notify 가드 등.
  bool isConnected();

  /// Pressure Stream (22B) notify.
  ///   samplesX10: cmH2O × 10 의 int16 배열 (양수=호기, 음수=흡기)
  ///   count: 보통 10. 부족하면 zero-pad.
  void pushSamples(const int16_t samplesX10[], uint8_t count);

  /// Device State (4B) notify. state 변경 시 호출.
  void pushState(uint8_t state_id, uint8_t orifice, uint8_t battery, bool charging);

  /// Session Summary (40B) notify. Summary state 진입 시 호출.
  /// maxPressure/avgPressure 는 호기(양압) 통계, avgInhale/maxInhale 은 흡기(음압)
  /// 통계 (양수 magnitude). 0..31 은 기존 32B 레이아웃과 동일, 32..39 append.
  struct SummaryFields {
    uint32_t startEpoch;     // SYNC_TIME 전이면 0
    uint32_t durationSec;
    float    maxPressure;    // 호기 최대 (cmH2O)
    float    avgPressure;    // 호기 평균
    uint32_t enduranceSec;   // zone hold 누적
    uint8_t  orificeLevel;
    uint8_t  targetHits;
    uint16_t sampleCount;
    uint32_t crc32;
    uint32_t sessionId;
    float    avgInhale;      // 흡기 평균 magnitude (양수)
    float    maxInhale;      // 흡기 최대 magnitude (양수)
  };
  void pushSummary(const SummaryFields& s);

  /// 앱이 SYNC_TIME 으로 전송한 epoch 초.
  uint32_t startEpoch();

}  // namespace ble_service
