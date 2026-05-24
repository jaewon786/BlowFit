// BLE GATT 서비스 구현 — ESP32 BLE Arduino 기반.

#include "ble_service.h"
#include "ble_uuids.h"
#include "config.h"
#include "session.h"
#include "sensor.h"

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <BLESecurity.h>

#include <cstring>

namespace ble_service {

namespace {

  BLEServer*         g_server        = nullptr;
  BLECharacteristic* g_pressureChar  = nullptr;
  BLECharacteristic* g_controlChar   = nullptr;
  BLECharacteristic* g_stateChar     = nullptr;
  BLECharacteristic* g_summaryChar   = nullptr;

  volatile bool g_connected   = false;
  uint32_t      g_startEpoch  = 0;
  uint16_t      g_seq         = 0;     // Pressure Stream sequence (wrap 65535)

  /// 연결/끊김 콜백. 끊기면 자동 광고 재시작.
  class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* /*s*/) override {
      g_connected = true;
      Serial.println("[ble] client connected");
    }
    void onDisconnect(BLEServer* /*s*/) override {
      g_connected = false;
      Serial.println("[ble] client disconnected, restarting advertising");
      BLEDevice::startAdvertising();
    }
  };

  /// SESSION_CONTROL 쓰기 콜백 — 앱이 보낸 opcode 처리.
  class ControlCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* c) override {
      // ESP32 BLE Arduino 의 getValue() 가 std::string 반환.
      std::string v = c->getValue();
      if (v.empty()) return;
      const uint8_t op = static_cast<uint8_t>(v[0]);
      const uint8_t* payload = reinterpret_cast<const uint8_t*>(v.data()) + 1;
      const size_t   plen    = v.size() - 1;

      switch (op) {
        case opcode::START_SESSION: {
          const uint8_t lvl = (plen >= 1) ? payload[0] : 1;
          Serial.printf("[ble] START_SESSION (orifice=%u)\n", (unsigned)lvl);
          session::startSession();
          // TODO: orifice level 적용 (M9: NVS 저장 + 화면 표시)
          break;
        }
        case opcode::STOP_SESSION:
          Serial.println("[ble] STOP_SESSION");
          session::stopSession();
          break;
        case opcode::SYNC_TIME:
          if (plen >= 4) {
            std::memcpy(&g_startEpoch, payload, 4);
            Serial.printf("[ble] SYNC_TIME epoch=%u\n", (unsigned)g_startEpoch);
          }
          break;
        case opcode::ZERO_CALIBRATE:
          Serial.println("[ble] ZERO_CALIBRATE — running");
          sensor::recalibrateZero();
          Serial.printf("[ble] ZERO_CALIBRATE done, offset=%.2f cmH2O\n",
                        sensor::zeroOffset());
          break;
        case opcode::SET_TARGET:
          if (plen >= 2) {
            const float lo = static_cast<float>(payload[0]);
            const float hi = static_cast<float>(payload[1]);
            Serial.printf("[ble] SET_TARGET low=%.1f high=%.1f\n", lo, hi);
            session::setTarget(lo, hi);
          }
          break;
        default:
          Serial.printf("[ble] unknown opcode 0x%02X\n", (unsigned)op);
          break;
      }
    }
  };

}  // anonymous namespace

void begin() {
  Serial.println("[ble] init...");
  BLEDevice::init(BLE_DEVICE_NAME);
  BLEDevice::setMTU(ble::MTU_TARGET);

  // ----- BLE 보안 + 본딩 (Bonding) -----
  // 첫 페어링 시 OS 가 LTK (Long-Term Key) + IRK (Identity Resolving Key) 교환
  // → 양쪽 영구 저장 → 이후 OS 가 디바이스 광고를 "내 페어 디바이스" 로 자동
  // 인식 → 앱이 background 에 있어도 OS 가 자동 reconnect 시도.
  //
  // 페어링 모드: Just Works (passkey/PIN 없음). 의료 디바이스에는 충분.
  BLESecurity* pSecurity = new BLESecurity();
  pSecurity->setAuthenticationMode(ESP_LE_AUTH_REQ_SC_BOND);  // Secure Connections + Bonding
  pSecurity->setCapability(ESP_IO_CAP_NONE);                  // Just Works
  pSecurity->setInitEncryptionKey(ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK);
  pSecurity->setRespEncryptionKey(ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK);

  g_server = BLEDevice::createServer();
  g_server->setCallbacks(new ServerCallbacks());

  // ----- BlowFit Training Service -----
  BLEService* svc = g_server->createService(uuids::SERVICE);

  // Pressure Stream (Notify, 22B)
  g_pressureChar = svc->createCharacteristic(
      uuids::PRESSURE_STREAM,
      BLECharacteristic::PROPERTY_NOTIFY);
  g_pressureChar->addDescriptor(new BLE2902());

  // Session Control (Write, 1-6B)
  g_controlChar = svc->createCharacteristic(
      uuids::SESSION_CONTROL,
      BLECharacteristic::PROPERTY_WRITE);
  g_controlChar->setCallbacks(new ControlCallbacks());

  // Device State (Read + Notify, 4B)
  g_stateChar = svc->createCharacteristic(
      uuids::DEVICE_STATE,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  g_stateChar->addDescriptor(new BLE2902());

  // Session Summary (Read + Notify, 32B)
  g_summaryChar = svc->createCharacteristic(
      uuids::SESSION_SUMMARY,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  g_summaryChar->addDescriptor(new BLE2902());

  svc->start();

  // ----- 광고 시작 -----
  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(uuids::SERVICE);
  adv->setScanResponse(true);
  // iOS 호환을 위해 interval 적당히 (Apple 권장 30~50ms).
  adv->setMinPreferred(0x06);   // 7.5ms
  adv->setMinPreferred(0x12);   // 22.5ms
  BLEDevice::startAdvertising();

  Serial.printf("[ble] advertising as '%s' (service %s)\n",
                BLE_DEVICE_NAME, uuids::SERVICE);
}

void poll() {
  // ESP32 BLE Arduino 는 별도 task 로 동작. 명시적 poll 불필요.
}

bool isConnected() { return g_connected; }

void pushSamples(const int16_t samplesX10[], uint8_t count) {
  if (!g_connected || !g_pressureChar) return;
  if (count == 0) return;

  uint8_t buf[22] = {0};
  const uint8_t n = (count > 10) ? 10 : count;
  ++g_seq;
  std::memcpy(buf,     &g_seq, 2);
  std::memcpy(buf + 2, samplesX10, n * 2);
  // 부족하면 zero-pad (이미 buf 가 0 초기화).

  g_pressureChar->setValue(buf, 22);
  g_pressureChar->notify();
}

void pushState(uint8_t state_id, uint8_t orifice, uint8_t battery, bool charging) {
  if (!g_stateChar) return;
  uint8_t flags = 0;
  if (charging)        flags |= 0x01;
  if (g_connected)     flags |= 0x02;
  if (battery <= 15)   flags |= 0x04;

  uint8_t buf[4] = { state_id, orifice, battery, flags };
  g_stateChar->setValue(buf, 4);
  if (g_connected) g_stateChar->notify();
}

void pushSummary(const SummaryFields& s) {
  if (!g_summaryChar) return;

  uint8_t buf[32] = {0};
  std::memcpy(buf + 0,  &s.startEpoch,    4);
  std::memcpy(buf + 4,  &s.durationSec,   4);
  std::memcpy(buf + 8,  &s.maxPressure,   4);
  std::memcpy(buf + 12, &s.avgPressure,   4);
  std::memcpy(buf + 16, &s.enduranceSec,  4);
  buf[20] = s.orificeLevel;
  buf[21] = s.targetHits;
  std::memcpy(buf + 22, &s.sampleCount,   2);
  std::memcpy(buf + 24, &s.crc32,         4);
  std::memcpy(buf + 28, &s.sessionId,     4);

  g_summaryChar->setValue(buf, 32);
  if (g_connected) g_summaryChar->notify();
}

uint32_t startEpoch() { return g_startEpoch; }

}  // namespace ble_service
