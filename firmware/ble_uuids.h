// Single source of truth for BLE UUIDs. MUST match:
//   - docs/ble-protocol.md
//   - tools/ble-sim.py
//   - app/lib/core/ble/blowfit_uuids.dart

#pragma once

namespace uuids {
  // Custom service + characteristics
  constexpr const char* SERVICE            = "0000b410-0000-1000-8000-00805f9b34fb";
  constexpr const char* PRESSURE_STREAM    = "0000b411-0000-1000-8000-00805f9b34fb";
  constexpr const char* SESSION_CONTROL    = "0000b412-0000-1000-8000-00805f9b34fb";
  constexpr const char* SESSION_SUMMARY    = "0000b413-0000-1000-8000-00805f9b34fb";
  constexpr const char* DEVICE_STATE       = "0000b414-0000-1000-8000-00805f9b34fb";
  constexpr const char* HISTORY_LIST       = "0000b415-0000-1000-8000-00805f9b34fb";

  // Standard
  constexpr const char* BATTERY_SERVICE    = "180f";
  constexpr const char* BATTERY_LEVEL      = "2a19";
  constexpr const char* DEVICE_INFO        = "180a";
  constexpr const char* FIRMWARE_REVISION  = "2a26";
}

// Session Control opcodes
namespace opcode {
  constexpr uint8_t START_SESSION  = 0x01;
  constexpr uint8_t STOP_SESSION   = 0x02;
  constexpr uint8_t SYNC_TIME      = 0x03;
  constexpr uint8_t ZERO_CALIBRATE = 0x04;
  constexpr uint8_t SET_TARGET     = 0x05;
}

// Advertised name (product: BlowFit)
constexpr const char* DEVICE_NAME = "BlowFit";
constexpr const char* FIRMWARE_VERSION = "1.0.0";
