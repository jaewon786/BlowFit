// session.cpp — state machine implementation.

#include "session.h"
#include "config.h"

#include <Arduino.h>
#include <cmath>

namespace session {

namespace {

  // ============================================================
  // 데모용 짧은 시간 (테스트 편의). 실 사용 시 config.h::session 의
  // TRAIN_MS=240000, REST_MS=30000 으로 조정.
  // ============================================================
  constexpr uint32_t PREP_DURATION_MS    = 3000;    // 3초 카운트다운
  constexpr uint32_t TRAIN_DURATION_MS   = 60000;   // 1분
  constexpr uint32_t REST_DURATION_MS    = 10000;   // 10초
  constexpr uint32_t SUMMARY_DURATION_MS = 8000;    // 8초 자동 복귀
  constexpr uint8_t  DEMO_TOTAL_SETS          = 3;
  // Train 내부 호기/흡기 turn cycle.
  constexpr uint32_t TURN_EXHALE_MS = 30000;
  constexpr uint32_t TURN_INHALE_MS = 30000;
  constexpr uint32_t TURN_CYCLE_MS  = TURN_EXHALE_MS + TURN_INHALE_MS;

  State    g_state       = State::Boot;
  Turn     g_turn        = Turn::None;
  uint32_t g_state_start = 0;
  uint32_t g_session_start = 0;
  uint8_t  g_set_index   = 0;   // 1-base, 0 = none
  float    g_target_low  = TARGET_LOW_DEFAULT;
  float    g_target_high = TARGET_HIGH_DEFAULT;

  // 통계 누적.
  double   g_sum_abs_p   = 0.0;
  uint32_t g_sum_n       = 0;
  float    g_max_abs_p   = 0.0f;
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
    g_hit_ms    = 0;
    g_train_ms  = 0;
    g_session_start = 0;
    g_set_index = 0;
  }

  void finalizeStats(uint32_t now) {
    g_stats.avg_pressure = g_sum_n > 0
        ? (float)(g_sum_abs_p / g_sum_n)
        : 0.0f;
    g_stats.max_pressure = g_max_abs_p;
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

  /// Train state 의 turn cycle (호기 ↔ 흡기) 계산.
  Turn turnAt(uint32_t elapsed_in_train) {
    const uint32_t in_cycle = elapsed_in_train % TURN_CYCLE_MS;
    return in_cycle < TURN_EXHALE_MS ? Turn::Exhale : Turn::Inhale;
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
      g_train_ms += dt;

      // zone 안 (양압 OR 음압) 시간 누적.
      const bool in_zone =
          (p >= g_target_low  && p <= g_target_high) ||
          (p <= -g_target_low && p >= -g_target_high);
      if (in_zone) g_hit_ms += dt;

      // turn 갱신.
      g_turn = turnAt(elapsed);

      // Train 끝 → Rest 또는 Summary
      if (elapsed >= TRAIN_DURATION_MS) {
        if (g_set_index >= DEMO_TOTAL_SETS) {
          finalizeStats(now_ms);
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
    case State::Train:   total = TRAIN_DURATION_MS;   break;
    case State::Rest:    total = REST_DURATION_MS;    break;
    case State::Summary: total = SUMMARY_DURATION_MS; break;
    default:             return 0;
  }
  // Train 내부에서는 현재 turn 의 남은 시간을 반환 (UI 의 카운트다운).
  if (g_state == State::Train) {
    const uint32_t in_cycle = elapsed % TURN_CYCLE_MS;
    const uint32_t turn_left = (g_turn == Turn::Exhale)
        ? (TURN_EXHALE_MS - in_cycle)
        : (TURN_CYCLE_MS - in_cycle);
    return turn_left / 1000;
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
    p += per_set * ((float)e / TRAIN_DURATION_MS);
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

}  // namespace session
