#include "power.h"
#include "config.h"

#ifdef ARDUINO
  #include <Arduino.h>
  #include <nrf_soc.h>
#endif

namespace power {

namespace {

// XIAO BLE: VBAT sense on P0.31 via 1M/510k divider.
// ADC_VREF = 3.3, divider ratio ~= (1.0 + 0.51) / 0.51 = 2.96
constexpr float VBAT_DIVIDER = 2.96f;

// Linear approximation of LiPo discharge curve (rough; refine with real data).
uint8_t voltageToPct(float v) {
  if (v >= 4.15f) return 100;
  if (v <= 3.30f) return 0;
  return (uint8_t)((v - 3.30f) / (4.15f - 3.30f) * 100.0f);
}

}  // namespace

void begin() {
#ifdef ARDUINO
  pinMode(31, INPUT);
#endif
}

uint8_t batteryPct() {
#ifdef ARDUINO
  uint16_t adc = analogRead(31);
  float v = (float)adc * sensor_cfg::ADC_VREF / (float)sensor_cfg::ADC_MAX * VBAT_DIVIDER;
  return voltageToPct(v);
#else
  return 80;
#endif
}

bool isCharging() {
#ifdef ARDUINO
  // XIAO BLE has no dedicated CHG pin exposed; heuristic: VBAT rising above ~4.1V
  // implies USB power. More accurate detection would require PCB modification.
  uint16_t adc = analogRead(31);
  float v = (float)adc * sensor_cfg::ADC_VREF / (float)sensor_cfg::ADC_MAX * VBAT_DIVIDER;
  return v > 4.10f;
#else
  return false;
#endif
}

void enterDeepSleep() {
#ifdef ARDUINO
  // Configure button as wake source, then power off.
  sd_power_system_off();
#endif
}

}  // namespace power
