#include "feedback.h"
#include "config.h"

#ifdef ARDUINO
  #include <Arduino.h>
#else
  static void pinMode(uint8_t, uint8_t) {}
  static void digitalWrite(uint8_t, uint8_t) {}
  static void analogWrite(uint8_t, int) {}
  #define OUTPUT 1
  #define HIGH 1
  #define LOW 0
#endif

namespace feedback {

namespace {

Pattern g_pattern = Pattern::Idle;

// Vibration queue: count remaining, current on/off window, current phase end
uint16_t g_vibCount = 0;
uint16_t g_vibOnMs = 0;
uint16_t g_vibOffMs = 0;
bool g_vibOn = false;
uint32_t g_vibNextSwitchMs = 0;

// LED heartbeat
uint32_t g_ledNextMs = 0;
bool g_ledState = false;

void ledSet(bool on) {
#ifdef ARDUINO
  digitalWrite(pins::LED, on ? HIGH : LOW);
#endif
  g_ledState = on;
}

void vibSet(bool on) {
#ifdef ARDUINO
  analogWrite(pins::VIBRATION, on ? 200 : 0);
#endif
  g_vibOn = on;
}

void startVib(uint16_t count, uint16_t onMs, uint16_t offMs, uint32_t nowMs) {
  g_vibCount = count;
  g_vibOnMs = onMs;
  g_vibOffMs = offMs;
  vibSet(true);
  g_vibNextSwitchMs = nowMs + onMs;
}

}  // namespace

void begin() {
#ifdef ARDUINO
  pinMode(pins::LED, OUTPUT);
  pinMode(pins::VIBRATION, OUTPUT);
#endif
  ledSet(false);
  vibSet(false);
}

void setPattern(Pattern p) {
  g_pattern = p;
  switch (p) {
    case Pattern::TrainActive:     ledSet(true);  break;
    case Pattern::Charging:        ledSet(false); break;
    case Pattern::ZoneEntered:     pulseVibration(1, 80, 0); break;
    case Pattern::HoldAchieved:    pulseVibration(2, 120, 100); break;
    case Pattern::SessionComplete: pulseVibration(3, 400, 200); break;
    case Pattern::CalibrateDone:   pulseVibration(2, 100, 80); break;
    default: break;
  }
}

void pulseVibration(uint16_t count, uint16_t onMs, uint16_t offMs) {
  // `nowMs` is picked up by tick(); start immediately by zeroing the switch time
  g_vibCount = count;
  g_vibOnMs = onMs;
  g_vibOffMs = offMs;
  vibSet(true);
  g_vibNextSwitchMs = 0;  // triggers immediate switch logic
}

void tick(uint32_t nowMs) {
  // LED patterns
  switch (g_pattern) {
    case Pattern::Idle:
      if (nowMs >= g_ledNextMs) {
        ledSet(!g_ledState);
        g_ledNextMs = nowMs + (g_ledState ? 80 : 1920);  // brief flash every 2s
      }
      break;
    case Pattern::BatteryLow:
      if (nowMs >= g_ledNextMs) {
        ledSet(!g_ledState);
        g_ledNextMs = nowMs + 150;
      }
      break;
    default:
      break;
  }

  // Vibration state machine
  if (g_vibCount > 0) {
    if (g_vibNextSwitchMs == 0) {
      g_vibNextSwitchMs = nowMs + g_vibOnMs;
      vibSet(true);
    }
    if (nowMs >= g_vibNextSwitchMs) {
      if (g_vibOn) {
        vibSet(false);
        if (--g_vibCount == 0) return;
        g_vibNextSwitchMs = nowMs + g_vibOffMs;
      } else {
        vibSet(true);
        g_vibNextSwitchMs = nowMs + g_vibOnMs;
      }
    }
  }
}

}  // namespace feedback
