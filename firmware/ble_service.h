#pragma once

#include <stdint.h>
#include "state_machine.h"

namespace ble_service {

void begin();

// Push a batch of recent samples out as a Pressure Stream notification.
// Called every ble_cfg::NOTIFY_INTERVAL_MS when connected and in TRAIN.
void pushSamples(const int16_t samplesX10[], uint8_t count);

// Push current DeviceState and battery.
void pushState(DeviceState s, uint8_t orificeLevel, uint8_t batteryPct, bool charging);

// Push session summary (sent when SessionEnd event fires).
void pushSummary(const state_machine::Metrics& m, uint32_t crc32);

// Service BLE stack; call from loop().
void poll();

bool isConnected();

// Epoch (unix seconds) provided by the app via SYNC_TIME; 0 if not synced.
uint32_t startEpoch();

}  // namespace ble_service
