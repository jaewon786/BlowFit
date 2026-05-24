// sensor.cpp — XGZP6847A010KPGPN33 (양방향 ±102 cmH₂O) 구현.
//
// 호스트 g++ 테스트 빌드 호환을 위해 ARDUINO 매크로 분기.

#include "sensor.h"
#include "config.h"

#if defined(ARDUINO)
  #include <Arduino.h>
#else
  // 호스트 테스트 stub — analogRead 가짜 + delay 무시.
  static int g_hostAdc = 0;
  inline int analogRead(int) { return g_hostAdc; }
  namespace sensor { void hostSetAdc(int adc) { g_hostAdc = adc; } }
#endif

namespace sensor {

namespace {
  float g_zeroOffset = 0.0f;
  float g_emaCurrent = 0.0f;
  constexpr float EMA_ALPHA = 0.3f;  // EMA 강도 — 노이즈 / 응답성 trade-off.
  TickHook g_tickHook = nullptr;     // calibrate 동안 매 sample 마다 호출 (LVGL refresh).
}  // anonymous

void setTickHook(TickHook hook) {
  g_tickHook = hook;
}

float adcToCmH2O(int adc, float zeroOffsetCmH2O) {
  const float voltage = (adc * ADC_VREF) / static_cast<float>(ADC_MAX);
  const float kPa = (voltage - ZERO_VOLTAGE) / K_FACTOR;
  const float cm = kPa * KPA_TO_CMH2O;
  // saturation guard
  float clamped = cm - zeroOffsetCmH2O;
  if (clamped > MAX_CMH2O) clamped = MAX_CMH2O;
  if (clamped < MIN_CMH2O) clamped = MIN_CMH2O;
  return clamped;
}

void calibrateZero() {
  // 첫 N 샘플 평균을 zero offset 으로 저장.
  // 이 함수는 setup() 에서 한 번만 호출 — 5초 지연 발생.
  double accumulator = 0.0;
  for (int i = 0; i < ZERO_CALIBRATION_SAMPLES; i++) {
    const int adc = analogRead(pins::PRESSURE_SENSOR);
    accumulator += adcToCmH2O(adc, /*zeroOffset=*/0.0f);
#if defined(ARDUINO)
    // LVGL refresh hook — 등록되어 있으면 매 sample 마다 호출 → boot 화면의
    // spinner 등 애니메이션이 5초 보정 동안에도 계속 회전.
    if (g_tickHook) g_tickHook();
    delay(10);  // 100Hz 샘플링 간격
#endif
  }
  g_zeroOffset = static_cast<float>(accumulator / ZERO_CALIBRATION_SAMPLES);
}

bool recalibrateZero() {
  // 영점 재보정 — 사용자 트리거. setup 의 calibrateZero 와 동일.
  calibrateZero();
  return true;
}

void tick() {
  const int adc = analogRead(pins::PRESSURE_SENSOR);
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
