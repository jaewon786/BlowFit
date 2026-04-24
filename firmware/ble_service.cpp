#include "ble_service.h"
#include "ble_uuids.h"
#include "config.h"

#ifdef ARDUINO
  #include <ArduinoBLE.h>
#endif

#include <string.h>

namespace ble_service {

namespace {

#ifdef ARDUINO
BLEService                g_service(uuids::SERVICE);
BLECharacteristic         g_pressure(uuids::PRESSURE_STREAM, BLENotify, 22);
BLECharacteristic         g_control(uuids::SESSION_CONTROL, BLEWrite, 8);
BLECharacteristic         g_summary(uuids::SESSION_SUMMARY, BLERead | BLENotify, 32);
BLECharacteristic         g_state(uuids::DEVICE_STATE, BLERead | BLENotify, 4);
BLECharacteristic         g_history(uuids::HISTORY_LIST, BLERead, 244);

BLEService                g_battSvc("180f");
BLEUnsignedCharCharacteristic g_battLevel("2a19", BLERead | BLENotify);
#endif

uint32_t g_startEpoch = 0;

void onControlWritten(
#ifdef ARDUINO
  BLEDevice, BLECharacteristic& c
#endif
) {
#ifdef ARDUINO
  if (c.valueLength() < 1) return;
  const uint8_t* val = c.value();
  uint8_t op = val[0];
  switch (op) {
    case opcode::START_SESSION: {
      uint8_t level = (c.valueLength() >= 2) ? val[1] : 1;
      state_machine::dispatch(state_machine::Event::BleStartSession, level);
      break;
    }
    case opcode::STOP_SESSION:
      state_machine::dispatch(state_machine::Event::BleStopSession);
      break;
    case opcode::SYNC_TIME:
      if (c.valueLength() >= 5) {
        memcpy(&g_startEpoch, val + 1, 4);
      }
      break;
    case opcode::ZERO_CALIBRATE:
      // Caller (main) observes this via a separate hook; keep BLE thin.
      // Exposed via a weak symbol for simplicity:
      extern void onBleCalibrateRequested();
      onBleCalibrateRequested();
      break;
    case opcode::SET_TARGET:
      if (c.valueLength() >= 3) {
        state_machine::setTargetZone((float)val[1], (float)val[2]);
      }
      break;
    default:
      break;
  }
#else
  (void)0;
#endif
}

}  // namespace

// Weak default — override in main if you need to hook calibration.
__attribute__((weak)) void onBleCalibrateRequested() {}

void begin() {
#ifdef ARDUINO
  if (!BLE.begin()) return;

  BLE.setLocalName(DEVICE_NAME);
  BLE.setDeviceName(DEVICE_NAME);
  BLE.setAdvertisedService(g_service);

  g_service.addCharacteristic(g_pressure);
  g_service.addCharacteristic(g_control);
  g_service.addCharacteristic(g_summary);
  g_service.addCharacteristic(g_state);
  g_service.addCharacteristic(g_history);
  BLE.addService(g_service);

  g_battSvc.addCharacteristic(g_battLevel);
  BLE.addService(g_battSvc);

  g_control.setEventHandler(BLEWritten, onControlWritten);

  BLE.advertise();
#endif
}

void pushSamples(const int16_t samplesX10[], uint8_t count) {
#ifdef ARDUINO
  if (!isConnected() || count == 0) return;
  static uint16_t seq = 0;
  uint8_t n = count > ble_cfg::SAMPLES_PER_PACKET ? ble_cfg::SAMPLES_PER_PACKET : count;
  uint8_t buf[22];
  seq++;
  memcpy(buf, &seq, 2);
  memcpy(buf + 2, samplesX10, n * 2);
  // Zero-pad if short
  for (uint8_t i = n; i < ble_cfg::SAMPLES_PER_PACKET; i++) {
    int16_t zero = 0;
    memcpy(buf + 2 + i * 2, &zero, 2);
  }
  g_pressure.writeValue(buf, 22);
#else
  (void)samplesX10; (void)count;
#endif
}

void pushState(DeviceState s, uint8_t orifice, uint8_t battery, bool charging) {
#ifdef ARDUINO
  uint8_t flags = (isConnected() ? 0x02 : 0x00) | (charging ? 0x01 : 0x00);
  if (battery < 15) flags |= 0x04;
  uint8_t buf[4] = { (uint8_t)s, orifice, battery, flags };
  g_state.writeValue(buf, 4);
  g_battLevel.writeValue(battery);
#else
  (void)s; (void)orifice; (void)battery; (void)charging;
#endif
}

void pushSummary(const state_machine::Metrics& m, uint32_t crc32) {
#ifdef ARDUINO
  uint8_t buf[32] = {0};
  uint32_t dur = m.sessionDurationMs / 1000;
  float maxP = m.maxPressure;
  float avgP = m.avgPressure();
  uint32_t end = m.enduranceMs / 1000;
  uint16_t samples = m.sampleCount > 65535 ? 65535 : (uint16_t)m.sampleCount;
  uint32_t sid = m.sessionId;
  memcpy(buf + 0,  &g_startEpoch, 4);
  memcpy(buf + 4,  &dur, 4);
  memcpy(buf + 8,  &maxP, 4);
  memcpy(buf + 12, &avgP, 4);
  memcpy(buf + 16, &end, 4);
  buf[20] = m.orificeLevel;
  buf[21] = m.targetHits;
  memcpy(buf + 22, &samples, 2);
  memcpy(buf + 24, &crc32, 4);
  memcpy(buf + 28, &sid, 4);
  g_summary.writeValue(buf, 32);
#else
  (void)m; (void)crc32;
#endif
}

void poll() {
#ifdef ARDUINO
  BLE.poll();
#endif
}

bool isConnected() {
#ifdef ARDUINO
  return BLE.connected();
#else
  return false;
#endif
}

uint32_t startEpoch() { return g_startEpoch; }

}  // namespace ble_service
