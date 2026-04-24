#pragma once

#include <stdint.h>
#include "state_machine.h"

// Flash session storage using nRF52 internal flash (LittleFS via Adafruit_LittleFS).
// Stores the last N session summaries as a fixed-size array for cheap access.

namespace storage {

constexpr uint8_t MAX_HISTORY = 30;

struct HistoryEntry {
  uint32_t sessionId;
  uint16_t maxPressureX10;   // cmH2O * 10
  uint16_t durationSec;
};

void begin();

// Append a finished session's summary to history (evicts oldest).
void saveSession(const state_machine::Metrics& m);

// Fill `out` with up to MAX_HISTORY entries newest-first.
// Returns number of entries written.
uint8_t readHistory(HistoryEntry out[MAX_HISTORY]);

// Persisted calibration + target config.
void saveConfig(float zeroOffset, float targetLow, float targetHigh);
bool loadConfig(float& zeroOffset, float& targetLow, float& targetHigh);

}  // namespace storage
