#pragma once

#include <stdint.h>

// Pressure sensor: CFSensor XGZP6847A005KPG (0-5 kPa, 3.3V).
// 100 Hz sampling via hardware timer -> ring buffer.

namespace sensor {

struct Sample {
  uint32_t tMillis;
  float raw;        // unfiltered cmH2O
  float filtered;   // EMA filtered
};

void begin();

// Advance ISR sampling. Called from hardware timer at 100 Hz.
void onTimerTick();

// Pop next unread sample into `out`. Returns false if buffer is empty.
// Safe to call from loop(); ring buffer is single-producer/single-consumer.
bool pop(Sample& out);

// Raw ADC -> cmH2O conversion (exposed for unit tests).
float adcToCmH2O(uint16_t adc);

// Latest filtered value (non-blocking snapshot).
float latestFiltered();

// Start zero calibration: averages next N samples to establish offset.
// Non-blocking; completion signalled via isCalibrating().
void startZeroCalibration();
bool isCalibrating();
float zeroOffset();

// Total samples produced since boot (for 100Hz stability check).
uint32_t sampleCount();

}  // namespace sensor
