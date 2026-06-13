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

#include "config.h"  // session::IntensityLevel, 임상 상수.

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
  /// 4-phase cycle: Exhale 5s → ExhaleRest 5s → Inhale 5s → InhaleRest 5s.
  /// (호기 → 휴식 → 흡기 → 휴식 반복)
  enum class Turn : uint8_t {
    Exhale     = 0,
    ExhaleRest = 1,
    Inhale     = 2,
    InhaleRest = 3,
    None       = 4,   // Train 이외 state 에서.
  };

  /// startSession 의 시작 phase — 기본은 호기부터. PImax 측정 시 흡기로
  /// 시작하면 LCD 가 처음부터 "들이쉬기" 화면을 표시한다.
  enum class StartPhase : uint8_t {
    Exhale = 0,   // 기본 — 호기부터 cycle 시작
    Inhale = 1,   // 흡기 측정 모드
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
  /// phase: cycle 시작 위치. 기본 Exhale. 흡기 측정 등 특정 phase 부터
  /// 시작하려면 Inhale 전달 (cycle offset 으로 적용 → 첫 phase 부터 Inhale).
  void startSession(StartPhase phase = StartPhase::Exhale);

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

  /// 현재 세션의 고유 id (startSession 마다 증가, NVS 영속 → 재부팅에도 유일).
  /// BLE Summary 의 sessionId 로 전송 → 앱이 세션별 DB 행 구분에 사용.
  uint32_t sessionId();

  /// (Legacy) 절대값 target zone — 양/음 대칭으로 적용. v4.0 호환용.
  /// 새 코드는 setPimaxMep + setIntensity 로 흡기/호기 분리 target 을 쓸 것.
  void setTarget(float low, float high);
  float targetLow();
  float targetHigh();

  // ── %PImax / %MEP 기반 target (clinical, v4.1+) ──────────────────────────
  // setPimaxMep / setIntensity 가 호출되면 4 개 target 을 자동으로 재계산.
  // 안전 상한 (INHALE_SAFETY_LIMIT_CMH2O / EXHALE_SAFETY_LIMIT_CMH2O) 를 넘으면
  // 자동 clamp 되고 Serial 경고가 찍힌다.

  /// 사용자별 PImax (최대 흡기압) / MEP (최대 호기압) 주입. cmH₂O magnitude.
  /// 0 이하 값은 무시. 호출 시 target 즉시 재계산.
  void setPimaxMep(float pimax_cmH2O, float mep_cmH2O);

  /// 강도 단계 변경 — Beginner/Normal/Advanced. 한 변수만 바꾸면 4 개 target
  /// 이 한꺼번에 갱신된다.
  void setIntensity(IntensityLevel level);

  IntensityLevel intensity();
  float pimax();
  float mep();

  /// 흡기 target — magnitude (양수). 측정 압력 |p| 가 [low, high] 안이면
  /// "흡기 zone hit". session.cpp 내부에서 음수 부호 처리.
  float inhaleTargetLow();
  float inhaleTargetHigh();

  /// 호기 target — magnitude (양수). 측정 압력 p (양수) 가 [low, high] 안이면
  /// "호기 zone hit".
  float exhaleTargetLow();
  float exhaleTargetHigh();

  /// Train 세션 길이 설정 (BLE SET_DURATION opcode).
  /// config.h::session::TRAIN_DURATION_MIN_MS ~ MAX_MS 로 clamp.
  void setTrainDuration(uint32_t ms);
  uint32_t trainDurationMs();

}  // namespace session
