// BlowFit — main sketch.
// Hardware: Seeed XIAO BLE nRF52840 + XGZP6847A005KPG + ST7735 0.96" TFT
//
// Non-blocking cooperative scheduler: every subsystem exposes a tick()
// function. loop() dispatches work based on millis() deltas. No delay() anywhere.

#include <Arduino.h>
#include "config.h"
#include "ble_uuids.h"
#include "sensor.h"
#include "state_machine.h"
#include "feedback.h"
#include "button.h"
#include "ui_tft.h"
#include "storage.h"
#include "ble_service.h"
#include "power.h"

// ----- Timer for 100 Hz sampling -----
// The XIAO BLE nRF52840 Arduino core exposes "HardwareTimer" or we can use
// nRF52's NRF_TIMER peripherals directly. ArduinoBLE ties up some timers, so
// TimerMillis/TimerTask helpers are preferred. For brevity this scaffold uses
// a simple millis()-based pump at the top of loop(); replace with a timer ISR
// once the sketch is validated.

uint32_t g_nextSampleMs = 0;

void pumpSensor(uint32_t nowMs)
{
  // Replace with NRF_TIMER ISR in production. This works at the ~100 Hz target
  // as long as loop() runtime stays below ~8 ms per iteration.
  constexpr uint32_t interval = 1000 / sensor_cfg::SAMPLE_RATE_HZ;
  if ((int32_t)(nowMs - g_nextSampleMs) >= 0)
  {
    sensor::onTimerTick();
    g_nextSampleMs += interval;
    if ((int32_t)(nowMs - g_nextSampleMs) >= (int32_t)(interval * 3))
    {
      // Dropped multiple ticks — reset to avoid runaway catch-up.
      g_nextSampleMs = nowMs + interval;
    }
  }
}

// ----- Session sample buffering for BLE stream -----
int16_t g_blePacketBuf[ble_cfg::SAMPLES_PER_PACKET];
uint8_t g_blePacketIdx = 0;
uint32_t g_nextNotifyMs = 0;
uint32_t g_nextRenderMs = 0;
uint32_t g_nextButtonMs = 0;
uint32_t g_nextBattMs = 0;
uint32_t g_nextStateNotifyMs = 0;
uint8_t g_cachedBatteryPct = 80;

// ----- State machine callbacks -----
void onStateChange(DeviceState, DeviceState next)
{
  ui_tft::invalidate();
  switch (next)
  {
  case DeviceState::Prep:
  case DeviceState::Train:
    feedback::setPattern(feedback::Pattern::TrainActive);
    break;
  case DeviceState::Standby:
    feedback::setPattern(feedback::Pattern::Idle);
    break;
  default:
    break;
  }
}

void onZoneChange(bool entered)
{
  if (entered)
    feedback::setPattern(feedback::Pattern::ZoneEntered);
}

void onTargetHold()
{
  feedback::setPattern(feedback::Pattern::HoldAchieved);
}

void onSessionEnd(const state_machine::Metrics &m)
{
  feedback::setPattern(feedback::Pattern::SessionComplete);
  storage::saveSession(m);
  ble_service::pushSummary(m, 0); // TODO: real CRC32 over stored waveform
}

// Called from ble_service on opcode 0x04.
void onBleCalibrateRequested()
{
  sensor::startZeroCalibration();
}

void setup()
{
  ble_service::begin();
  Serial.begin(115200);
  sensor::begin();
  power::begin();
  feedback::begin();
  button::begin();
  ui_tft::begin();
  storage::begin();

  // Load persisted target zone & offset.
  float zero, lo, hi;
  if (storage::loadConfig(zero, lo, hi))
  {
    state_machine::setTargetZone(lo, hi);
  }
  state_machine::begin();
  state_machine::onStateChange(onStateChange);
  state_machine::onZoneChange(onZoneChange);
  state_machine::onTargetHold(onTargetHold);
  state_machine::onSessionEnd(onSessionEnd);

  sensor::startZeroCalibration();
  feedback::setPattern(feedback::Pattern::Idle);
  g_nextSampleMs = millis();
}

void loop()
{
  ble_service::poll();
  uint32_t now = millis();

  pumpSensor(now);
  feedback::tick(now);

  // Drain sensor samples — 한 번 loop() 에서 너무 많이 처리하면 BLE.poll() 호출이
  // 느려져서 connection 단계에서 timeout. 예산 제한 + 중간 yield.
  sensor::Sample s;
  int drainBudget = 8;
  while (drainBudget-- > 0 && sensor::pop(s))
  {
    state_machine::tick(s.tMillis);
    state_machine::onPressureSample(s.filtered);

    if (state_machine::state() == DeviceState::Train && g_blePacketIdx < ble_cfg::SAMPLES_PER_PACKET)
    {
      int32_t v = (int32_t)(s.filtered * 10.0f);
      if (v < -32768) v = -32768;
      if (v > 32767) v = 32767;
      g_blePacketBuf[g_blePacketIdx++] = (int16_t)v;
    }
  }
  ble_service::poll();

  // BLE pressure notify every 50ms
  if ((int32_t)(now - g_nextNotifyMs) >= 0)
  {
    g_nextNotifyMs = now + ble_cfg::NOTIFY_INTERVAL_MS;
    if (g_blePacketIdx > 0)
    {
      ble_service::pushSamples(g_blePacketBuf, g_blePacketIdx);
      g_blePacketIdx = 0;
    }
  }

  // UI render (HAS_TFT=0 이면 no-op)
  if ((int32_t)(now - g_nextRenderMs) >= 0)
  {
    g_nextRenderMs = now + ui_cfg::RENDER_INTERVAL_MS;
    ui_tft::render(state_machine::state(), sensor::latestFiltered(),
                   state_machine::metrics(), now, g_cachedBatteryPct);
  }

  // Button scan
  if ((int32_t)(now - g_nextButtonMs) >= 0)
  {
    g_nextButtonMs = now + ui_cfg::BUTTON_SCAN_MS;
    button::Press p = button::scan(now);
    if (p == button::Press::Short)
      state_machine::dispatch(state_machine::Event::ButtonShort);
    else if (p == button::Press::Long)
      state_machine::dispatch(state_machine::Event::ButtonLong);
  }

  // Battery poll (HAS_BATTERY=0 이면 batteryPct/isCharging 모두 더미값)
  if ((int32_t)(now - g_nextBattMs) >= 0)
  {
    g_nextBattMs = now + ui_cfg::BATTERY_POLL_MS;
    g_cachedBatteryPct = power::batteryPct();
    if (g_cachedBatteryPct < 15)
      feedback::setPattern(feedback::Pattern::BatteryLow);
  }

  // State notify (1s)
  if ((int32_t)(now - g_nextStateNotifyMs) >= 0)
  {
    g_nextStateNotifyMs = now + 1000;
    ble_service::pushState(state_machine::state(),
                           state_machine::metrics().orificeLevel,
                           g_cachedBatteryPct,
                           power::isCharging());
  }
}
