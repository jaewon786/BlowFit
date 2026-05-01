// PC-buildable unit test for state_machine.
// Compile: g++ -std=c++17 -I.. test_state_machine.cpp -o test_sm && ./test_sm
//
// The state machine only uses stdint.h types from config.h, so it can run
// on a host PC without the Arduino toolchain.

#include <cassert>
#include <cstdio>
#include <cstdint>

#include "../state_machine.cpp"

using namespace state_machine;

static int g_failures = 0;
#define CHECK(expr) do { \
  if (!(expr)) { \
    std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #expr); \
    g_failures++; \
  } \
} while (0)

// Reset the state machine AND the internal g_lastSampleMs clock. Because
// state_machine.cpp uses static globals, we must explicitly sync the clock
// by calling tick(0) before each test dispatches events.
static void reset() {
  state_machine::begin();
  state_machine::tick(0);
}

static void test_boot_to_standby() {
  reset();
  CHECK(state() == DeviceState::Standby);
}

static void test_ble_start_moves_to_prep_or_train() {
  reset();
  dispatch(Event::BleStartSession, /*orifice=*/1);
  // PREP_MS=0 (UX 결정: 준비시간 스킵) 이면 dispatch 시점에 Prep, tick 한번에
  // Train 으로 전환. PREP_MS>0 이면 Prep 유지. 둘 다 허용.
  CHECK(state() == DeviceState::Prep || state() == DeviceState::Train);
  CHECK(metrics().orificeLevel == 1);
}

static void test_prep_transitions_to_train() {
  reset();
  dispatch(Event::BleStartSession, 1);
  // PREP_MS 만큼 (또는 0이면 즉시) 지나면 Train.
  tick(train_cfg::PREP_MS);
  CHECK(state() == DeviceState::Train);
}

static void test_target_hit_after_15s_in_zone() {
  reset();
  dispatch(Event::BleStartSession, 1);
  tick(30000);  // -> Train

  uint32_t t = 30000;
  // Feed 100 Hz samples for 15+ seconds at 25 cmH2O (inside target zone).
  // Zone enters on first sample (t=30010), so the 15000 ms hold threshold
  // is reached at t=45010, i.e. iteration 1501.
  for (int i = 0; i < 1600; i++) {
    t += 10;
    tick(t);
    onPressureSample(25.0f);
  }
  CHECK(metrics().targetHits == 1);
  CHECK(metrics().maxPressure >= 24.9f);
  CHECK(metrics().enduranceMs >= 15000);
}

static void test_hysteresis_keeps_zone_on_brief_dip() {
  reset();
  dispatch(Event::BleStartSession, 1);
  tick(30000);

  uint32_t t = 30000;
  for (int i = 0; i < 200; i++) {
    t += 10; tick(t); onPressureSample(25.0f);
  }
  for (int i = 0; i < 50; i++) {
    t += 10; tick(t); onPressureSample(18.5f); // within hysteresis (20 - 3 = 17)
  }
  for (int i = 0; i < 50; i++) {
    t += 10; tick(t); onPressureSample(25.0f);
  }
  CHECK(metrics().enduranceMs >= 2900);
}

static void test_ble_stop_ends_session() {
  reset();
  dispatch(Event::BleStartSession, 2);
  tick(30000);  // Train
  dispatch(Event::BleStopSession);
  CHECK(state() == DeviceState::Summary);
  CHECK(metrics().orificeLevel == 2);
  CHECK(metrics().sessionId > 0);
}

static void test_three_sets_auto_complete() {
  // 타임라인 (REST_MS=30s 기준):
  //   0~30s    Prep
  //   30~270s  Train1     (4분)
  //   270~300s Rest1      (30초)
  //   300~540s Train2
  //   540~570s Rest2
  //   570~810s Train3
  //   810s+    Summary
  reset();
  dispatch(Event::BleStartSession, 0);
  tick(30000);
  CHECK(state() == DeviceState::Train);
  tick(30000 + 4*60*1000);
  CHECK(state() == DeviceState::Rest);
  tick(30000 + 4*60*1000 + 30*1000);
  CHECK(state() == DeviceState::Train);
  tick(30000 + 2*(4*60*1000) + 30*1000);
  CHECK(state() == DeviceState::Rest);
  tick(30000 + 2*(4*60*1000) + 2*30*1000);
  CHECK(state() == DeviceState::Train);
  tick(30000 + 3*(4*60*1000) + 2*30*1000);
  CHECK(state() == DeviceState::Summary);
}

static void test_set_target_zone_clamps() {
  setTargetZone(-5.0f, 3.0f);
  CHECK(targetLow() == 0.0f);
  CHECK(targetHigh() > targetLow());
  setTargetZone(20.0f, 30.0f);
}

int main() {
  test_boot_to_standby();
  test_ble_start_moves_to_prep_or_train();
  test_prep_transitions_to_train();
  test_target_hit_after_15s_in_zone();
  test_hysteresis_keeps_zone_on_brief_dip();
  test_ble_stop_ends_session();
  test_three_sets_auto_complete();
  test_set_target_zone_clamps();
  if (g_failures == 0) {
    std::printf("ALL TESTS PASSED\n");
    return 0;
  }
  std::printf("%d FAILURE(S)\n", g_failures);
  return 1;
}
