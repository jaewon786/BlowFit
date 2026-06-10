// session.cpp — state machine implementation.

#include "session.h"
#include "config.h"
#include "haptic.h"

#include <Arduino.h>
#include <cmath>
#if HAS_FLASH
#include <Preferences.h>
#endif

namespace session {

namespace {

  // ============================================================
  // Timing — 모두 config.h::session 의 임상 상수에서 derive. 한 곳 관리.
  //
  //   1 호흡 cycle (Exhale → ExhaleRest=0 → Inhale → InhaleRest)
  //     = 5s + 0s + 5s + 5s = 15 s
  //   10 cycles                  = 150 s = 1 set
  //   2 sets + 세트 사이 30 s   ≈ 5.5 분 = 1 session
  //
  // 4-phase Turn enum 은 v4.0 호환을 위해 유지. ExhaleRest=0 이라 사실상
  // 3-phase (Exhale → Inhale → InhaleRest) 동작. UI/햅틱 분기 코드는
  // ExhaleRest 가 즉시 skip 되는 식으로 무변경.
  // ============================================================
  constexpr uint32_t TURN_EXHALE_MS      = BREATH_EXHALE_MS;  // 5000
  constexpr uint32_t TURN_EXHALE_REST_MS = 0;                 // skip
  constexpr uint32_t TURN_INHALE_MS      = BREATH_INHALE_MS;  // 5000
  constexpr uint32_t TURN_INHALE_REST_MS = BREATH_REST_MS;    // 5000 (한 호흡 끝)
  constexpr uint32_t TURN_CYCLE_MS =
      TURN_EXHALE_MS + TURN_EXHALE_REST_MS +
      TURN_INHALE_MS + TURN_INHALE_REST_MS;  // 15000

  State    g_state       = State::Boot;
  Turn     g_turn        = Turn::None;
  Turn     g_prev_turn   = Turn::None;  // 햅틱 cue 용 — phase 전환 감지
  uint32_t g_state_start = 0;
  uint32_t g_session_start = 0;
  uint32_t g_session_id  = 0;   // 세션 고유 id (NVS 영속, startSession 마다 +1)
  uint8_t  g_set_index   = 0;   // 1-base, 0 = none

  // PImax/MEP/Intensity — sets/getters 가 변경 시 recomputeTargets() 호출.
  float           g_pimax     = PIMAX_DEFAULT_CMH2O;
  float           g_mep       = MEP_DEFAULT_CMH2O;
  IntensityLevel  g_intensity = INTENSITY_DEFAULT;

  // 계산된 target — magnitude (양수). recomputeTargets() 결과물.
  float g_inhale_target_low  = 0.0f;
  float g_inhale_target_high = 0.0f;
  float g_exhale_target_low  = 0.0f;
  float g_exhale_target_high = 0.0f;

  // Legacy 대칭 target — setTarget(low, high) 가 들어오면 갱신.
  // 새 코드는 setPimaxMep + setIntensity 를 쓰지만, BLE v4.0 클라이언트가
  // legacy 2B payload 를 보낼 수 있으므로 backing field 유지.
  float g_target_low  = 0.0f;   // recomputeTargets() 에서 초기화
  float g_target_high = 0.0f;
  bool  g_legacy_target_active = false;   // setTarget() 가 호출되면 true

  // Train 세션 길이 (1 set 기준) — 앱이 SET_DURATION 으로 변경 가능.
  // 기본 = SET_TRAIN_MS (150 s = 1 set). 앱이 5분 보내면 세션 전체가 5분.
  uint32_t g_train_duration_ms = SET_TRAIN_MS;

  // turnAt() 호출 시 elapsed 에 더하는 cycle 내 시작 offset.
  // 0       → Exhale 부터 시작 (기본)
  // TURN_EXHALE_MS (=5000) → Inhale 부터 시작 (PImax 측정 모드)
  // startSession(phase) 가 설정.
  uint32_t g_cycle_offset_ms = 0;

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

  /// PImax/MEP/Intensity 변경 시 흡기/호기 target 4개 자동 재계산.
  /// 안전 상한 초과 시 clamp + Serial 경고.
  /// setTarget(low, high) 가 별도 호출되어 있던 상태 (legacy 대칭) 라면
  /// 그 값을 흡기/호기 양쪽에 그대로 적용해서 v4.0 호환을 유지한다.
  void recomputeTargets() {
    if (g_legacy_target_active) {
      // Legacy 절대값 — 흡기/호기 동일 magnitude.
      g_inhale_target_low  = g_target_low;
      g_inhale_target_high = g_target_high;
      g_exhale_target_low  = g_target_low;
      g_exhale_target_high = g_target_high;
      return;
    }
    const uint8_t i = static_cast<uint8_t>(g_intensity);
    const float low_pct  = INTENSITY_LOW_PCT[i];
    const float high_pct = INTENSITY_HIGH_PCT[i];

    // 흡기 target — PImax × %.
    float inh_lo = g_pimax * low_pct;
    float inh_hi = g_pimax * high_pct;
    if (inh_hi > INHALE_SAFETY_LIMIT_CMH2O) {
      Serial.printf("[session] WARN: inhale target %.1f > safety %.1f cmH2O — clamped\n",
                    inh_hi, INHALE_SAFETY_LIMIT_CMH2O);
      inh_hi = INHALE_SAFETY_LIMIT_CMH2O;
      if (inh_lo > inh_hi) inh_lo = inh_hi;
    }
    g_inhale_target_low  = inh_lo;
    g_inhale_target_high = inh_hi;

    // 호기 target — MEP × %.
    float exh_lo = g_mep * low_pct;
    float exh_hi = g_mep * high_pct;
    if (exh_hi > EXHALE_SAFETY_LIMIT_CMH2O) {
      Serial.printf("[session] WARN: exhale target %.1f > safety %.1f cmH2O — clamped\n",
                    exh_hi, EXHALE_SAFETY_LIMIT_CMH2O);
      exh_hi = EXHALE_SAFETY_LIMIT_CMH2O;
      if (exh_lo > exh_hi) exh_lo = exh_hi;
    }
    g_exhale_target_low  = exh_lo;
    g_exhale_target_high = exh_hi;

    Serial.printf(
        "[session] targets: level=%u inhale -%.1f~-%.1f exhale +%.1f~+%.1f (PImax=%.1f MEP=%.1f)\n",
        (unsigned)g_intensity,
        g_inhale_target_low, g_inhale_target_high,
        g_exhale_target_low, g_exhale_target_high,
        g_pimax, g_mep);
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
    g_stats.total_sets     = TOTAL_SETS;
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
  recomputeTargets();  // 기본 (Normal · PImax80 / MEP60) 으로 4개 target 초기화
#if HAS_FLASH
  // 마지막 세션 id 복원 — 재부팅에도 id 가 단조 증가하도록.
  Preferences prefs;
  if (prefs.begin("blowfit", /*readOnly=*/true)) {
    g_session_id = prefs.getUInt("sess_id", 0);
    prefs.end();
  }
#endif
}

void startSession(StartPhase phase) {
  if (g_state != State::Standby && g_state != State::Summary) {
    Serial.println("[session] startSession ignored — not in Standby/Summary");
    return;
  }
  const uint32_t now = millis();
  resetStats();
  // cycle 시작 phase 적용. Inhale 로 시작하려면 첫 phase (Exhale) 길이만큼
  // offset 을 줘서 turnAt 결과가 즉시 Inhale 이 되도록 한다. Train 의 elapsed
  // (= 진행률) 자체는 0 부터 시작 → progress bar 영향 없음.
  g_cycle_offset_ms = (phase == StartPhase::Inhale) ? TURN_EXHALE_MS : 0;
  // 세션마다 고유 id 부여 (1-base, 0 은 "없음") + NVS 영속.
  g_session_id += 1;
#if HAS_FLASH
  Preferences prefs;
  if (prefs.begin("blowfit", /*readOnly=*/false)) {
    prefs.putUInt("sess_id", g_session_id);
    prefs.end();
  }
#endif
  g_session_start = now;
  g_set_index = 1;
  transition(State::Prep, now);
  haptic::play(haptic::SESSION_START);  // 시작 진동 피드백
  Serial.printf("[session] session started (id=%lu)\n",
                (unsigned long)g_session_id);
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
      if (elapsed >= PREP_MS) {
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

      // zone hit — phase 별로 비대칭 적용:
      //   호기 turn  → 양압 p 가 [exhale_low, exhale_high]
      //   흡기 turn  → 음압 |p| 가 [inhale_low, inhale_high]
      // 휴식 (ExhaleRest/InhaleRest) 은 hit 평가 제외.
      bool in_zone = false;
      if (g_turn == Turn::Exhale) {
        in_zone = (p >= g_exhale_target_low && p <= g_exhale_target_high);
      } else if (g_turn == Turn::Inhale) {
        const float mag = -p;  // 음압 magnitude
        in_zone = (mag >= g_inhale_target_low && mag <= g_inhale_target_high);
      }
      if (in_zone) g_hit_ms += dt;

      // turn 갱신. cycle offset 으로 시작 phase 조정 (PImax 측정 모드 등).
      g_turn = turnAt(elapsed + g_cycle_offset_ms);

      // 호흡 phase 전환 시 햅틱 cue — 눈 안 보고도 호기/흡기/휴식 시점 인지.
      // 첫 진입(None→Exhale)은 세션 시작 click 으로 대체하므로 생략.
      if (g_turn != g_prev_turn) {
        if (g_prev_turn != Turn::None) {
          if (g_turn == Turn::Exhale) {
            haptic::play(haptic::EXHALE_CUE);
          } else if (g_turn == Turn::Inhale) {
            haptic::play(haptic::INHALE_CUE);
          } else if (g_turn == Turn::InhaleRest) {
            haptic::play(haptic::REST_TICK);  // 휴식 시작 — 짧은 진동
          }
        }
        g_prev_turn = g_turn;
      }

      // Train 끝 → Rest 또는 Summary
      if (elapsed >= g_train_duration_ms) {
        if (g_set_index >= TOTAL_SETS) {
          finalizeStats(now_ms);
          haptic::play(haptic::SESSION_DONE, 3);  // 완료 진동 (길게 3회)
          transition(State::Summary, now_ms);
        } else {
          haptic::play(haptic::REST_CUE);  // 휴식 전환 진동
          transition(State::Rest, now_ms);
        }
      }
      break;
    }

    case State::Rest:
      g_turn = Turn::None;
      if (elapsed >= SET_REST_MS) {
        g_set_index += 1;
        transition(State::Train, now_ms);
      }
      break;

    case State::Summary:
      g_turn = Turn::None;
      if (elapsed >= SUMMARY_MS) {
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
    case State::Prep:    total = PREP_MS;             break;
    case State::Train:   total = g_train_duration_ms; break;
    case State::Rest:    total = SET_REST_MS;         break;
    case State::Summary: total = SUMMARY_MS;          break;
    default:             return 0;
  }
  // Train 내부에서는 현재 turn (4-phase) 의 남은 시간을 반환.
  if (g_state == State::Train) {
    // ceil 로 변환 — 표시 시 1초 단위로 자연스럽게 카운트다운.
    // 시작 phase offset 반영 — Inhale 시작 모드에서도 phase 잔여 시간 정확.
    const uint32_t ms = turnRemainingMs(elapsed + g_cycle_offset_ms);
    return (uint16_t)((ms + 999) / 1000);
  }
  if (elapsed >= total) return 0;
  return (total - elapsed) / 1000;
}

uint8_t progressPercent() {
  if (g_state == State::Standby || g_state == State::Boot) return 0;
  if (g_state == State::Summary) return 100;
  // 전체 세션 진행률 = (현재 set - 1 + 현재 set 내 progress) / TOTAL_SETS.
  const float per_set = 1.0f / TOTAL_SETS;
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

uint32_t sessionId() { return g_session_id; }

// ─── Legacy 절대값 target (v4.0 BLE 호환) ────────────────────────────────────
// 호출되는 순간 g_legacy_target_active=true 로 잠그고 흡기/호기 동일 magnitude
// 로 적용. 새 setPimaxMep/setIntensity 가 호출되면 다시 false 로 풀린다.
void setTarget(float low, float high) {
  g_target_low  = low;
  g_target_high = high;
  g_legacy_target_active = true;
  recomputeTargets();
  Serial.printf("[session] setTarget (legacy) low=%.1f high=%.1f\n", low, high);
}
float targetLow()  { return g_target_low; }
float targetHigh() { return g_target_high; }

// ─── %PImax / %MEP 기반 target (clinical, v4.1+) ─────────────────────────────
void setPimaxMep(float pimax_cmH2O, float mep_cmH2O) {
  if (pimax_cmH2O > 0.0f) g_pimax = pimax_cmH2O;
  if (mep_cmH2O   > 0.0f) g_mep   = mep_cmH2O;
  g_legacy_target_active = false;  // clinical 모드 활성
  recomputeTargets();
}
void setIntensity(IntensityLevel level) {
  if (level > INTENSITY_ADVANCED) level = INTENSITY_ADVANCED;
  g_intensity = level;
  g_legacy_target_active = false;
  recomputeTargets();
}
IntensityLevel intensity() { return g_intensity; }
float pimax()              { return g_pimax; }
float mep()                { return g_mep; }
float inhaleTargetLow()    { return g_inhale_target_low; }
float inhaleTargetHigh()   { return g_inhale_target_high; }
float exhaleTargetLow()    { return g_exhale_target_low; }
float exhaleTargetHigh()   { return g_exhale_target_high; }

void setTrainDuration(uint32_t ms) {
  // config.h::session 의 TRAIN_DURATION_MIN/MAX_MS 로 clamp.
  if (ms < TRAIN_DURATION_MIN_MS) ms = TRAIN_DURATION_MIN_MS;
  if (ms > TRAIN_DURATION_MAX_MS) ms = TRAIN_DURATION_MAX_MS;
  g_train_duration_ms = ms;
  Serial.printf("[session] train duration = %u ms\n", (unsigned)g_train_duration_ms);
}
uint32_t trainDurationMs() { return g_train_duration_ms; }

}  // namespace session
