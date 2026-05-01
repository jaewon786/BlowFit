// Pin map, tunable constants, and shared enums.
// Keep this header free of Arduino-only types so tests can include it.

#pragma once

#include <stdint.h>

// ----- Hardware feature flags -----
// 외부 페리페럴이 아직 도착하지 않았을 때 또는 BSP 가 해당 라이브러리를 제공
// 하지 않을 때 활성 코드를 우회하기 위한 컴파일 시 토글. 1 로 바꾸면 해당
// 모듈의 실제 하드웨어 코드가 빌드됨.
#ifndef HAS_TFT
#define HAS_TFT 1   // ST7735 0.96" TFT 활성. TFT_eSPI 라이브러리 + User_Setup.h 필요.
#endif
#ifndef HAS_FLASH
#define HAS_FLASH 0 // mbed BSP + Adafruit_LittleFS 환경 정리 후 1
#endif
#ifndef HAS_BATTERY
#define HAS_BATTERY 0 // VBAT divider (P0.31 / AIN7) 배선 + mbed SAADC 안정화 후 1
#endif

// SENSOR_DEBUG_RAW=1 로 빌드하면 차트 표시값이 cmH2O 가 아니라 raw ADC / 100 이 됨.
// idle ~2.5 (ADC 248), 5kPa 풀스케일 ~33.5 (ADC 3350) 가 정상 범위.
// 변환식 / 센서 모델 확정 디버그용. 검증 끝나면 0 으로 되돌리기.
#ifndef SENSOR_DEBUG_RAW
#define SENSOR_DEBUG_RAW 0
#endif

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
  // 5V supply 직결 (분압 미사용). 5kPa 풀스케일 = 4.5V 인데 ADC ref 3.3V 라
  // 약 35 cmH2O 부터 saturation. 훈련 영역 (20~30 cmH2O) 는 안전 범위 안.
  // 분압회로 추가하면 풀스케일 측정 가능 — 추후 작업.
  constexpr float OUT_LOW_V        = 0.5f;     // 0 kPa @ 5V supply (datasheet)
  constexpr float OUT_HIGH_V       = 4.5f;     // 5 kPa @ 5V supply (datasheet)
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
  constexpr uint32_t REST_MS                = 30UL * 1000;   // UI 가이드와 일치 (앱 D1 결정 후속)
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
