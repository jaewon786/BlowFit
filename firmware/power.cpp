#include "power.h"
#include "config.h"

#ifdef ARDUINO
  #include <Arduino.h>
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
#if defined(ARDUINO) && HAS_BATTERY
  pinMode(31, INPUT);
#endif
}

uint8_t batteryPct() {
#if defined(ARDUINO) && HAS_BATTERY
  uint16_t adc = analogRead(31);
  float v = (float)adc * sensor_cfg::ADC_VREF / (float)sensor_cfg::ADC_MAX * VBAT_DIVIDER;
  return voltageToPct(v);
#else
  // mbed BSP 에서 analogRead(31) (AIN7) 가 hang 하는 이슈로 HAS_BATTERY=0 일 때
  // 안전한 더미값 반환. 실제 VBAT 회로 결선 + mbed SAADC 검증 후 HAS_BATTERY=1.
  return 80;
#endif
}

bool isCharging() {
#if defined(ARDUINO) && HAS_BATTERY
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
  // Adafruit Bluefruit BSP 에서만 SoftDevice (sd_power_system_off) 사용 가능.
  // 현재 mbed BSP 사용 중이고 loop() 에서 호출하는 경로도 없어서 no-op.
  // mbed 스택용 deep sleep 은 추후 별도 작업 (e.g. mbed::deepsleep()).
}

}  // namespace power
