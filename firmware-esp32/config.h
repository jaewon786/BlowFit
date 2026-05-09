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
  constexpr uint8_t PRESSURE_SENSOR = 4;   // GPIO4 (ADC1) — XGZP6847A010KPGPN33 OUT
  constexpr uint8_t VIBRATION       = 10;  // GPIO10 PWM — 진동 모터
  constexpr uint8_t LED_STATUS      = 11;  // GPIO11 — 상태 LED (선택)

  // 내장 — TFT_eSPI Setup206 가 자동 처리. 참고용으로만 명시:
  //   GPIO5  — TFT_RST
  //   GPIO6  — TFT_CS
  //   GPIO7  — TFT_DC
  //   GPIO15 — 백라이트 enable (배터리 모드 HIGH 필수)
  //   GPIO38 — 백라이트 PWM
  //   GPIO39~48 — 8-bit 병렬 데이터
  constexpr uint8_t TFT_BACKLIGHT_ENABLE = 15;

}  // namespace pins

// ----- Pressure sensor (XGZP6847A010KPGPN33) -----
// 양방향 차압 센서, 3.3V, -10~+10 kPa = -102~+102 cmH₂O.
namespace sensor {

  constexpr float ADC_VREF = 3.3f;       // ADC 기준 전압
  constexpr int   ADC_MAX  = 4095;       // 12-bit ESP32 ADC
  constexpr float ZERO_VOLTAGE = 1.45f;  // 0 압력 시 출력 전압 (데이터시트)
  constexpr float K_FACTOR     = 0.125f; // -10~+10 kPa 3.3V 모델 K
  constexpr float KPA_TO_CMH2O = 10.197f;

  // 영점 보정용 — 부팅 후 첫 N 샘플 평균을 zeroOffset 로 저장.
  constexpr int   ZERO_CALIBRATION_SAMPLES = 500;  // 100Hz × 5초

  // 안전한 측정 범위 (saturation guard)
  constexpr float MIN_CMH2O = -120.0f;
  constexpr float MAX_CMH2O = +120.0f;

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
namespace display {

  constexpr int16_t SCREEN_W = 320;  // T-Display S3 가로 모드
  constexpr int16_t SCREEN_H = 170;
  constexpr uint8_t TARGET_FPS = 60;

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
