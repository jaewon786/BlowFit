#include "sensor.h"
#include "config.h"

#ifdef ARDUINO
  #include <Arduino.h>
#else
  // Unit-test stubs. Tests set [g_hostAdc] / [g_hostMillis] before driving ticks.
  #include <cstdint>
  namespace sensor {
    uint16_t g_hostAdc = 0;
    uint32_t g_hostMillis = 0;
  }
  static uint16_t analogRead(uint8_t) { return sensor::g_hostAdc; }
  static uint32_t millis() { return sensor::g_hostMillis; }
  static void pinMode(uint8_t, uint8_t) {}
  static void analogReadResolution(uint8_t) {}
#endif

namespace sensor {

namespace {

constexpr size_t RING_SIZE = 64;   // 64 samples = 640 ms buffer at 100 Hz
volatile uint32_t g_head = 0;
volatile uint32_t g_tail = 0;
Sample g_ring[RING_SIZE];

float g_ema = 0.0f;
float g_zeroOffset = 0.0f;
volatile uint32_t g_sampleCount = 0;

bool g_calibrating = false;
uint32_t g_calSamplesRemaining = 0;
float g_calAccum = 0.0f;

}  // namespace

void begin() {
#ifdef ARDUINO
  pinMode(pins::PRESSURE_ADC, INPUT);
  analogReadResolution(12);  // 12-bit on nRF52840
#endif
  g_head = g_tail = 0;
  g_ema = 0.0f;
}

float adcToCmH2O(uint16_t adc) {
  using namespace sensor_cfg;
  float v = (float)adc * ADC_VREF / (float)ADC_MAX;
  float kPa = (v - OUT_LOW_V) / (OUT_HIGH_V - OUT_LOW_V) * KPA_FULL;
  if (kPa < 0.0f) kPa = 0.0f;
  return kPa * KPA_TO_CMH2O;
}

void onTimerTick() {
  uint16_t adc = analogRead(pins::PRESSURE_ADC);
#if SENSOR_DEBUG_RAW
  // Debug: 영점 보정 무시하고 raw ADC / 100 을 그대로 차트에 표시.
  // idle ≈ 2.5 (ADC 248 = 0.2V), sealed full scale 5kPa ≈ 33.5 (ADC 3350 = 2.7V).
  // Y축 max=40 가 절대값 기준이라 풀스케일까지 다 보임.
  float raw = (float)adc / 100.0f;
#else
  float raw = adcToCmH2O(adc) - g_zeroOffset;
#endif

  // EMA filter
  g_ema = sensor_cfg::EMA_ALPHA * raw + (1.0f - sensor_cfg::EMA_ALPHA) * g_ema;

#if !SENSOR_DEBUG_RAW
  // Calibration accumulator (debug 모드에선 영점 보정 사용 안 함)
  if (g_calibrating) {
    g_calAccum += adcToCmH2O(adc);  // include offset so accum measures absolute
    if (--g_calSamplesRemaining == 0) {
      g_zeroOffset = g_calAccum / (float)sensor_cfg::ZERO_CAL_SAMPLES;
      g_calAccum = 0.0f;
      g_calibrating = false;
    }
  }
#endif

  // Enqueue (drop oldest on overflow)
  uint32_t next = (g_head + 1) % RING_SIZE;
  if (next == g_tail) {
    g_tail = (g_tail + 1) % RING_SIZE;  // drop oldest
  }
  g_ring[g_head] = Sample{ millis(), raw, g_ema };
  g_head = next;
  g_sampleCount++;
}

bool pop(Sample& out) {
  if (g_tail == g_head) return false;
  out = g_ring[g_tail];
  g_tail = (g_tail + 1) % RING_SIZE;
  return true;
}

float latestFiltered() { return g_ema; }

void startZeroCalibration() {
  g_calAccum = 0.0f;
  g_calSamplesRemaining = sensor_cfg::ZERO_CAL_SAMPLES;
  g_calibrating = true;
}

bool isCalibrating() { return g_calibrating; }
float zeroOffset()   { return g_zeroOffset; }
uint32_t sampleCount() { return g_sampleCount; }

}  // namespace sensor
