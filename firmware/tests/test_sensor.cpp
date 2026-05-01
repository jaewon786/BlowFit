// PC-buildable unit test for sensor module.
// Compile: g++ -std=c++17 -I.. test_sensor.cpp -o test_sensor && ./test_sensor

#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstdint>

#include "../sensor.cpp"

using namespace sensor;

static int g_failures = 0;
#define CHECK(expr) do { \
  if (!(expr)) { \
    std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #expr); \
    g_failures++; \
  } \
} while (0)

#define CHECK_NEAR(actual, expected, tol) do { \
  if (std::fabs((actual) - (expected)) > (tol)) { \
    std::printf("FAIL %s:%d  %s = %f, expected ~ %f (tol %f)\n", \
                __FILE__, __LINE__, #actual, \
                (double)(actual), (double)(expected), (double)(tol)); \
    g_failures++; \
  } \
} while (0)

static void resetAll() {
  g_head = g_tail = 0;
  g_ema = 0.0f;
  g_zeroOffset = 0.0f;
  g_sampleCount = 0;
  g_calibrating = false;
  g_calSamplesRemaining = 0;
  g_calAccum = 0.0f;
  g_hostAdc = 0;
  g_hostMillis = 0;
}

// -- adcToCmH2O conversion -----------------------------------------------
// 변환식 sanity 테스트는 sensor_cfg 상수로부터 ADC 값을 동적으로 계산해서
// OUT_LOW_V/HIGH_V 가 변경되어도 테스트가 자동 적응하도록 함.

static uint16_t voltsToAdc(float v) {
  return (uint16_t)(v / sensor_cfg::ADC_VREF * sensor_cfg::ADC_MAX);
}

static void test_zero_voltage_maps_to_zero_cmh2o() {
  CHECK_NEAR(adcToCmH2O(0), 0.0f, 0.01f);
}

static void test_low_threshold_voltage_maps_to_zero() {
  // OUT_LOW_V (sensor's 0 kPa baseline) → 0 cmH2O.
  CHECK_NEAR(adcToCmH2O(voltsToAdc(sensor_cfg::OUT_LOW_V)), 0.0f, 0.1f);
}

static void test_midpoint_voltage_round_trips() {
  // Halfway between LOW_V and HIGH_V → half of full-scale (~25.5 cmH2O).
  const float vMid = (sensor_cfg::OUT_LOW_V + sensor_cfg::OUT_HIGH_V) * 0.5f;
  // ADC 가 3.3V 에서 saturate 하므로 vMid 가 그 위라면 측정 불가 — 그땐 skip.
  if (vMid > sensor_cfg::ADC_VREF) return;
  const float expected =
      sensor_cfg::KPA_FULL * 0.5f * sensor_cfg::KPA_TO_CMH2O;
  CHECK_NEAR(adcToCmH2O(voltsToAdc(vMid)), expected, 0.5f);
}

static void test_below_threshold_clamps_to_zero() {
  // OUT_LOW_V 보다 낮은 전압은 0 cmH2O 로 클램프.
  const uint16_t adcBelow = voltsToAdc(sensor_cfg::OUT_LOW_V) / 2;
  CHECK_NEAR(adcToCmH2O(adcBelow), 0.0f, 0.01f);
}

// -- EMA filter convergence ---------------------------------------------

static void test_ema_converges_to_steady_state() {
  resetAll();
  begin();
  // Drive a known midpoint voltage for 30 samples. With α=0.2 and EMA
  // starting at 0: after 30 ticks the filter is within 1% of input.
  const float vMid = (sensor_cfg::OUT_LOW_V + sensor_cfg::OUT_HIGH_V) * 0.5f;
  if (vMid > sensor_cfg::ADC_VREF) return; // ADC saturates at midpoint — skip.
  const uint16_t adcMid = voltsToAdc(vMid);
  const float expected =
      sensor_cfg::KPA_FULL * 0.5f * sensor_cfg::KPA_TO_CMH2O;
  g_hostAdc = adcMid;
  for (int i = 0; i < 30; i++) {
    onTimerTick();
  }
  CHECK_NEAR(latestFiltered(), expected, 1.0f);
}

static void test_ema_first_sample_partially_weighted() {
  resetAll();
  begin();
  const float vMid = (sensor_cfg::OUT_LOW_V + sensor_cfg::OUT_HIGH_V) * 0.5f;
  if (vMid > sensor_cfg::ADC_VREF) return;
  const uint16_t adcMid = voltsToAdc(vMid);
  const float fullValue =
      sensor_cfg::KPA_FULL * 0.5f * sensor_cfg::KPA_TO_CMH2O;
  g_hostAdc = adcMid;
  onTimerTick();
  // After single tick: EMA = α · input + (1-α) · 0 = α · input
  CHECK_NEAR(latestFiltered(), fullValue * sensor_cfg::EMA_ALPHA, 0.5f);
}

// -- Zero calibration ---------------------------------------------------

static void test_zero_calibration_offsets_subsequent_readings() {
  resetAll();
  begin();
  const float vMid = (sensor_cfg::OUT_LOW_V + sensor_cfg::OUT_HIGH_V) * 0.5f;
  if (vMid > sensor_cfg::ADC_VREF) return;
  const uint16_t adcMid = voltsToAdc(vMid);
  const float midCmH2O =
      sensor_cfg::KPA_FULL * 0.5f * sensor_cfg::KPA_TO_CMH2O;
  // Feed a steady "ambient" reading at midpoint during calibration.
  g_hostAdc = adcMid;
  startZeroCalibration();
  CHECK(isCalibrating());

  // ZERO_CAL_SAMPLES ticks at constant ADC.
  for (uint16_t i = 0; i < sensor_cfg::ZERO_CAL_SAMPLES; i++) {
    onTimerTick();
  }

  CHECK(!isCalibrating());
  CHECK_NEAR(zeroOffset(), midCmH2O, 0.5f);
}

static void test_offset_subtracted_from_raw_after_calibration() {
  resetAll();
  begin();
  const float vMid = (sensor_cfg::OUT_LOW_V + sensor_cfg::OUT_HIGH_V) * 0.5f;
  if (vMid > sensor_cfg::ADC_VREF) return;
  const uint16_t adcMid = voltsToAdc(vMid);
  const float midCmH2O =
      sensor_cfg::KPA_FULL * 0.5f * sensor_cfg::KPA_TO_CMH2O;
  g_hostAdc = adcMid;
  g_zeroOffset = midCmH2O;  // skip cal loop, set directly
  // EMA at 0. One tick → raw = midCmH2O - midCmH2O = 0; EMA stays ≈0.
  onTimerTick();
  CHECK_NEAR(latestFiltered(), 0.0f, 0.1f);
}

// -- Ring buffer ---------------------------------------------------------

static void test_pop_returns_false_when_empty() {
  resetAll();
  begin();
  Sample s;
  CHECK(!pop(s));
}

static void test_pop_returns_samples_in_order() {
  resetAll();
  begin();
  g_hostAdc = 1000;
  onTimerTick();
  g_hostAdc = 2000;
  onTimerTick();
  Sample first;
  CHECK(pop(first));
  CHECK(first.raw > 0); // adc=1000 > threshold → non-zero
  Sample second;
  CHECK(pop(second));
  CHECK(second.raw > first.raw); // adc 2000 → 더 큰 압력
  Sample dummy;
  CHECK(!pop(dummy));
}

static void test_sample_count_increments_each_tick() {
  resetAll();
  begin();
  CHECK(sampleCount() == 0);
  for (int i = 0; i < 10; i++) onTimerTick();
  CHECK(sampleCount() == 10);
}

int main() {
  test_zero_voltage_maps_to_zero_cmh2o();
  test_low_threshold_voltage_maps_to_zero();
  test_midpoint_voltage_round_trips();
  test_below_threshold_clamps_to_zero();
  test_ema_converges_to_steady_state();
  test_ema_first_sample_partially_weighted();
  test_zero_calibration_offsets_subsequent_readings();
  test_offset_subtracted_from_raw_after_calibration();
  test_pop_returns_false_when_empty();
  test_pop_returns_samples_in_order();
  test_sample_count_increments_each_tick();
  if (g_failures == 0) {
    std::printf("ALL TESTS PASSED\n");
    return 0;
  }
  std::printf("%d FAILURE(S)\n", g_failures);
  return 1;
}
