// Training session state machine.
//
// 흐름: Boot -> Standby -> Prep -> Train -> Rest -> Train -> ... -> Summary -> Standby
//
// v3.2 firmware/state_machine.cpp 를 ESP32 단순화 포팅. BLE notify / NVS 저장 등은
// 후속 마일스톤 (M8 BLE, M9 NVS) 에서 hook 으로 추가.
//
// 외부에서:
//   session::tick(now_ms, current_pressure_cmH2O)  매 loop iteration 호출.
//   session::start() / stop()                      사용자 트리거 (버튼 / BLE).
//   session::state()                                현재 state.
//   session::stats()                                Summary 표시용 통계.

#pragma once

#include <stdint.h>

namespace session {

  enum class State : uint8_t {
    Boot     = 0,
    Standby  = 1,
    Prep     = 2,
    Train    = 3,
    Rest     = 4,
    Summary  = 5,
    Error    = 7,
  };

  /// Training 내 호기/흡기 turn — UI 표시용. session 이 자동 cycle.
  /// 4-phase cycle: Exhale 10s → ExhaleRest 3s → Inhale 10s → InhaleRest 3s.
  enum class Turn : uint8_t {
    Exhale     = 0,
    ExhaleRest = 1,
    Inhale     = 2,
    InhaleRest = 3,
    None       = 4,   // Train 이외 state 에서.
  };

  struct Stats {
    float    avg_pressure;  // 세션 평균 |p| (cmH2O) — 기기 자체 Summary 화면용
    float    max_pressure;  // 세션 max |p|
    float    avg_exhale;    // 호기(양압 p>0) 평균
    float    max_exhale;    // 호기 최대
    float    avg_inhale;    // 흡기(음압 p<0) 평균 — 양수 magnitude
    float    max_inhale;    // 흡기 최대 magnitude
    uint32_t hit_ms;        // zone 안 머문 총 시간 (ms)
    uint32_t train_ms;      // 총 train 시간 (ms, 분모)
    uint8_t  hit_percent;   // hit_ms / train_ms * 100
    uint16_t duration_sec;  // 세션 총 지속 시간 (s)
    uint8_t  completed_sets;
    uint8_t  total_sets;
  };

  /// 초기화 (setup 에서 한 번 호출).
  void begin();

  /// 사용자 트리거 — Standby 또는 Summary 에서만 동작.
  void startSession();

  /// 사용자 트리거 — 어디서든 호출하면 Standby 로 복귀 (Summary 생략).
  void stopSession();

  /// 매 loop iteration 호출 — state 전환 + 통계 누적.
  /// current_pressure: 현재 sensor 값 (cmH2O, +/-).
  void tick(uint32_t now_ms, float current_pressure_cmH2O);

  /// 현재 state.
  State currentState();

  /// Train 내부 호기/흡기 turn.
  Turn currentTurn();

  /// 현재 state 의 남은 시간 (s). Standby/Summary 면 0.
  uint16_t remainingSec();

  /// 현재 세트 (1-base). Standby 면 0.
  uint8_t currentSet();

  /// 세션 진행률 (0~100). Summary 도달 시 100.
  uint8_t progressPercent();

  /// Summary 통계 (Summary state 에서만 의미 있음).
  const Stats& stats();

  /// 목표 압력 zone 설정 (BLE setTarget opcode 또는 NVS load 후).
  void setTarget(float low, float high);
  float targetLow();
  float targetHigh();

}  // namespace session
