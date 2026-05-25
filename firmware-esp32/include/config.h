// BlowFit v4.0 펌웨어 — 핀맵 + 상수 + enum.
// LILYGO T-Display S3 (ESP32-S3) 기준.
//
// 전반적 룩-필은 v3.2 firmware/config.h 와 비슷하지만 보드/센서가 달라
// 핀 번호와 일부 토글이 변경됨. 호스트 g++ 테스트 호환을 위해 Arduino-only
// 타입은 헤더에 두지 않음.

#pragma once

#include <stdint.h>

// ----- Hardware feature flags -----
// 외부 페리페럴이 아직 도착하지 않았을 때 또는 BSP 가 해당 라이브러리를 제공
// 하지 않을 때 활성 코드를 우회하기 위한 컴파일 시 토글.
#ifndef HAS_DISPLAY
#define HAS_DISPLAY 1   // LILYGO T-Display S3 일체형 1.9" IPS. TFT_eSPI Setup206.
#endif
#ifndef HAS_LVGL
#define HAS_LVGL 1      // LVGL 9.x GUI. lv_conf.h 활성화 필요.
#endif
#ifndef HAS_FLASH
#define HAS_FLASH 1     // ESP32 NVS (Preferences) — 기본 활성. 세션 영속화.
#endif
#ifndef HAS_BATTERY
#define HAS_BATTERY 1   // VBAT 모니터링 (LiPo 400mAh, T-Display S3 내장 회로).
#endif
#ifndef HAS_BLE
#define HAS_BLE 1       // ESP32 BLE Arduino. v4.0 의 핵심 기능.
#endif

// ----- Pin map -----
namespace pins {

  // 외부 부품 — 사용자 배선
  // 압력 센서는 MikroE Diff Press Click (MPXV7007DP + MCP3221 12-bit I²C ADC).
  // 보드 내장 MCP3221 이 0~5V analog 를 받아 I²C 로 변환 → MCU 측 GPIO 는 3.3V
  // logic 만 노출되어 안전. 자세한 내용은 docs/mpxv7007_migration.md 참조.
  constexpr uint8_t I2C_SDA         = 43;  // GPIO43 (UART0 TX, USB-CDC 사용 중이라 free)
  constexpr uint8_t I2C_SCL         = 44;  // GPIO44 (UART0 RX, 위와 동일)
  constexpr uint8_t VIBRATION       = 10;  // GPIO10 PWM — 진동 모터
  constexpr uint8_t LED_STATUS      = 11;  // GPIO11 — 상태 LED (선택)

  // 내장 — TFT_eSPI Setup206 가 자동 처리. 참고용으로만 명시:
  //   GPIO5  — TFT_RST
  //   GPIO7  — TFT_DC
  //   GPIO8  — TFT_WR (쓰기 strobe)
  //   GPIO9  — TFT_RD
  //   GPIO39~48 — 8-bit 병렬 데이터
  //   GPIO38 — 백라이트 PWM (TFT_BL, TFT_eSPI 가 직접 제어)
  //   GPIO15 — LDO 전원 enable (배터리 모드 HIGH 필수, firmware setup() 직접 처리)
  constexpr uint8_t TFT_POWER_ON = 15;  // LDO enable — 배터리 모드 필수

  // 사용자 입력 버튼 (T-Display S3 내장)
  constexpr uint8_t BUTTON_BOOT = 0;   // 부트 버튼 (short = startSession, long = deep sleep)
  constexpr uint8_t BUTTON_USER = 14;  // 사용자 버튼 (short = stopSession)

  // 외부 전원 버튼 (M11) — ETP164L 6x6 tact + LED.
  // ESP32-S3 의 모든 GPIO 가 RTC GPIO 라 EXT0 deep sleep wakeup 가능.
  // GPIO12 는 좌측 헤더 free + ADC1 가능 (배터리 측정 후 옵션).
  constexpr uint8_t PWR_BUTTON  = 12;  // 외부 전원 버튼 (input pullup)
  constexpr uint8_t PWR_LED     = 13;  // 외부 전원 LED (output, 220Ω 직렬)

}  // namespace pins

// ----- Power management (M11) -----
namespace power {

  // Deep sleep 진입 조건.
  constexpr uint32_t LONG_PRESS_MS    = 2000;   // 전원 버튼 long-press = 2초
  // BOOT 버튼은 short-press 가 startSession 이라 long-press 로 deep sleep.
  // 외부 PWR_BUTTON (ETP164L) 은 short-press 만으로 deep sleep (별도 long
  // press 의미 없음, 그저 켜고 끄기).

  // Standby idle 시 자동 deep sleep (옵션 — 추후 활성화).
  // constexpr uint32_t IDLE_DEEP_SLEEP_MS = 5UL * 60 * 1000;  // 5분

}  // namespace power

// ----- Pressure sensor (MPXV7007DP via MikroE Diff Press Click + MCP3221) -----
// 양방향 차압 센서, 5V Vs, ±7 kPa (≈ ±71 cmH₂O). 보드 내장 MCP3221 12-bit I²C
// ADC 가 sensor output (0.5~4.5V) 을 ratiometric 으로 변환.
//
// 변환식 (datasheet, 5V ratiometric):
//   Vout/Vs = 0.057 × ΔP_kPa + 0.5
//   ratio   = ADC / 4095
//   ΔP_kPa  = (ratio - 0.5) / 0.057
//   ΔP_cmH2O = ΔP_kPa × 10.197
//
// MCP3221 은 VDD 기준 ratiometric 이라 절대 전압 측정 불필요 — ADC ↔ ratio 만
// 사용. ADC_VREF 같은 항목은 의도적으로 두지 않음.
namespace sensor {

  constexpr int   ADC_MAX        = 4095;     // MCP3221 12-bit
  constexpr float ZERO_RATIO     = 0.5f;     // ΔP=0 시 ratio (datasheet)
  constexpr float K_FACTOR_RATIO = 0.057f;   // ratio per kPa
  constexpr float KPA_TO_CMH2O   = 10.197f;

  // MCP3221 I²C 주소 — 0x48~0x4F 중 하나. MikroE Click 기본 0x4D 추정.
  // MS2 (tools/i2c_scan) 로 실측 확인 후 필요 시 갱신.
  constexpr uint8_t MCP3221_ADDR = 0x4D;
  // I²C frequency: 100kHz standard-mode. 400kHz Fast-mode 도 가능하지만 본
  // 펌웨어의 LVGL/BLE task 점유 환경에선 100kHz 가 더 안정적. i2c_scan
  // sketch 는 가벼워서 400kHz OK 였음.
  constexpr uint32_t I2C_FREQ_HZ = 100000;   // Standard-mode (안정성 우선)

  // 영점 보정용 — 부팅 후 첫 N 샘플 평균을 zeroOffset 로 저장.
  // 부팅 시간 2초 = 200 sample × 10ms. 더 길게 (500 = 5초) 하면 평균 noise
  // 감소하지만 호흡 훈련 응용엔 200 sample 도 충분.
  constexpr int   ZERO_CALIBRATION_SAMPLES = 200;  // 100Hz × 2초

  // 안전한 측정 범위 (saturation guard). MPXV7007 풀스케일 ±71 cmH₂O 보다 약간
  // 보수적으로 설정 → 비정상 입력은 clamp.
  constexpr float MIN_CMH2O = -71.0f;
  constexpr float MAX_CMH2O = +71.0f;

}  // namespace sensor

// ----- Training session timing -----
namespace session {

  constexpr uint32_t PREP_MS    = 0;        // 준비 단계 — 0 (디버그 결정)
  constexpr uint32_t TRAIN_MS   = 240000;   // 4분
  constexpr uint32_t REST_MS    = 30000;    // 30초
  constexpr uint8_t  TOTAL_SETS = 3;
  constexpr uint16_t SAMPLE_HZ  = 100;

  // 목표 압력 기본 — 사용자가 SET_TARGET opcode 로 변경 가능.
  // 양방향이라 흡기/호기 각각 별도. v3.2 는 호기만 있었음.
  constexpr float TARGET_LOW_DEFAULT  = 20.0f;   // cmH2O
  constexpr float TARGET_HIGH_DEFAULT = 30.0f;
  constexpr uint16_t TARGET_HOLD_MS   = 15000;   // 15초

}  // namespace session

// ----- BLE -----
namespace ble {

  // ATT MTU 협상 목표 — Pressure Stream 22B 패킷이 한 packet 에 들어가도록.
  constexpr uint16_t MTU_TARGET = 185;

  // Connection interval 권장 (ms) — 짧으면 끊김 적고 배터리 소모 큼.
  constexpr uint16_t CONN_INTERVAL_MIN_MS = 15;
  constexpr uint16_t CONN_INTERVAL_MAX_MS = 30;

  // 광고 이름. v3.2 와 동일한 prefix 'BlowFit' — 앱이 prefix 매칭으로 스캔.
  constexpr const char* DEVICE_NAME = "BlowFit";

}  // namespace ble

// ----- Display (LVGL) -----
// 세로 모드 native — TFT_eSPI 의 setRotation(0) 기준.
// (가로 모드 필요 시 setRotation(1) + SCREEN_W/H 스왑.)
namespace display {

  constexpr int16_t SCREEN_W = 170;  // T-Display S3 세로 모드
  constexpr int16_t SCREEN_H = 320;
  constexpr uint8_t TARGET_FPS = 60;
  constexpr uint8_t ROTATION   = 0;  // 0=세로 (USB 아래), 2=세로 뒤집힘

}  // namespace display

// ----- Device State enum (v3.2 와 동일) -----
enum DeviceState : uint8_t {
  STATE_BOOT     = 0,
  STATE_STANDBY  = 1,
  STATE_PREP     = 2,
  STATE_TRAIN    = 3,
  STATE_REST     = 4,
  STATE_SUMMARY  = 5,
  STATE_WEEKLY   = 6,
  STATE_ERROR    = 7,
};

// ----- Orifice Level enum -----
enum OrificeLevel : uint8_t {
  ORIFICE_LOW    = 0,  // 4mm 디스크
  ORIFICE_MEDIUM = 1,  // 3mm 디스크
  ORIFICE_HIGH   = 2,  // 2mm 디스크
};
