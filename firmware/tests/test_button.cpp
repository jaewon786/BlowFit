// PC-buildable unit test for button debounce + short/long detection.
// Compile: g++ -std=c++17 -I.. test_button.cpp -o test_button && ./test_button
//
// On host the digitalRead() stub reads from button::g_hostPressed (a test seam
// added in button.cpp), so we drive the physical signal by toggling that flag.

#include <cassert>
#include <cstdio>
#include <cstdint>

#include "../button.cpp"

using namespace button;

static int g_failures = 0;
#define CHECK(expr) do { \
  if (!(expr)) { \
    std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #expr); \
    g_failures++; \
  } \
} while (0)

// State variables live in feedback's anonymous namespace; same TU here.
static void resetButton() {
  g_lastStable = true;
  g_lastRaw = true;
  g_lastChangeMs = 0;
  g_pressStartMs = 0;
  g_pressed = false;
  g_hostPressed = false;
}

// Drives scan() repeatedly across [start, end) at 10 ms intervals, returning
// the first non-None result observed (or None if nothing fired).
static Press tickUntilEvent(uint32_t start, uint32_t end) {
  Press fired = Press::None;
  for (uint32_t t = start; t < end; t += 10) {
    Press p = scan(t);
    if (p != Press::None && fired == Press::None) fired = p;
  }
  return fired;
}

static void test_idle_returns_none() {
  resetButton();
  for (uint32_t t = 0; t < 500; t += 10) {
    CHECK(scan(t) == Press::None);
  }
}

static void test_short_press_emits_short() {
  resetButton();

  // Press at t=100, release at t=400 (held 300 ms — well below LONG_PRESS_MS=2000).
  scan(0);             // baseline released
  g_hostPressed = true;
  // Drive past debounce window so the press is registered.
  tickUntilEvent(100, 200);
  g_hostPressed = false;
  Press result = tickUntilEvent(400, 500);
  CHECK(result == Press::Short);
}

static void test_long_press_emits_long() {
  resetButton();

  scan(0);
  g_hostPressed = true;
  tickUntilEvent(100, 200);  // debounce + register press
  // Hold for >= LONG_PRESS_MS (2000 ms): release at t = 100 + 2100 = 2200
  g_hostPressed = false;
  Press result = tickUntilEvent(2300, 2400);
  CHECK(result == Press::Long);
}

static void test_chatter_within_debounce_is_ignored() {
  resetButton();

  // Bounce the line many times within the 30 ms debounce window. The state
  // never settles long enough to register a press.
  scan(0);
  for (uint32_t t = 0; t < 25; t += 5) {
    g_hostPressed = !g_hostPressed;
    Press p = scan(t);
    CHECK(p == Press::None);
  }
  // Force back to released and let it settle.
  g_hostPressed = false;
  Press settled = tickUntilEvent(100, 300);
  CHECK(settled == Press::None);
}

static void test_press_at_exactly_long_threshold_is_long() {
  resetButton();

  scan(0);
  g_hostPressed = true;
  // Register the press around t=100.
  tickUntilEvent(100, 200);
  // Release exactly at LONG_PRESS_MS after the registered press start.
  // Press registered at t=100 (first stable scan after debounce). Long if
  // held >= 2000ms, so release at t=2100 with the 10ms grid.
  g_hostPressed = false;
  Press result = tickUntilEvent(2100, 2200);
  CHECK(result == Press::Long);
}

int main() {
  test_idle_returns_none();
  test_short_press_emits_short();
  test_long_press_emits_long();
  test_chatter_within_debounce_is_ignored();
  test_press_at_exactly_long_threshold_is_long();
  if (g_failures == 0) {
    std::printf("ALL TESTS PASSED\n");
    return 0;
  }
  std::printf("%d FAILURE(S)\n", g_failures);
  return 1;
}
