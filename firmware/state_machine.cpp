#include "state_machine.h"

#include <stddef.h>

namespace state_machine {

namespace {

DeviceState g_state = DeviceState::Boot;
Metrics g_metrics;
uint32_t g_phaseStartMs = 0;
uint8_t g_setIndex = 0;

float g_targetLow  = train_cfg::DEFAULT_TARGET_LOW_CMH2O;
float g_targetHigh = train_cfg::DEFAULT_TARGET_HIGH_CMH2O;

bool g_inZone = false;
uint32_t g_zoneEnterMs = 0;
uint32_t g_lastSampleMs = 0;
bool g_holdCountedThisEntry = false;

StateChangeCb g_onStateChange = nullptr;
TargetZoneCb  g_onZoneChange  = nullptr;
TargetHoldCb  g_onTargetHold  = nullptr;
SessionEndCb  g_onSessionEnd  = nullptr;

uint32_t g_nextSessionId = 1;

void transition(DeviceState next, uint32_t nowMs) {
  if (next == g_state) return;
  DeviceState prev = g_state;
  g_state = next;
  g_phaseStartMs = nowMs;
  if (g_onStateChange) g_onStateChange(prev, next);
}

void startSession(uint32_t nowMs, uint8_t orifice) {
  g_metrics = Metrics{};
  g_metrics.sessionStartMs = nowMs;
  g_metrics.orificeLevel = orifice;
  // sessionId 는 session 시작 시점의 millis() 사용. 부팅 안에서 monotonic 하고,
  // 부팅마다 첫 세션 시작 시점이 달라서 cross-reboot 충돌이 사실상 안 일어남.
  // 앱 DB unique key (deviceSessionId) 와 결합해 retransmission dedup 도 유지.
  // nowMs == 0 인 host test 에선 기존 카운터로 fallback.
  g_metrics.sessionId = (nowMs > 0) ? nowMs : g_nextSessionId;
  g_nextSessionId++;
  g_setIndex = 0;
  g_inZone = false;
  g_holdCountedThisEntry = false;
  transition(DeviceState::Prep, nowMs);
}

void endSession(uint32_t nowMs) {
  g_metrics.sessionDurationMs = nowMs - g_metrics.sessionStartMs;
  transition(DeviceState::Summary, nowMs);
  if (g_onSessionEnd) g_onSessionEnd(g_metrics);
}

}  // namespace

void begin() {
  g_state = DeviceState::Standby;
  g_phaseStartMs = 0;
}

void setTargetZone(float lo, float hi) {
  if (lo < 0) lo = 0;
  if (hi <= lo) hi = lo + 1;
  g_targetLow = lo;
  g_targetHigh = hi;
}

float targetLow()  { return g_targetLow; }
float targetHigh() { return g_targetHigh; }

void onStateChange(StateChangeCb cb) { g_onStateChange = cb; }
void onZoneChange(TargetZoneCb cb)   { g_onZoneChange = cb; }
void onTargetHold(TargetHoldCb cb)   { g_onTargetHold = cb; }
void onSessionEnd(SessionEndCb cb)   { g_onSessionEnd = cb; }

DeviceState state() { return g_state; }
const Metrics& metrics() { return g_metrics; }

void onPressureSample(float cmH2O) {
  if (g_state != DeviceState::Train) return;

  g_metrics.sampleCount++;
  if (cmH2O > g_metrics.maxPressure) g_metrics.maxPressure = cmH2O;
  if (cmH2O >= 5.0f) {
    g_metrics.pressureSum += cmH2O;
    g_metrics.pressureSamples++;
  }

  // Target zone with hysteresis
  bool nowInZone;
  if (g_inZone) {
    nowInZone = (cmH2O >= g_targetLow - train_cfg::ZONE_HYSTERESIS_CMH2O);
  } else {
    nowInZone = (cmH2O >= g_targetLow);
  }

  uint32_t now = g_lastSampleMs;  // Set by tick()
  uint32_t sampleIntervalMs = 1000 / sensor_cfg::SAMPLE_RATE_HZ;

  if (nowInZone) {
    if (!g_inZone) {
      g_inZone = true;
      g_zoneEnterMs = now;
      g_holdCountedThisEntry = false;
      if (g_onZoneChange) g_onZoneChange(true);
    }
    g_metrics.enduranceMs += sampleIntervalMs;

    if (!g_holdCountedThisEntry && (now - g_zoneEnterMs) >= train_cfg::TARGET_HOLD_MS) {
      g_metrics.targetHits++;
      g_holdCountedThisEntry = true;
      if (g_onTargetHold) g_onTargetHold();
    }
  } else {
    if (g_inZone) {
      g_inZone = false;
      if (g_onZoneChange) g_onZoneChange(false);
    }
  }
}

void tick(uint32_t nowMs) {
  g_lastSampleMs = nowMs;
  uint32_t dt = nowMs - g_phaseStartMs;

  switch (g_state) {
    case DeviceState::Prep:
      if (dt >= train_cfg::PREP_MS) transition(DeviceState::Train, nowMs);
      break;
    case DeviceState::Train:
      if (dt >= train_cfg::TRAIN_SET_MS) {
        g_setIndex++;
        if (g_setIndex >= train_cfg::TOTAL_SETS) endSession(nowMs);
        else transition(DeviceState::Rest, nowMs);
      }
      break;
    case DeviceState::Rest:
      if (dt >= train_cfg::REST_MS) transition(DeviceState::Train, nowMs);
      break;
    case DeviceState::Summary:
      // Auto-return to STANDBY after 10 s (user can extend via button)
      if (dt >= 10000) transition(DeviceState::Standby, nowMs);
      break;
    default:
      break;
  }
}

void dispatch(Event e, uint8_t payload) {
  uint32_t now = g_lastSampleMs;
  switch (e) {
    case Event::BootComplete:
      transition(DeviceState::Standby, now);
      break;
    case Event::ButtonShort:
      if (g_state == DeviceState::Standby) {
        startSession(now, 1);  // default medium
      } else if (g_state == DeviceState::Summary) {
        transition(DeviceState::Standby, now);
      } else if (g_state == DeviceState::Standby && false) {
        // reserved for mode cycling
      }
      break;
    case Event::ButtonLong:
      if (g_state == DeviceState::Standby) {
        transition(DeviceState::Weekly, now);
      } else {
        endSession(now);
      }
      break;
    case Event::BleStartSession:
      if (g_state == DeviceState::Standby) startSession(now, payload);
      break;
    case Event::BleStopSession:
      if (g_state == DeviceState::Train || g_state == DeviceState::Rest
          || g_state == DeviceState::Prep) {
        endSession(now);
      }
      break;
  }
}

}  // namespace state_machine
