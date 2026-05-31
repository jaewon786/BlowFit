// BlowFit v4.0 펌웨어 — M7 milestone (session state machine).
//
// 진행:
//   - session.{h,cpp} 가 Boot/Standby/Prep/Train/Rest/Summary 사이클 관리
//   - main.cpp 가 state 변화 감지 → 해당 screen 호출
//   - GPIO0 (BOOT 버튼) 짧게 누름 → session::startSession()
//   - GPIO14 (사용자 버튼) 짧게 누름 → session::stopSession()
//   - 압력값/카운트다운/진행률 매 tick 화면 갱신

#include <Arduino.h>
#include <Wire.h>
#include <lvgl.h>

#include "config.h"
#include "sensor.h"
#include "session.h"
#include "ble_service.h"
#include "power.h"
#include "display/lvgl_port.h"
#include "display/theme.h"
#include "display/screens/screen_boot.h"
#include "display/screens/screen_pairwait.h"
#include "display/screens/screen_pairconnected.h"
#include "display/screens/screen_standby.h"
#include "display/screens/screen_training.h"
#include "display/screens/screen_rest.h"
#include "display/screens/screen_summary.h"

// ----- 시리얼 + 디스플레이 전원 + I²C 부트 -----
static void bootHardware() {
#if HAS_DISPLAY
  pinMode(pins::TFT_POWER_ON, OUTPUT);
  digitalWrite(pins::TFT_POWER_ON, HIGH);
  delay(50);
#endif
  // I²C bus init — sensor.cpp 의 MCP3221 read 가 Wire 사용.
  Wire.begin(pins::I2C_SDA, pins::I2C_SCL, sensor::I2C_FREQ_HZ);
  Serial.printf("[i2c] init SDA=GPIO%u SCL=GPIO%u @ %lu Hz\n",
                (unsigned)pins::I2C_SDA, (unsigned)pins::I2C_SCL,
                (unsigned long)sensor::I2C_FREQ_HZ);
}

// ----- 버튼 처리 (debounce + edge detect) -----
namespace btn {
  constexpr uint32_t DEBOUNCE_MS = 30;

  struct Button {
    uint8_t pin;
    bool last_raw = HIGH;       // INPUT_PULLUP 기본 HIGH
    bool stable = HIGH;
    uint32_t last_change_ms = 0;
    explicit Button(uint8_t p) : pin(p) {}
  };

  Button g_boot(pins::BUTTON_BOOT);
  Button g_user(pins::BUTTON_USER);

  /// 한 frame 동안 falling edge (HIGH → LOW = 눌림) 발생 여부.
  bool pollFallingEdge(Button& b, uint32_t now) {
    const bool raw = digitalRead(b.pin);
    if (raw != b.last_raw) {
      b.last_raw = raw;
      b.last_change_ms = now;
    }
    if (now - b.last_change_ms >= DEBOUNCE_MS && b.stable != raw) {
      const bool pressed_now = (raw == LOW);
      b.stable = raw;
      return pressed_now;
    }
    return false;
  }
}  // namespace btn

// ----- 화면 전환 — session state 변화 시 호출 -----
static void switchScreenFor(session::State s) {
  switch (s) {
    case session::State::Standby:
      screens::standby_show();
      screens::standby_set_connected(false);
      // 실제 VBAT ADC 측정은 미구현 (M9/M11) — 타 화면과 동일하게 placeholder 76%.
      screens::standby_set_battery(76);
      break;
    case session::State::Prep:
    case session::State::Train: {
      // Prep 도 training 화면에 카운트다운 노출 (간결).
      screens::training_show();
      screens::training_set_target(session::targetLow(), session::targetHigh());
      const auto turn = session::currentTurn();
      screens::TrainingPhase ui_phase;
      switch (turn) {
        case session::Turn::Inhale:     ui_phase = screens::TrainingPhase::Inhale; break;
        case session::Turn::ExhaleRest:
        case session::Turn::InhaleRest: ui_phase = screens::TrainingPhase::Rest; break;
        // None(=Prep 등) / Exhale / default → 호기(흰 배경). Prep 이 휴식(검정)
        // 으로 평가돼 검은 화면이 깜빡이던 문제 방지.
        case session::Turn::Exhale:
        case session::Turn::None:
        default:                        ui_phase = screens::TrainingPhase::Exhale; break;
      }
      screens::training_set_phase(ui_phase, session::remainingSec());
      screens::training_set_progress(session::progressPercent(),
                                     session::currentSet(),
                                     session::stats().total_sets > 0
                                         ? session::stats().total_sets
                                         : 3);
      break;
    }
    case session::State::Rest:
      screens::rest_show();
      screens::rest_set_remaining(session::remainingSec());
      screens::rest_set_next_set(session::currentSet() + 1, 3);
      break;
    case session::State::Summary: {
      const auto& st = session::stats();
      screens::SummaryData d {
        .avg_pressure   = st.avg_pressure,
        .max_pressure   = st.max_pressure,
        .duration_sec   = st.duration_sec,
        .hit_percent    = st.hit_percent,
        .completed_sets = st.completed_sets,
        .total_sets     = st.total_sets,
      };
      screens::summary_show(d);
      break;
    }
    default:
      break;
  }
}

// ----- Setup -----
void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println();
  Serial.println("=========================================");
  Serial.println("BlowFit v4.0 - ESP32-S3 / T-Display S3");
  Serial.println("Build: " __DATE__ " " __TIME__);
  Serial.println("M7: session state machine, M11: power mgmt");
  Serial.println("=========================================");

  bootHardware();
  power::begin();   // wakeup reason 출력 + PWR_LED ON

#if HAS_LVGL
  lvgl_port::begin();
  // 부팅 화면 표시 + 첫 LVGL refresh (즉시 그려지도록).
  screens::boot_show();
  lvgl_port::tick();
  // calibrateZero 의 매 sample 사이에 LVGL refresh 가 호출되도록 hook 등록.
  // → 2초 보정 동안 spinner 계속 회전 (총 부팅 ≈ 2초).
  sensor::setTickHook([]() { lvgl_port::tick(); });
#endif

  // 영점 보정 — 2초 (200 sample × 10ms). hook 덕에 spinner 회전 유지.
  Serial.println("Showing boot screen + calibrating zero (2s)...");
  sensor::calibrateZero();
  Serial.printf("Zero offset = %.2f cmH2O\n", sensor::zeroOffset());

  pinMode(pins::HAPTIC_EN, OUTPUT);  // DRV2605L EN/trigger (실제 효과는 I²C)
  pinMode(pins::LED_STATUS, OUTPUT);
  pinMode(pins::BUTTON_BOOT, INPUT_PULLUP);
  pinMode(pins::BUTTON_USER, INPUT_PULLUP);

  // Session state machine 시작.
  session::begin();
  // 영점 보정 끝났으므로 자연스럽게 Standby 로 진입.

#if HAS_BLE
  // BLE GATT — 광고 시작. 앱이 prefix 'BlowFit' 로 스캔하면 발견됨.
  ble_service::begin();

  // 부팅 흐름: boot 화면 → 페어링 대기 화면 (30초 timeout) → 연결되면 연결완료
  // 화면 → Standby. 30초 안에 앱이 연결 안 해도 Standby 진입 — 디바이스 단독
  // 사용 가능. 백그라운드 BLE 광고는 계속 → 앱이 나중에 켜져도 어느 시점에서든
  // 자동 연결 (standby 화면의 BT dot 가 자동 갱신).
  Serial.println("Waiting for BLE pairing (30s timeout)...");
  screens::pairwait_show();
  const uint32_t pair_until = millis() + 30000;
  while (!ble_service::isConnected() && (int32_t)(pair_until - millis()) > 0) {
    lvgl_port::tick();
    delay(50);
    if (digitalRead(pins::BUTTON_BOOT) == LOW) {
      Serial.println("[ble] pairing skipped by BOOT button");
      break;
    }
  }

  if (ble_service::isConnected()) {
    Serial.println("[ble] paired — showing connected screen (2s)");
    screens::pairconnected_show();
    const uint32_t until = millis() + 2000;
    while ((int32_t)(until - millis()) > 0) {
      lvgl_port::tick();
      delay(20);
    }
  } else {
    Serial.println("[ble] pairing timeout — entering Standby (advertising continues)");
  }
#endif

  Serial.println("Setup complete. Press BOOT button to start session.");
}

// ----- Loop -----
void loop() {
  const uint32_t now = millis();

#if HAS_BLE
  // BLE watchdog — Android 가 graceful disconnect 없이 연결을 silent drop
  // 했을 때 stale "connected" state 를 force-disconnect → advertising 재시작.
  ble_service::poll();
#endif

  // 100Hz 압력 샘플링 + BLE Pressure Stream 누적.
  static uint32_t lastSampleMs = 0;
  static int16_t  ble_sample_buf[10];
  static uint8_t  ble_sample_idx = 0;
  if (now - lastSampleMs >= 10) {
    lastSampleMs = now;
    sensor::tick();

#if HAS_BLE
    // cmH2O × 10 의 int16 으로 변환 후 buffer 에 누적. 10개 모이면 notify.
    const float v = sensor::currentCmH2O();
    int32_t s32 = (int32_t)lroundf(v * 10.0f);
    if (s32 >  32767) s32 =  32767;
    if (s32 < -32768) s32 = -32768;
    ble_sample_buf[ble_sample_idx++] = (int16_t)s32;
    if (ble_sample_idx >= 10) {
      ble_sample_idx = 0;
      ble_service::pushSamples(ble_sample_buf, 10);
    }
#endif
  }

  // 전원 버튼 처리 (long-press = deep sleep). settle 후에만 활성.
  static const uint32_t BTN_SETTLE_MS = 1500;
  if (now >= BTN_SETTLE_MS) {
    power::tick(now);
  }

  // 버튼 입력 — 부팅 후 1.5초 settle 통과 후에만 처리 (floating 핀 안정화).
  if (now >= BTN_SETTLE_MS) {
    if (btn::pollFallingEdge(btn::g_boot, now)) {
      // BOOT 버튼 = toggle. Standby/Summary 면 start, 그 외 면 stop.
      const auto s = session::currentState();
      if (s == session::State::Standby || s == session::State::Summary) {
        Serial.println("[btn] BOOT pressed -> startSession");
        session::startSession();
      } else {
        Serial.println("[btn] BOOT pressed -> stopSession");
        session::stopSession();
      }
    }
    if (btn::pollFallingEdge(btn::g_user, now)) {
      Serial.println("[btn] USER pressed -> stopSession");
      session::stopSession();
    }
  }

  // Session state machine tick.
  const float p = sensor::currentCmH2O();
  static session::State last_state = session::State::Boot;
  session::tick(now, p);
  const session::State cur = session::currentState();
  if (cur != last_state) {
    Serial.printf("[state] %u -> %u\n", (unsigned)last_state, (unsigned)cur);
    switchScreenFor(cur);

#if HAS_BLE
    // Device State notify (4B). orifice/battery 는 placeholder (M9 NVS 후 실값).
    ble_service::pushState((uint8_t)cur, /*orifice=*/0, /*battery=*/100, /*charging=*/false);

    // Summary 진입 시 Session Summary notify (40B). state machine 의 stats() 활용.
    // maxPressure/avgPressure 는 호기(양압) 통계, avgInhale/maxInhale 은 흡기(음압).
    if (cur == session::State::Summary) {
      const auto& st = session::stats();
      ble_service::SummaryFields s = {
        .startEpoch    = ble_service::startEpoch(),
        .durationSec   = st.duration_sec,
        .maxPressure   = st.max_exhale,
        .avgPressure   = st.avg_exhale,
        .enduranceSec  = st.hit_ms / 1000,
        .orificeLevel  = 0,     // TODO M9
        .targetHits    = 0,     // TODO M9 (15s hold count)
        .sampleCount   = (uint16_t)((uint32_t)st.duration_sec * 100u > 65535u ? 65535u
                                    : (uint16_t)((uint32_t)st.duration_sec * 100u)),
        .crc32         = 0,     // TODO M9
        .sessionId     = 0,     // TODO M9 (NVS counter)
        .avgInhale     = st.avg_inhale,
        .maxInhale     = st.max_inhale,
      };
      ble_service::pushSummary(s);
    }
#endif

    last_state = cur;
  }

#if HAS_BLE
  // BLE 연결 상태 변화 → standby 화면 BT dot 동기화 (현재 Standby state 일 때만).
  static bool last_ble_connected = false;
  const bool ble_now = ble_service::isConnected();
  if (last_ble_connected != ble_now) {
    last_ble_connected = ble_now;
    Serial.printf("[ble] connection state -> %s\n", ble_now ? "connected" : "disconnected");
    if (cur == session::State::Standby) {
      screens::standby_set_connected(ble_now);
    }
  }
#endif

  // Training 화면이면 압력 + 카운트다운 + 진행률 실시간 갱신.
  static uint32_t lastUpdate20HzMs = 0;
  if (cur == session::State::Prep || cur == session::State::Train) {
    if (now - lastUpdate20HzMs >= 50) {
      lastUpdate20HzMs = now;
      screens::training_set_pressure(p);
    }
  }
  static uint32_t lastUpdate1HzMs = 0;
  if (now - lastUpdate1HzMs >= 1000) {
    lastUpdate1HzMs = now;
    if (cur == session::State::Prep || cur == session::State::Train) {
      const auto turn = session::currentTurn();
      screens::TrainingPhase ui_phase;
      switch (turn) {
        case session::Turn::Inhale:     ui_phase = screens::TrainingPhase::Inhale; break;
        case session::Turn::ExhaleRest:
        case session::Turn::InhaleRest: ui_phase = screens::TrainingPhase::Rest; break;
        // None(=Prep 등) / Exhale / default → 호기(흰 배경). Prep 이 휴식(검정)
        // 으로 평가돼 검은 화면이 깜빡이던 문제 방지.
        case session::Turn::Exhale:
        case session::Turn::None:
        default:                        ui_phase = screens::TrainingPhase::Exhale; break;
      }
      screens::training_set_phase(ui_phase, session::remainingSec());
      screens::training_set_progress(session::progressPercent(),
                                     session::currentSet(),
                                     3);
    } else if (cur == session::State::Rest) {
      screens::rest_set_remaining(session::remainingSec());
    }
    const int boot_raw = digitalRead(pins::BUTTON_BOOT);
    const int user_raw = digitalRead(pins::BUTTON_USER);
    Serial.printf("[%lu] state=%u turn=%u P=%+6.2f rem=%us BOOT=%d USER=%d\n",
                  now, (unsigned)cur, (unsigned)session::currentTurn(),
                  p, session::remainingSec(), boot_raw, user_raw);
  }

  // LVGL tick.
#if HAS_LVGL
  lvgl_port::tick();
#endif

  delay(2);
}
