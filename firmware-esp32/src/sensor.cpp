// sensor.cpp — MPXV7007DP (MikroE Diff Press Click) + MCP3221 I²C ADC.
//
// 양방향 차압 센서, ratiometric 출력. JP1=3V3 위치 + Click 보드 위 3V3↔5V
// short 로 단일 3.3V 레일 운용 (under-spec, 호흡 훈련 영역엔 충분).
//
// 변환식 (Vs 무관 ratiometric):
//   ratio = adc / 4095     ← MCP3221 12-bit, VDD 대비 ratiometric
//   ΔP_kPa = (ratio - 0.5) / 0.057
//   ΔP_cmH2O = ΔP_kPa × 10.197
//
// 호스트 g++ 테스트 빌드 호환:
//   - ARDUINO 매크로 분기로 Wire 의존성 격리
//   - hostSetAdc(int) 로 fake ADC value 주입 가능

#include "sensor.h"
#include "config.h"

#include <cmath>

#if defined(ARDUINO)
  #include <Arduino.h>
  #include <Wire.h>
#else
  // 호스트 테스트 stub — Wire 없음.
  static int g_hostAdc = 2048;   // 영점 근처 default
  namespace sensor { void hostSetAdc(int adc) { g_hostAdc = adc; } }
#endif

namespace sensor {

namespace {
  float g_zeroOffset = 0.0f;
  float g_emaCurrent = 0.0f;
  constexpr float EMA_ALPHA = 0.3f;  // EMA 강도 — 노이즈 / 응답성 trade-off.
  TickHook g_tickHook = nullptr;     // calibrate 동안 매 sample 마다 호출 (LVGL refresh).

  /// MCP3221 에서 12-bit ADC 값 read.
  /// 반환: 0..4095 (정상), -1 (5회 retry 후 I²C 통신 실패)
  /// 일시적 BLE/LVGL 간섭으로 한 번 실패해도 retry 로 흡수.
  int readMcp3221() {
#if defined(ARDUINO)
    for (int attempt = 0; attempt < 5; ++attempt) {
      const uint8_t got = Wire.requestFrom(MCP3221_ADDR, (uint8_t)2);
      if (got >= 2) {
        const uint8_t hi = Wire.read();
        const uint8_t lo = Wire.read();
        return ((uint16_t)(hi & 0x0F) << 8) | lo;
      }
      if (attempt < 4) delay(2);  // 2ms 대기 후 재시도
    }
    return -1;
#else
    return g_hostAdc;
#endif
  }

}  // anonymous

void setTickHook(TickHook hook) {
  g_tickHook = hook;
}

float adcToCmH2O(int adc, float zeroOffsetCmH2O) {
  // adc < 0 = I²C 실패 — 0 으로 처리 (영점에서 적용).
  if (adc < 0) return -zeroOffsetCmH2O;

  const float ratio = adc / static_cast<float>(ADC_MAX);
  const float kPa = (ratio - ZERO_RATIO) / K_FACTOR_RATIO;
  // PRESSURE_SIGN: 센서 포트 방향 보정 (반대로 연결 시 -1.0 으로 극성 반전).
  const float cm = kPa * KPA_TO_CMH2O * PRESSURE_SIGN;

  // saturation guard
  float clamped = cm - zeroOffsetCmH2O;
  if (clamped > MAX_CMH2O) clamped = MAX_CMH2O;
  if (clamped < MIN_CMH2O) clamped = MIN_CMH2O;
  return clamped;
}

void calibrateZero() {
  // 첫 N 샘플 평균을 zero offset 으로 저장.
  // setup() 에서 한 번만 호출 — ~2초 지연 발생 (200 sample × 10ms).
  double accumulator = 0.0;
  int valid_samples = 0;
  for (int i = 0; i < ZERO_CALIBRATION_SAMPLES; i++) {
    const int adc = readMcp3221();
    if (adc >= 0) {
      accumulator += adcToCmH2O(adc, /*zeroOffset=*/0.0f);
      valid_samples++;
    }
#if defined(ARDUINO)
    if (g_tickHook) g_tickHook();
    delay(10);
#endif
  }
  // I²C 실패가 많아 valid sample 부족 시 영점 0 유지 (보수적).
  if (valid_samples > ZERO_CALIBRATION_SAMPLES / 2) {
    g_zeroOffset = static_cast<float>(accumulator / valid_samples);
  } else {
    g_zeroOffset = 0.0f;
  }
}

bool recalibrateZero() {
  calibrateZero();
  return true;
}

void tick() {
  const int adc = readMcp3221();
  if (adc < 0) {
    // I²C 통신 실패 — EMA 유지 (값 안 갱신, decay 안 함).
    return;
  }
  const float instant = adcToCmH2O(adc, g_zeroOffset);
  g_emaCurrent = EMA_ALPHA * instant + (1.0f - EMA_ALPHA) * g_emaCurrent;
}

float currentCmH2O() {
  return g_emaCurrent;
}

float zeroOffset() {
  return g_zeroOffset;
}

}  // namespace sensor
