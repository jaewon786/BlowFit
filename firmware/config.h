// Pin map, tunable constants, and shared enums.
// Keep this header free of Arduino-only types so tests can include it.

#pragma once

#include <stdint.h>

// ----- Pin map (Seeed XIAO BLE nRF52840) -----
namespace pins {
  constexpr uint8_t PRESSURE_ADC = 0;   // D0  (A0)
  constexpr uint8_t BUTTON       = 1;   // D1
  constexpr uint8_t LED          = 2;   // D2
  constexpr uint8_t VIBRATION    = 3;   // D3 (PWM)
  constexpr uint8_t TFT_CS       = 4;   // D4
  constexpr uint8_t TFT_DC       = 5;   // D5
  constexpr uint8_t TFT_RST      = 6;   // D6
  // TFT SCK/MOSI use hardware SPI (D8/D10)
}

// ----- Sensor -----
namespace sensor_cfg {
  constexpr float ADC_VREF         = 3.3f;
  constexpr uint16_t ADC_MAX       = 4095;     // 12-bit
  constexpr float OUT_LOW_V        = 0.2f;     // 0 kPa
  constexpr float OUT_HIGH_V       = 2.7f;     // 5 kPa
  constexpr float KPA_FULL         = 5.0f;
  constexpr float KPA_TO_CMH2O     = 10.197f;
  constexpr float EMA_ALPHA        = 0.2f;
  constexpr uint16_t SAMPLE_RATE_HZ = 100;
  constexpr uint16_t ZERO_CAL_SAMPLES = 500;   // 5 s at 100 Hz
}

// ----- Training -----
namespace train_cfg {
  constexpr float DEFAULT_TARGET_LOW_CMH2O  = 20.0f;
  constexpr float DEFAULT_TARGET_HIGH_CMH2O = 30.0f;
  constexpr float ZONE_HYSTERESIS_CMH2O     = 3.0f;
  constexpr uint16_t TARGET_HOLD_MS         = 15000; // 15 s for targetHit
  constexpr uint32_t PREP_MS                = 30000;
  constexpr uint32_t TRAIN_SET_MS           = 4UL * 60 * 1000;
  constexpr uint32_t REST_MS                = 60UL * 1000;
  constexpr uint8_t  TOTAL_SETS             = 3;
  constexpr uint32_t COOLDOWN_MS            = 30000;
}

// ----- Orifice -----
enum class OrificeLevel : uint8_t {
  Low    = 0,  // 4.0 mm
  Medium = 1,  // 3.0 mm
  High   = 2,  // 2.0 mm
};

// ----- Device state (matches docs/ble-protocol.md 3.4) -----
enum class DeviceState : uint8_t {
  Boot    = 0,
  Standby = 1,
  Prep    = 2,
  Train   = 3,
  Rest    = 4,
  Summary = 5,
  Weekly  = 6,
  Error   = 7,
};

// ----- BLE -----
namespace ble_cfg {
  constexpr uint16_t NOTIFY_INTERVAL_MS = 50;    // 20 Hz
  constexpr uint8_t SAMPLES_PER_PACKET  = 10;
  constexpr uint16_t REQUESTED_MTU      = 185;
}

// ----- UI / Feedback -----
namespace ui_cfg {
  constexpr uint16_t RENDER_INTERVAL_MS = 50;    // 20 FPS
  constexpr uint16_t BUTTON_SCAN_MS     = 20;
  constexpr uint16_t LONG_PRESS_MS      = 2000;
  constexpr uint16_t BATTERY_POLL_MS    = 10000;
}

// ----- Power -----
namespace power_cfg {
  constexpr uint32_t STANDBY_SLEEP_MS = 5UL * 60 * 1000;  // 5 min idle -> deep sleep
  constexpr uint32_t BLE_IDLE_STOP_MS = 10UL * 60 * 1000;
}
