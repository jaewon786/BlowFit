// PC-buildable unit test for feedback vibration state machine.
// Compile: g++ -std=c++17 -I.. test_feedback.cpp -o test_feedback && ./test_feedback
//
// Verifies that pulseVibration() drives a count/onMs/offMs sequence correctly
// across tick() calls. On host the LED/PWM writes are no-ops, but the internal
// state flags (g_vibCount, g_vibOn, g_vibNextSwitchMs) are still observable
// because the anonymous namespace is in this translation unit.

#include <cassert>
#include <cstdio>
#include <cstdint>

#include "../feedback.cpp"

using namespace feedback;

static int g_failures = 0;
#define CHECK(expr) do { \
  if (!(expr)) { \
    std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #expr); \
    g_failures++; \
  } \
} while (0)

// Direct access to anonymous-namespace members works because including the .cpp
// places them in this translation unit's feedback:: namespace.
static void resetVib() {
  g_vibCount = 0;
  g_vibOn = false;
  g_vibNextSwitchMs = 0;
  g_vibOnMs = 0;
  g_vibOffMs = 0;
  g_pattern = Pattern::Idle;
}

static void test_initial_state_is_idle() {
  feedback::begin();
  CHECK(g_vibCount == 0);
  CHECK(g_vibOn == false);
}

static void test_pulse_one_shot_sequence() {
  resetVib();
  pulseVibration(/*count=*/1, /*onMs=*/100, /*offMs=*/0);

  // pulseVibration sets g_vibOn=true, count=1, nextSwitch=0 (immediate trigger).
  CHECK(g_vibCount == 1);
  CHECK(g_vibOn == true);

  // First tick: nextSwitch==0 path schedules off-time at now+onMs.
  tick(0);
  CHECK(g_vibOn == true);
  CHECK(g_vibNextSwitchMs == 100);

  // Half way through: still on.
  tick(50);
  CHECK(g_vibOn == true);

  // At onMs boundary: turn off and decrement count to 0 — sequence done.
  tick(100);
  CHECK(g_vibOn == false);
  CHECK(g_vibCount == 0);
}

static void test_pulse_three_shots_alternates() {
  resetVib();
  pulseVibration(/*count=*/3, /*onMs=*/120, /*offMs=*/100);
  CHECK(g_vibCount == 3);

  // tick(0) initialises switch time at 120.
  tick(0);
  CHECK(g_vibOn == true);
  CHECK(g_vibNextSwitchMs == 120);

  // First on→off transition at t=120: count drops to 2, off-window opens to 220.
  tick(120);
  CHECK(g_vibOn == false);
  CHECK(g_vibCount == 2);
  CHECK(g_vibNextSwitchMs == 220);

  // Off→on at t=220: vibration on again, on-window to 340.
  tick(220);
  CHECK(g_vibOn == true);
  CHECK(g_vibNextSwitchMs == 340);

  // Second on→off at t=340: count=1.
  tick(340);
  CHECK(g_vibOn == false);
  CHECK(g_vibCount == 1);

  // Off→on at t=440.
  tick(440);
  CHECK(g_vibOn == true);

  // Final on→off at t=560: count=0, sequence ends.
  tick(560);
  CHECK(g_vibOn == false);
  CHECK(g_vibCount == 0);
}

static void test_setpattern_zone_entered_triggers_single_pulse() {
  resetVib();
  setPattern(Pattern::ZoneEntered);
  // ZoneEntered → pulseVibration(1, 80, 0)
  CHECK(g_vibCount == 1);
  CHECK(g_vibOnMs == 80);

  tick(0);    // schedule switch at 80
  tick(80);   // turn off, count→0
  CHECK(g_vibCount == 0);
  CHECK(g_vibOn == false);
}

static void test_setpattern_session_complete_three_pulses() {
  resetVib();
  setPattern(Pattern::SessionComplete);
  // SessionComplete → pulseVibration(3, 400, 200)
  CHECK(g_vibCount == 3);
  CHECK(g_vibOnMs == 400);
  CHECK(g_vibOffMs == 200);
}

static void test_idle_pattern_does_not_trigger_vibration() {
  resetVib();
  setPattern(Pattern::Idle);
  CHECK(g_vibCount == 0);
  // tick still works without crashing.
  tick(1000);
  tick(2000);
  CHECK(g_vibCount == 0);
}

int main() {
  test_initial_state_is_idle();
  test_pulse_one_shot_sequence();
  test_pulse_three_shots_alternates();
  test_setpattern_zone_entered_triggers_single_pulse();
  test_setpattern_session_complete_three_pulses();
  test_idle_pattern_does_not_trigger_vibration();
  if (g_failures == 0) {
    std::printf("ALL TESTS PASSED\n");
    return 0;
  }
  std::printf("%d FAILURE(S)\n", g_failures);
  return 1;
}
