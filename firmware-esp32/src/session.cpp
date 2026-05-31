// session.cpp — state machine implementation.

#include "session.h"
#include "config.h"
#include "haptic.h"

#include <Arduino.h>
#include <cmath>

namespace session {

namespace {

  // ============================================================
  // 데모용 짧은 시간 (테스트 편의). 실 사용 시 config.h::session 의
  // TRAIN_MS=240000, REST_MS=30000 으로 조정.
  // ============================================================
  constexpr uint32_t PREP_DURATION_MS    = 0;        // PREP 스킵 — 즉시 TRAIN
  constexpr uint32_t TRAIN_DURATION_DEFAULT_MS = 300000;  // 기본 5분 (앱이 변경 가능)
  constexpr uint32_t REST_DURATION_MS    = 5000;     // set 사이 휴식 5초
  constexpr uint32_t SUMMARY_DURATION_MS = 8000;     // 8초 자동 복귀
  constexpr uint8_t  DEMO_TOTAL_SETS     = 1;        // sets 단순화 — 1 set
  // Train 내부 4-phase turn cycle (앱 spec 일치):
  //   Exhale 10s → ExhaleRest 5s → Inhale 10s → InhaleRest 5s = 30s/cycle
  constexpr uint32_t TURN_EXHALE_MS      = 10000;
  constexpr uint32_t TURN_EXHALE_REST_MS = 5000;
  constexpr uint32_t TURN_INHALE_MS      = 10000;
  constexpr uint32_t TURN_INHALE_REST_MS = 5000;
  constexpr uint32_t TURN_CYCLE_MS =
      TURN_EXHALE_MS + TURN_EXHALE_REST_MS +
      TURN_INHALE_MS + TURN_INHALE_REST_MS;

  State    g_state       = State::Boot;
  Turn     g_turn        = Turn::None;
  Turn     g_prev_turn   = Turn::None;  // 햅틱 cue 용 — phase 전환 감지
  uint32_t g_state_start = 0;
  uint32_t g_session_start = 0;
  uint8_t  g_set_index   = 0;   // 1-base, 0 = none
  float    g_target_low  = TARGET_LOW_DEFAULT;
  float    g_target_high = TARGET_HIGH_DEFAULT;
  // Train 세션 길이 — 앱이 SET_DURATION (opcode 0x06) 으로 변경. 기본 5분.
  uint32_t g_train_duration_ms = TRAIN_DURATION_DEFAULT_MS;

  // 통계 누적.
  double   g_sum_abs_p   = 0.0;
  uint32_t g_sum_n       = 0;
  float    g_max_abs_p   = 0.0f;
  // 호기(양압)/흡기(음압) 분리 누적 — 앱 추이 차트의 호기/흡기선 실데이터용.
  double   g_sum_exhale  = 0.0;
  uint32_t g_n_exhale    = 0;
  float    g_max_exhale  = 0.0f;
  double   g_sum_inhale  = 0.0;  // |p| 누적 (음압의 절댓값)
  uint32_t g_n_inhale    = 0;
  float    g_max_inhale  = 0.0f;  // 최대 음압 magnitude
  uint32_t g_hit_ms      = 0;
  uint32_t g_train_ms    = 0;
  Stats    g_stats       = {};

  // tick 간 dt 계산용.
  uint32_t g_last_tick_ms = 0;

  void transition(State next, uint32_t now) {
    g_state = next;
    g_state_start = now;
    Serial.printf("[session] -> %u\n", (unsigned)next);
  }

  void resetStats() {
    g_sum_abs_p = 0;
    g_sum_n     = 0;
    g_max_abs_p = 0;
    g_sum_exhale = 0;
    g_n_exhale   = 0;
    g_max_exhale = 0;
    g_sum_inhale = 0;
    g_n_inhale   = 0;
    g_max_inhale = 0;
    g_hit_ms    = 0;
    g_train_ms  = 0;
    g_session_start = 0;
    g_set_index = 0;
    g_prev_turn = Turn::None;
  }

  void finalizeStats(uint32_t now) {
    g_stats.avg_pressure = g_sum_n > 0
        ? (float)(g_sum_abs_p / g_sum_n)
        : 0.0f;
    g_stats.max_pressure = g_max_abs_p;
    g_stats.avg_exhale = g_n_exhale > 0
        ? (float)(g_sum_exhale / g_n_exhale)
        : 0.0f;
    g_stats.max_exhale = g_max_exhale;
    g_stats.avg_inhale = g_n_inhale > 0
        ? (float)(g_sum_inhale / g_n_inhale)
        : 0.0f;
    g_stats.max_inhale = g_max_inhale;
    g_stats.hit_ms       = g_hit_ms;
    g_stats.train_ms     = g_train_ms;
    g_stats.hit_percent  = g_train_ms > 0
        ? (uint8_t)((g_hit_ms * 100) / g_train_ms)
        : 0;
    g_stats.duration_sec = g_session_start > 0
        ? (now - g_session_start) / 1000
        : 0;
    g_stats.completed_sets = g_set_index;
    g_stats.total_sets     = DEMO_TOTAL_SETS;
  }

  /// Train state 의 turn cycle (4-phase: Exhale/ExhaleRest/Inhale/InhaleRest).
  Turn turnAt(uint32_t elapsed_in_train) {
    const uint32_t in_cycle = elapsed_in_train % TURN_CYCLE_MS;
    if (in_cycle < TURN_EXHALE_MS) return Turn::Exhale;
    uint32_t t = in_cycle - TURN_EXHALE_MS;
    if (t < TURN_EXHALE_REST_MS) return Turn::ExhaleRest;
    t -= TURN_EXHALE_REST_MS;
    if (t < TURN_INHALE_MS) return Turn::Inhale;
    return Turn::InhaleRest;
  }

  /// 현재 turn 의 남은 시간 (ms).
  uint32_t turnRemainingMs(uint32_t elapsed_in_train) {
    const uint32_t in_cycle = elapsed_in_train % TURN_CYCLE_MS;
    uint32_t phase_end;
    if (in_cycle < TURN_EXHALE_MS) {
      phase_end = TURN_EXHALE_MS;
    } else if (in_cycle < TURN_EXHALE_MS + TURN_EXHALE_REST_MS) {
      phase_end = TURN_EXHALE_MS + TURN_EXHALE_REST_MS;
    } else if (in_cycle < TURN_EXHALE_MS + TURN_EXHALE_REST_MS + TURN_INHALE_MS) {
      phase_end = TURN_EXHALE_MS + TURN_EXHALE_REST_MS + TURN_INHALE_MS;
    } else {
      phase_end = TURN_CYCLE_MS;
    }
    return phase_end - in_cycle;
  }

}  // anonymous namespace

void begin() {
  g_state = State::Boot;
  g_turn  = Turn::None;
  resetStats();
}

void startSession() {
  if (g_state != State::Standby && g_state != State::Summary) {
    Serial.println("[session] startSession ignored — not in Standby/Summary");
    return;
  }
  const uint32_t now = millis();
  resetStats();
  g_session_start = now;
  g_set_index = 1;
  transition(State::Prep, now);
  haptic::play(haptic::SESSION_START);  // 시작 진동 피드백
  Serial.println("[session] session started");
}

void stopSession() {
  if (g_state == State::Standby) return;
  const uint32_t now = millis();
  finalizeStats(now);
  transition(State::Standby, now);
  g_turn = Turn::None;
  Serial.println("[session] session stopped");
}

void tick(uint32_t now_ms, float p) {
  // dt 계산.
  uint32_t dt = 0;
  if (g_last_tick_ms != 0 && now_ms > g_last_tick_ms) {
    dt = now_ms - g_last_tick_ms;
  }
  g_last_tick_ms = now_ms;

  const uint32_t elapsed = (g_state_start > 0) ? (now_ms - g_state_start) : 0;

  switch (g_state) {
    case State::Boot:
      transition(State::Standby, now_ms);
      break;

    case State::Standby:
      g_turn = Turn::None;
      break;

    case State::Prep:
      g_turn = Turn::None;
      if (elapsed >= PREP_DURATION_MS) {
        transition(State::Train, now_ms);
      }
      break;

    case State::Train: {
      // 통계 누적 (현재 sensor 값 기준).
      const float abs_p = std::fabs(p);
      if (abs_p > g_max_abs_p) g_max_abs_p = abs_p;
      g_sum_abs_p += abs_p;
      g_sum_n += 1;
      // 호기/흡기 분리 — 양압은 호기, 음압은 흡기 (magnitude 로 누적).
      if (p > 0.0f) {
        g_sum_exhale += p;
        g_n_exhale += 1;
        if (p > g_max_exhale) g_max_exhale = p;
      } else if (p < 0.0f) {
        const float mag = -p;
        g_sum_inhale += mag;
        g_n_inhale += 1;
        if (mag > g_max_inhale) g_max_inhale = mag;
      }
      g_train_ms += dt;

      // zone 안 (양압 OR 음압) 시간 누적.
      const bool in_zone =
          (p >= g_target_low  && p <= g_target_high) ||
          (p <= -g_target_low && p >= -g_target_high);
      if (in_zone) g_hit_ms += dt;

      // turn 갱신.
      g_turn = turnAt(elapsed);

      // 호흡 phase 전환 시 햅틱 cue — 눈 안 보고도 호기/흡기 시점 인지.
      // 첫 진입(None→Exhale)은 세션 시작 click 으로 대체하므로 생략.
      if (g_turn != g_prev_turn) {
        if (g_prev_turn != Turn::None) {
          if (g_turn == Turn::Exhale) {
            haptic::play(haptic::EXHALE_CUE);
          } else if (g_turn == Turn::Inhale) {
            haptic::play(haptic::INHALE_CUE);
          }
        }
        g_prev_turn = g_turn;
      }

      // Train 끝 → Rest 또는 Summary
      if (elapsed >= g_train_duration_ms) {
        if (g_set_index >= DEMO_TOTAL_SETS) {
          finalizeStats(now_ms);
          haptic::play(haptic::SESSION_DONE);  // 완료 진동
          transition(State::Summary, now_ms);
        } else {
          transition(State::Rest, now_ms);
        }
      }
      break;
    }

    case State::Rest:
      g_turn = Turn::None;
      if (elapsed >= REST_DURATION_MS) {
        g_set_index += 1;
        transition(State::Train, now_ms);
      }
      break;

    case State::Summary:
      g_turn = Turn::None;
      if (elapsed >= SUMMARY_DURATION_MS) {
        transition(State::Standby, now_ms);
      }
      break;

    case State::Error:
      // 별도 처리 없음 — 사용자가 reset.
      break;
  }
}

State currentState() { return g_state; }
Turn  currentTurn()  { return g_turn; }
uint8_t currentSet() { return g_set_index; }

uint16_t remainingSec() {
  if (g_state_start == 0) return 0;
  const uint32_t elapsed = millis() - g_state_start;
  uint32_t total = 0;
  switch (g_state) {
    case State::Prep:    total = PREP_DURATION_MS;    break;
    case State::Train:   total = g_train_duration_ms; break;
    case State::Rest:    total = REST_DURATION_MS;    break;
    case State::Summary: total = SUMMARY_DURATION_MS; break;
    default:             return 0;
  }
  // Train 내부에서는 현재 turn (4-phase) 의 남은 시간을 반환.
  if (g_state == State::Train) {
    // ceil 로 변환 — 표시 시 1초 단위로 자연스럽게 카운트다운.
    const uint32_t ms = turnRemainingMs(elapsed);
    return (uint16_t)((ms + 999) / 1000);
  }
  if (elapsed >= total) return 0;
  return (total - elapsed) / 1000;
}

uint8_t progressPercent() {
  if (g_state == State::Standby || g_state == State::Boot) return 0;
  if (g_state == State::Summary) return 100;
  // 전체 세션 진행률 = (현재 set - 1 + 현재 set 내 progress) / DEMO_TOTAL_SETS.
  const float per_set = 1.0f / DEMO_TOTAL_SETS;
  float p = (g_set_index - 1) * per_set;
  if (g_state == State::Train) {
    const uint32_t e = millis() - g_state_start;
    p += per_set * ((float)e / g_train_duration_ms);
  } else if (g_state == State::Rest) {
    p += per_set;  // 세트 끝
  } else if (g_state == State::Prep) {
    // prep 은 0% 로 처리
  }
  if (p > 1.0f) p = 1.0f;
  return (uint8_t)(p * 100);
}

const Stats& stats() { return g_stats; }

void setTarget(float low, float high) {
  g_target_low  = low;
  g_target_high = high;
}
float targetLow()  { return g_target_low; }
float targetHigh() { return g_target_high; }

void setTrainDuration(uint32_t ms) {
  // 안전 범위 1~60분으로 clamp.
  if (ms < 60000)   ms = 60000;
  if (ms > 3600000) ms = 3600000;
  g_train_duration_ms = ms;
  Serial.printf("[session] train duration = %u ms\n", (unsigned)g_train_duration_ms);
}
uint32_t trainDurationMs() { return g_train_duration_ms; }

}  // namespace session
