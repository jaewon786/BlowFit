// BLE UUID 단일 출처 (BlowFit Training Service).
// docs/ble-protocol.md 와 app/lib/core/ble/blowfit_uuids.dart 와 동일.
// v3.2 firmware/ble_uuids.h 의 카피 — v4.0 ESP32 BLE Arduino 에서도 그대로 사용.

#pragma once

#include <stdint.h>

namespace uuids {
  // Custom BlowFit Training Service + characteristics
  constexpr const char* SERVICE            = "0000b410-0000-1000-8000-00805f9b34fb";
  constexpr const char* PRESSURE_STREAM    = "0000b411-0000-1000-8000-00805f9b34fb";
  constexpr const char* SESSION_CONTROL    = "0000b412-0000-1000-8000-00805f9b34fb";
  constexpr const char* SESSION_SUMMARY    = "0000b413-0000-1000-8000-00805f9b34fb";
  constexpr const char* DEVICE_STATE       = "0000b414-0000-1000-8000-00805f9b34fb";
  constexpr const char* HISTORY_LIST       = "0000b415-0000-1000-8000-00805f9b34fb";

  // 표준 (현재 미구현 — 후속 마일스톤)
  constexpr const char* BATTERY_SERVICE    = "180f";
  constexpr const char* BATTERY_LEVEL      = "2a19";
  constexpr const char* DEVICE_INFO        = "180a";
  constexpr const char* FIRMWARE_REVISION  = "2a26";
}

// Session Control opcodes (Write to SESSION_CONTROL char)
namespace opcode {
  constexpr uint8_t START_SESSION  = 0x01;
  constexpr uint8_t STOP_SESSION   = 0x02;
  constexpr uint8_t SYNC_TIME      = 0x03;
  constexpr uint8_t ZERO_CALIBRATE = 0x04;
  constexpr uint8_t SET_TARGET     = 0x05;
}

// 광고 이름 + 펌웨어 버전
constexpr const char* BLE_DEVICE_NAME    = "BlowFit";
constexpr const char* BLE_FIRMWARE_VER   = "4.0.0";
