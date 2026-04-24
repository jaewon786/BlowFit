#pragma once

#include <stdint.h>
#include "config.h"

// Training session state machine.
// Time is driven by millis() externally; tick() drives transitions.

namespace state_machine {

struct Metrics {
  float maxPressure = 0.0f;      // cmH2O, session max of EMA
  float pressureSum = 0.0f;      // sum for avg (only active samples >= 5)
  uint32_t pressureSamples = 0;
  uint32_t enduranceMs = 0;      // accumulated time in target zone
  uint8_t targetHits = 0;        // 15s+ sustained holds
  uint32_t sessionStartMs = 0;
  uint32_t sessionDurationMs = 0;
  uint32_t sampleCount = 0;
  uint8_t orificeLevel = 1;
  uint32_t sessionId = 0;

  float avgPressure() const {
    return pressureSamples ? (pressureSum / (float)pressureSamples) : 0.0f;
  }
};

enum class Event : uint8_t {
  BootComplete,
  ButtonShort,
  ButtonLong,
  BleStartSession,
  BleStopSession,
};

void begin();

// Feed a filtered pressure sample into the state machine.
// Should be called every loop iteration after sensor::pop().
void onPressureSample(float cmH2O);

// Advance time-based transitions (call from loop()).
void tick(uint32_t nowMs);

// Queue a discrete event.
void dispatch(Event e, uint8_t payload = 0);

DeviceState state();
const Metrics& metrics();

// Target zone (configurable via BLE SET_TARGET).
void setTargetZone(float lowCmH2O, float highCmH2O);
float targetLow();
float targetHigh();

// Callback types used by higher layers (UI, feedback, BLE).
using StateChangeCb   = void (*)(DeviceState oldS, DeviceState newS);
using TargetZoneCb    = void (*)(bool enteredZone);    // rising edge events
using TargetHoldCb    = void (*)();                    // 15s hold achieved
using SessionEndCb    = void (*)(const Metrics&);

void onStateChange(StateChangeCb cb);
void onZoneChange(TargetZoneCb cb);
void onTargetHold(TargetHoldCb cb);
void onSessionEnd(SessionEndCb cb);

}  // namespace state_machine
