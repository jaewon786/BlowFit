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

static void test_zero_voltage_maps_to_zero_cmh2o() {
  CHECK_NEAR(adcToCmH2O(0), 0.0f, 0.01f);
}

static void test_low_threshold_voltage_maps_to_zero() {
  // 0.2 V (sensor's "0 kPa" floor) -> 0 cmH2O.
  // adc = 0.2/3.3 * 4095 ≈ 248
  CHECK_NEAR(adcToCmH2O(248), 0.0f, 0.1f);
}

static void test_documented_midpoint_maps_to_25cmh2o() {
  // Doc 5.1 example: ADC 1.45 V -> 25.49 cmH2O.
  // adc = 1.45/3.3 * 4095 ≈ 1799
  CHECK_NEAR(adcToCmH2O(1799), 25.5f, 0.5f);
}

static void test_full_range_maps_to_51cmh2o() {
  // 2.7 V (sensor's "5 kPa" full scale) -> 51 cmH2O.
  // adc = 2.7/3.3 * 4095 ≈ 3351
  CHECK_NEAR(adcToCmH2O(3351), 50.99f, 0.5f);
}

static void test_below_threshold_clamps_to_zero() {
  // adc=100 → ~0.08V which is below OUT_LOW_V=0.2. Should clamp at 0.
  CHECK_NEAR(adcToCmH2O(100), 0.0f, 0.01f);
}

// -- EMA filter convergence ---------------------------------------------

static void test_ema_converges_to_steady_state() {
  resetAll();
  begin();
  // Drive a constant 1.45 V (≈25.5 cmH2O) for 30 samples.
  // With α=0.2 and EMA starting at 0: after 30 ticks the filter should be
  // within 1% of the input (1 - (1-α)^30 ≈ 0.9988).
  g_hostAdc = 1799;
  for (int i = 0; i < 30; i++) {
    onTimerTick();
  }
  CHECK_NEAR(latestFiltered(), 25.5f, 1.0f);
}

static void test_ema_first_sample_partially_weighted() {
  resetAll();
  begin();
  g_hostAdc = 1799;
  onTimerTick();
  // After single tick: EMA = α·25.5 + (1-α)·0 ≈ 5.1
  CHECK_NEAR(latestFiltered(), 25.5f * 0.2f, 0.5f);
}

// -- Zero calibration ---------------------------------------------------

static void test_zero_calibration_offsets_subsequent_readings() {
  resetAll();
  begin();
  // Feed a steady "ambient" reading (≈25.5 cmH2O) during calibration.
  g_hostAdc = 1799;
  startZeroCalibration();
  CHECK(isCalibrating());

  // ZERO_CAL_SAMPLES = 500 ticks at constant ADC.
  for (uint16_t i = 0; i < sensor_cfg::ZERO_CAL_SAMPLES; i++) {
    onTimerTick();
  }

  CHECK(!isCalibrating());
  // Offset should equal the calibration input pressure (~25.5 cmH2O).
  CHECK_NEAR(zeroOffset(), 25.5f, 0.5f);

  // After calibration, subsequent raw readings = adcCmH2O - offset.
  // At same ADC, raw should now be near 0.
  resetAll(); // resets g_ema/queue but not the offset → preserve manually
  // Actually we need to re-run with offset preserved. Use a fresh test below.
}

static void test_offset_subtracted_from_raw_after_calibration() {
  resetAll();
  begin();
  g_hostAdc = 1799;  // ~25.5 cmH2O
  // Manually set offset (skip calibration loop for speed).
  g_zeroOffset = 25.5f;
  // EMA remains 0 from begin(). One tick → raw = 25.5 - 25.5 = 0; EMA stays ≈0.
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
  test_documented_midpoint_maps_to_25cmh2o();
  test_full_range_maps_to_51cmh2o();
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
