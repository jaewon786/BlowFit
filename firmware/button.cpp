#include "button.h"
#include "config.h"

#ifdef ARDUINO
  #include <Arduino.h>
#else
  namespace button {
    // Host-test seam: tests flip this to simulate the physical button.
    // Pull-up wiring → false = released (digitalRead returns 1).
    bool g_hostPressed = false;
  }
  static int digitalRead(uint8_t) { return button::g_hostPressed ? 0 : 1; }
  static void pinMode(uint8_t, uint8_t) {}
  #define INPUT_PULLUP 2
#endif

namespace button {

namespace {
constexpr uint16_t DEBOUNCE_MS = 30;

bool g_lastStable = true;       // true = released (pull-up)
bool g_lastRaw = true;
uint32_t g_lastChangeMs = 0;
uint32_t g_pressStartMs = 0;
bool g_pressed = false;
}  // namespace

void begin() {
#ifdef ARDUINO
  pinMode(pins::BUTTON, INPUT_PULLUP);
#endif
}

Press scan(uint32_t nowMs) {
  bool raw = digitalRead(pins::BUTTON) != 0;  // pull-up: 1 = released
  if (raw != g_lastRaw) {
    g_lastRaw = raw;
    g_lastChangeMs = nowMs;
    return Press::None;
  }
  if ((nowMs - g_lastChangeMs) < DEBOUNCE_MS) return Press::None;
  if (raw == g_lastStable) return Press::None;

  g_lastStable = raw;
  if (!raw) {
    // Just pressed
    g_pressed = true;
    g_pressStartMs = nowMs;
    return Press::None;
  } else {
    // Just released
    if (!g_pressed) return Press::None;
    g_pressed = false;
    uint32_t held = nowMs - g_pressStartMs;
    return held >= ui_cfg::LONG_PRESS_MS ? Press::Long : Press::Short;
  }
}

}  // namespace button
