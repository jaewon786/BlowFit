#pragma once

#include <stdint.h>

namespace power {

void begin();

// Read battery percentage (0-100). Uses VBAT ADC + LiPo discharge curve.
uint8_t batteryPct();

// Approximate charging detection (USB-C VBUS present).
bool isCharging();

// Request deep sleep; wakes on button interrupt.
void enterDeepSleep();

}  // namespace power
