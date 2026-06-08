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
  uint16_t      g_connId      = 0;     // 활성 connection handle (force disconnect 용)
  uint32_t      g_lastActivityMs = 0;  // 마지막 GATT activity (write/notify) 시각

  /// 연결/끊김 콜백. 끊기면 자동 광고 재시작.
  class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* s) override {
      g_connected = true;
      g_lastActivityMs = millis();
      // ESP-IDF 의 conn_id 는 BLEServer 내부 — 가장 최근 연결을 추적.
      // ESP32 BLE Arduino 는 단일 연결만 보장하므로 conn id 0 가 일반적.
      g_connId = s->getConnId();
      Serial.printf("[ble] client connected (connId=%u)\n", (unsigned)g_connId);
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
      g_lastActivityMs = millis();  // watchdog refresh
      // ESP32 BLE Arduino 의 getValue() 가 std::string 반환.
      std::string v = c->getValue();
      Serial.printf("[ble] CTRL onWrite: %u bytes\n", (unsigned)v.size());
      if (v.empty()) return;
      const uint8_t op = static_cast<uint8_t>(v[0]);
      Serial.printf("[ble] CTRL opcode=%u\n", (unsigned)op);
      const uint8_t* payload = reinterpret_cast<const uint8_t*>(v.data()) + 1;
      const size_t   plen    = v.size() - 1;

      switch (op) {
        case opcode::START_SESSION: {
          // payload (forward-compat):
          //   [orifice_level: 1B]
          //   [orifice_level: 1B, start_phase: 1B]   ← v4.1, PImax 측정 모드
          //   start_phase: 0=Exhale (기본), 1=Inhale (PImax 측정 시)
          const uint8_t lvl   = (plen >= 1) ? payload[0] : 1;
          const uint8_t phase = (plen >= 2) ? payload[1] : 0;
          Serial.printf("[ble] START_SESSION orifice=%u phase=%u\n",
                        (unsigned)lvl, (unsigned)phase);
          session::startSession(
              phase == 1 ? session::StartPhase::Inhale
                         : session::StartPhase::Exhale);
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
          // payload 길이로 v4.0 legacy / v4.1 clinical 구분:
          //   2 B → legacy : (low: u8, high: u8) — 대칭 절대값 cmH₂O
          //   5 B → v4.1   : (level: u8, pimax×10: u16 LE, mep×10: u16 LE)
          //                  level = IntensityLevel (0/1/2). PImax/MEP 는
          //                  decimal 1자리 보존을 위해 ×10 정수로 전송.
          if (plen == 2) {
            const float lo = static_cast<float>(payload[0]);
            const float hi = static_cast<float>(payload[1]);
            Serial.printf("[ble] SET_TARGET legacy low=%.1f high=%.1f\n", lo, hi);
            session::setTarget(lo, hi);
          } else if (plen >= 5) {
            const uint8_t level = payload[0];
            uint16_t pimax_x10 = 0;
            uint16_t mep_x10   = 0;
            std::memcpy(&pimax_x10, payload + 1, 2);
            std::memcpy(&mep_x10,   payload + 3, 2);
            const float pimax = pimax_x10 / 10.0f;
            const float mep   = mep_x10   / 10.0f;
            Serial.printf("[ble] SET_TARGET v4.1 level=%u PImax=%.1f MEP=%.1f\n",
                          (unsigned)level, pimax, mep);
            session::setPimaxMep(pimax, mep);
            session::setIntensity(static_cast<session::IntensityLevel>(level));
          } else {
            Serial.printf("[ble] SET_TARGET ignored — plen=%u\n", (unsigned)plen);
          }
          break;
        case opcode::SET_DURATION:
          if (plen >= 2) {
            uint16_t sec = 0;
            std::memcpy(&sec, payload, 2);  // uint16 LE seconds
            Serial.printf("[ble] SET_DURATION sec=%u\n", (unsigned)sec);
            session::setTrainDuration(static_cast<uint32_t>(sec) * 1000u);
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

  // Session Summary (Read + Notify, 40B)
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
  // ─────────────────────────────────────────────────────────────
  // BLE 활동 watchdog — Android 가 background 진입 시 연결을 silent
  // drop 하는 경우 (L2CAP_DISCONNECT 패킷 안 보냄) 펌웨어가 stuck
  // 상태가 됨: g_connected=true 이지만 실제론 dead link. onDisconnect
  // 도 안 호출되어서 advertising 재시작 안 됨 → 앱이 reconnect 못 함.
  //
  // 해결: connection 중에 N 초 동안 GATT activity (write/notify) 없으면
  // dead link 로 간주, force disconnect → onDisconnect 호출 → advertising
  // 재시작.
  //
  // Activity = onWrite (control) 호출 + pushSamples 등 notify 호출 시
  // g_lastActivityMs 갱신. Train 중엔 pressure notify 50Hz 라 활성, Standby
  // 에서도 stateNotify 가 1Hz 로 갱신.
  //
  // Threshold 60s — 보수적. App 의 graceful disconnect (lifecycle paused
  // 에서 호출) 가 primary mechanism 이고, watchdog 는 force-quit 등 비정상
  // 종료 시 backstop. Standby idle 60s 미만이면 false positive 없음.
  // (실제론 BLE link supervision 이 5-10s 안에 firing 하는 게 정상이라 60s
  // 면 두 메커니즘 다 실패한 경우만 발동.)
  // ─────────────────────────────────────────────────────────────
  constexpr uint32_t WATCHDOG_TIMEOUT_MS = 60000;
  if (g_connected && g_lastActivityMs > 0) {
    const uint32_t now = millis();
    if (now - g_lastActivityMs > WATCHDOG_TIMEOUT_MS) {
      Serial.printf("[ble] watchdog: no activity for %ums, forcing disconnect\n",
                    (unsigned)(now - g_lastActivityMs));
      // ESP-IDF API 직접 호출 — esp_ble_gap_disconnect.
      // ESP32 BLE Arduino 의 BLEServer::disconnect() 도 가능하지만 conn id
      // 정확성이 떨어짐. esp_ble_gatts_close 가 더 명확.
      if (g_server != nullptr) {
        g_server->disconnect(g_connId);
      }
      // disconnect 이후 onDisconnect callback 이 advertising 재시작 처리.
      // 다음 watchdog 실행에서 false alarm 방지하려면 lastActivity reset.
      g_lastActivityMs = now;
    }
  }
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

  uint8_t buf[40] = {0};
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
  std::memcpy(buf + 32, &s.avgInhale,     4);
  std::memcpy(buf + 36, &s.maxInhale,     4);

  g_summaryChar->setValue(buf, 40);
  if (g_connected) g_summaryChar->notify();
}

uint32_t startEpoch() { return g_startEpoch; }

}  // namespace ble_service
