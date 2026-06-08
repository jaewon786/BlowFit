# 제 4 장  펌웨어 설계

> 본 장에서는 BRELOW 디바이스의 펌웨어 구조를 모듈 단위로 기술한다. 펌웨어는 ESP-IDF 위의 Arduino 프레임워크 (PlatformIO `lilygo-t-display-s3` env) 로 작성되었으며, 코드 베이스는 `firmware-esp32/` 에 있다.

---

## 4.1 모듈 다이어그램

그림 4.1 — BRELOW 펌웨어의 모듈 의존성.

```
        ┌──────────────────────────────────────┐
        │            main.cpp (loop)           │
        │  100 Hz sensor tick · state · BLE    │
        └──────────────────────────────────────┘
            │      │      │      │      │
            ▼      ▼      ▼      ▼      ▼
        sensor session ble_service haptic power battery
            │                │
            │                ▼
            │           display/lvgl_port
            │                │
            │                ▼
            │           display/screens/ (boot/pairwait/standby/
            │                            training/rest/summary/charging/error)
            ▼
       Wire (I²C)
```

표 4.1 — 모듈별 책임.

| 모듈 | 헤더 | 책임 |
|---|---|---|
| sensor | `include/sensor.h` | 압력 측정, 영점 보정, EMA 필터, saturation clamp |
| session | `include/session.h` | 세션 state machine, 4-phase Turn cycle, 통계 누적, %PImax 적응형 target |
| ble_service | `include/ble_service.h` | GATT 서버, 5 char, 6 opcode 처리 |
| haptic | `include/haptic.h` | DRV2605L 효과 트리거 (6종) |
| power | `include/power.h` | Deep sleep 진입, wake gate |
| battery | `include/battery.h` | VBAT 측정 → 잔량 %, 충전 감지 |
| display/lvgl_port | `include/display/lvgl_port.h` | LVGL 초기화, TFT_eSPI buffer 연결 |
| display/screens/* | 9 파일 | 화면별 LVGL 객체 라이프사이클 |

---

## 4.2 메인 루프 (main.cpp)

`firmware-esp32/src/main.cpp:loop()` 의 골격:

```cpp
void loop() {
  const uint32_t now = millis();

  ble_service::poll();                          // BLE watchdog

  // 100 Hz 압력 샘플링 + BLE PressureStream 누적
  if (now - lastSampleMs >= 10) {
    lastSampleMs = now;
    sensor::tick();
    const float v = sensor::currentCmH2O();
    ble_sample_buf[ble_sample_idx++] = lroundf(v * 10.0f);
    if (ble_sample_idx >= 10) {
      ble_service::pushSamples(ble_sample_buf, 10);   // 20 Hz packet
      ble_sample_idx = 0;
    }
  }

  power::tick(now);                             // Deep sleep 진입 감지

  // 버튼 (BOOT short = start, USER short = stop)
  if (btn::pollFallingEdge(g_boot, now)) session::startSession();
  if (btn::pollFallingEdge(g_user, now)) session::stopSession();

  // Session state machine tick
  session::tick(now, sensor::currentCmH2O());

  // 화면 갱신 (state 변화 시)
  if (session::currentState() != last_state) switchScreenFor(...);
  lvgl_port::tick();
}
```

코드 4.1 — `loop()` 의 의사 코드. 모든 sub-system 이 동일한 1 ms 단위 시간축에서 협력적으로 동작.

---

## 4.3 센서 모듈

### 4.3.1 변환식 (재인용)

```
ratio = ADC / 4095
ΔP_kPa = (ratio - 0.5) / 0.057
ΔP_cmH₂O = ΔP_kPa × 10.197
```

식 4.1 — MPXV7007DP ratiometric 변환식 (3장 식 3.1 재인용).

### 4.3.2 영점 보정

영점은 사용자가 마우스피스를 입에 물지 않은 상태의 대기압을 0 cmH₂O 로 정의한다. 부팅 직후 자동으로 200 샘플 평균(2 초)을 측정해 NVS 에 저장하며, 사용자는 설정 화면 → "영점 보정" 또는 BLE opcode `0x04` 로 언제든 재보정 가능하다.

```cpp
constexpr int ZERO_CALIBRATION_SAMPLES = 200;   // 100 Hz × 2 s
```

### 4.3.3 EMA 필터

100 Hz raw 값에 1차 IIR(EMA) 를 적용해 고주파 노이즈를 억제한다.

```
filtered_n = α × raw_n + (1 - α) × filtered_{n-1}
```

α 는 응답 속도(빠른 호흡 반응)와 노이즈 억제 간의 trade-off 로 선정.

### 4.3.4 Saturation Clamp

`sensor::currentCmH2O()` 결과는 ±71 cmH₂O 로 clamp 된다 (`config.h::sensor::MIN/MAX_CMH2O`). 이는 (a) 데이터시트 정확도 보장 범위, (b) 안전 ceiling 의 이중 역할.

---

## 4.4 세션 상태 머신

### 4.4.1 State 다이어그램

그림 4.2 — `session::State` 전이.

```
   ┌──────┐        ┌──────────┐
   │ Boot │ ─────► │ Standby  │ ◄─────┐
   └──────┘        └────┬─────┘       │
                        │ startSession│ stopSession / Summary 끝(8 s 자동)
                        ▼             │
                   ┌──────────┐       │
                   │  Prep    │ (0 s 즉시 통과)
                   └────┬─────┘       │
                        ▼             │
              ┌──► ┌──────────┐ ──────┴──────► ┌──────────┐
        Rest  │    │  Train   │ ────set 완료──►│ Summary  │
       (30 s)│    └──────────┘   ◄──set N───  └──────────┘
              │
              └── 다음 set ──┐
                            │
                            ▼
                       ┌──────────┐
                       │   Rest   │ (30 s)
                       └──────────┘
```

표 4.2 — State 정의 (`include/session.h::State`).

| State | 값 | LCD 화면 | 비고 |
|---|---|---|---|
| Boot | 0 | screen_boot | 부팅 직후 (1 회) |
| Standby | 1 | screen_standby / screen_charging | 대기 |
| Prep | 2 | screen_training (카운트다운) | PREP_MS = 0 → 즉시 Train 진입 |
| Train | 3 | screen_training | 호흡 cycle 진행 |
| Rest | 4 | screen_rest | 세트 사이 30 s 휴식 |
| Summary | 5 | screen_summary | 통계 표시 (8 s) |
| Error | 7 | screen_error | 센서 read fail 등 |

### 4.4.2 Train 의 4-phase Turn Cycle

Train state 내부는 호흡 phase 별로 cycle 을 돈다.

```cpp
// firmware-esp32/include/config.h::session
constexpr uint32_t BREATH_INHALE_MS = 5000;
constexpr uint32_t BREATH_EXHALE_MS = 5000;
constexpr uint32_t BREATH_REST_MS   = 5000;
```

구현상 `Turn` enum 은 v4.0 호환을 위해 4-phase 로 유지하되, `ExhaleRest = 0 ms` 로 사실상 3-phase 동작.

| Turn | 시간 | LCD 라벨 | 햅틱 cue |
|---|---|---|---|
| Exhale | 5 s | "내쉬기" | EXHALE_CUE |
| ExhaleRest | 0 s | (skip) | — |
| Inhale | 5 s | "들이쉬기" | INHALE_CUE |
| InhaleRest | 5 s | "휴식" | — |

1 cycle = 15 s. 1 set = 10 cycle = 150 s. 한 세션 = `TOTAL_SETS=2` × 150 s + 세트 사이 휴식 30 s ≈ **5.5 분**.

### 4.4.3 시작 Phase 오프셋 (Cycle Offset)

v4.1 에서 PImax/MEP 측정 화면 도입 시 추가된 기능. 흡기 측정을 위해 LCD 가 처음부터 "들이쉬기" 화면을 보여야 하나, cycle 은 항상 Exhale 부터 시작했다. `startSession(StartPhase)` 에 phase 인자를 추가하고 내부적으로 cycle offset 으로 적용했다.

```cpp
// firmware-esp32/src/session.cpp
g_cycle_offset_ms = (phase == StartPhase::Inhale) ? TURN_EXHALE_MS : 0;
// ...
g_turn = turnAt(elapsed + g_cycle_offset_ms);
```

코드 4.2 — Cycle offset 의 적용. Train 의 `elapsed`(진행률) 자체는 0 부터라 progress bar 는 영향을 받지 않는다.

### 4.4.4 통계 누적

Train state 동안 매 tick 마다 4 종 통계를 누적한다.

| 변수 | 의미 |
|---|---|
| `g_max_abs_p` | 세션 max |p| |
| `g_sum_exhale / g_n_exhale / g_max_exhale` | 호기(양압) 합·개수·최대 |
| `g_sum_inhale / g_n_inhale / g_max_inhale` | 흡기(음압) magnitude 합·개수·최대 |
| `g_hit_ms` | turn 별 비대칭 target zone 안 머문 시간 |

Summary state 진입 시 `finalizeStats()` 가 평균을 계산하고 `Stats` 구조체를 채워 BLE 로 전송한다.

### 4.4.5 비대칭 Zone Hit 평가

v4.1 부터 zone hit 판정은 phase 에 따라 비대칭이다.

```cpp
if (g_turn == Turn::Exhale)
  in_zone = (p >= g_exhale_target_low && p <= g_exhale_target_high);
else if (g_turn == Turn::Inhale)
  in_zone = (-p >= g_inhale_target_low && -p <= g_inhale_target_high);
```

호기 turn 에는 양압 만, 흡기 turn 에는 |음압| 만 평가한다. 휴식(Rest) phase 는 평가 제외.

---

## 4.5 BLE 서비스

본 모듈의 상세는 **제 5 장**에서 별도로 다룬다. 본 절에서는 펌웨어 측 책임만 명시한다.

| 책임 | 함수 |
|---|---|
| GATT 서버 광고 시작 | `ble_service::begin()` |
| Pressure Stream notify (20 Hz, 10 samples/packet) | `ble_service::pushSamples()` |
| Device State notify (state 변화 시) | `ble_service::pushState()` |
| Session Summary notify (Summary 진입 시) | `ble_service::pushSummary()` |
| 앱 → 기기 명령 처리 (opcode) | `BLECharacteristicCallbacks::onWrite` |

표 4.3 — BLE 모듈 인터페이스.

---

## 4.6 디스플레이 (LVGL 9.x)

### 4.6.1 LVGL 통합

LVGL 의 디스플레이 buffer 는 TFT_eSPI 의 `pushImage()` 콜백에 연결된다 (`display/lvgl_port.cpp`). 매 loop iteration 마다 `lvgl_port::tick()` 이 LVGL 의 task handler 를 호출해 화면 갱신을 수행한다.

### 4.6.2 화면 목록

표 4.4 — `display/screens/` 9 파일.

| 화면 | 진입 조건 | 표시 내용 |
|---|---|---|
| screen_boot | Boot state | 로고 + spinner (영점 보정 중) |
| screen_pairwait | BLE 미연결 + Standby | "기기 연결 대기" + BT 아이콘 깜빡임 |
| screen_pairconnected | BLE 연결 이벤트 (1 회성) | "연결됨" |
| screen_standby | Standby + 충전 X | 배터리 잔량 + 호흡 가이드 |
| screen_charging | Standby + 충전 중 | 충전 아이콘 + % |
| screen_training | Prep / Train | phase 라벨 + 카운트다운 + 현재 압력 + 목표 영역 |
| screen_rest | Rest | "휴식" + 남은 시간 |
| screen_summary | Summary | max / avg / hit % |
| screen_error | Error | 에러 코드 + reset 안내 |

### 4.6.3 status_bar

전체 화면 공통으로 표시되는 상단 status bar (`display/screens/status_bar.cpp`):

- 좌측: BLE 연결 dot (회색=미연결 / 파란색=연결)
- 우측: 배터리 잔량 + 충전 아이콘

---

## 4.7 햅틱 (DRV2605L)

### 4.7.1 아키텍처

DRV2605L 은 내장 ROM library 의 효과 ID 를 GO bit 로 트리거하는 방식으로 동작한다. PWM 직접 제어가 아니므로 MCU 부하가 최소화된다.

```cpp
namespace haptic {
  enum Effect : uint8_t {
    SESSION_START = 16,  // 1000 ms Alert 100%
    EXHALE_CUE    = 15,  // 750 ms Alert 100%
    INHALE_CUE    = 15,
    REST_CUE      = 16,
    SESSION_DONE  = 16,
    POWER_ON      = 16,
    POWER_OFF     = 16,
  };
  void play(uint8_t effect, uint8_t repeat = 1);
}
```

코드 4.3 — `haptic::Effect` enum 과 효과 ID 매핑. ROM library 1 (TS2200 ERM A) 의 강한 alert 효과 위주로 선정.

### 4.7.2 호출 지점

| 트리거 | 호출 |
|---|---|
| 세션 시작 | `haptic::play(SESSION_START)` |
| Train 의 Exhale 진입 | `haptic::play(EXHALE_CUE)` |
| Train 의 Inhale 진입 | `haptic::play(INHALE_CUE)` |
| Train → Rest 전환 | `haptic::play(REST_CUE)` |
| Summary 진입 | `haptic::play(SESSION_DONE, 3)` (3 회 반복) |
| 전원 ON (버튼 wake) | `haptic::play(POWER_ON)` |
| Deep sleep 진입 직전 | `haptic::play(POWER_OFF)` |

표 4.5 — 햅틱 cue 호출 지점.

---

## 4.8 전원 관리 (Deep Sleep + Wake Gate)

### 4.8.1 소비 전류

| 모드 | 전류 | 400 mAh 배터리 가용 시간 |
|---|---|---|
| ON (LCD + BLE 광고 + 100 Hz 센서) | ~80 mA | 5 시간 |
| Deep sleep | ~10 μA | 5 년+ |

### 4.8.2 Deep Sleep 진입 조건

- BOOT 버튼 (GPIO 0) long-press **2 초** → deep sleep
- PWR_BUTTON (GPIO 12) long-press **3 초** → deep sleep

진입 직전 `haptic::POWER_OFF` 진동으로 사용자에게 명확한 피드백을 준다.

### 4.8.3 Wake Gate

오작동(가방 안 우발 압력 등) 으로 인한 의도치 않은 wake 를 방지하기 위해, deep sleep 에서 EXT0 (PWR_BUTTON) 으로 깨어났을 때 **3 초간 연속으로 버튼을 눌러야** 실제 부팅이 진행된다. 그 전에 떼면 다시 deep sleep 으로 복귀한다(LCD 도 켜지지 않음).

```cpp
// firmware-esp32/src/power.cpp::wakeGate()
if (wakeup_cause == ESP_SLEEP_WAKEUP_EXT0) {
  // 3초간 버튼 hold 확인
  uint32_t hold_start = millis();
  while (digitalRead(PWR_BUTTON) == LOW) {
    if (millis() - hold_start >= WAKE_HOLD_MS) return;  // 정상 wake
  }
  esp_deep_sleep_start();   // 다시 sleep
}
```

코드 4.4 — Wake gate 의 핵심 로직.

---

## 4.9 배터리 모니터링

### 4.9.1 측정

T-Display-S3 는 VBAT 를 내장 2:1 분압기로 GPIO 4 (ADC1_CH3) 에 연결한다. 추가 회로 없이 `analogReadMilliVolts(4) × 2` 가 VBAT 의 mV 값.

### 4.9.2 잔량 추정

LiPo 단셀의 방전 곡선은 비선형이지만, 일반적인 평탄 구간(3.7 ~ 4.0 V) 에서는 선형 근사가 가능하다.

```
V ≥ 4.20 V → 100 %
V ≤ 3.30 V → 0 %
선형 보간
```

식 4.2 — LiPo 단셀 방전 곡선의 선형 근사.

### 4.9.3 충전 감지

USB 연결 시 충전 IC 가 VBAT 를 4.2 V 이상으로 끌어올린다. 부하 sag 가 사라지므로 이 임계를 hysteresis 와 함께 사용해 충전 여부를 판정한다 (`battery::isCharging()`).

> ⚠️ 충전 초기(VBAT 가 4.15 V 미만) 에는 전압 기반 감지가 실패할 수 있다. 정확한 충전 감지는 충전 IC 의 status 핀이 필요하나, 본 보드는 해당 핀을 노출하지 않아 추정 방식으로 처리한다.

---

## 4.10 펌웨어 빌드 / 플래시

### 4.10.1 PlatformIO

`firmware-esp32/platformio.ini` 의 환경 이름은 `lilygo-t-display-s3` 이다.

```bash
cd firmware-esp32
pio run -e lilygo-t-display-s3                    # 빌드
pio run -e lilygo-t-display-s3 -t upload          # 플래시
pio device monitor -e lilygo-t-display-s3         # 시리얼 모니터
```

### 4.10.2 빌드 결과 (v4.1 기준)

```
RAM:   29.4 %  (96,380 / 327,680 bytes)
Flash: 23.2 %  (1,522,749 / 6,553,600 bytes)
```

LVGL 과 BLE 스택이 가장 큰 비중을 차지하지만, ESP32-S3 의 16 MB Flash 와 8 MB PSRAM 에 비하면 여유롭다.

---

*— 제 4 장 끝 —*
