#pragma once

#include <stdint.h>

// Non-blocking LED + vibration patterns. All timing uses millis().

namespace feedback {

enum class Pattern : uint8_t {
  Idle,             // LED slow heartbeat
  TrainActive,      // LED solid
  ZoneEntered,      // Single short vibration
  HoldAchieved,     // Double vibration
  SessionComplete,  // Triple long vibration
  BatteryLow,       // LED fast blink
  Charging,         // LED off
  CalibrateDone,    // Double vibration
};

void begin();
void setPattern(Pattern p);
void pulseVibration(uint16_t count, uint16_t onMs, uint16_t offMs);

// Called every loop iteration.
void tick(uint32_t nowMs);

}  // namespace feedback
