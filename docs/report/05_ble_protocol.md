# 제 5 장  통신 프로토콜 (BLE)

> 본 장에서는 펌웨어와 앱 사이의 통신 프로토콜을 기술한다. BLE 5.0 GATT 위에 단일 커스텀 서비스를 정의했으며, 표준 서비스(Battery, Device Information) 도 함께 노출한다. 1차 자료는 `docs/ble-protocol.md` 이며 본 장은 v4.1 변경 사항을 추가 반영한다.

---

## 5.1 BLE 광고 및 연결 파라미터

### 5.1.1 광고

표 5.1 — 광고 사양.

| 항목 | 값 |
|---|---|
| Advertising Name | `BlowFit` (실기기) / `BlowFit-SIM` (시뮬레이터) |
| Advertising Interval | 100 ms (활성) / 1000 ms (저전력) |
| Service UUID in Adv | `0000B410-0000-1000-8000-00805F9B34FB` |
| TX Power | 0 dBm |

앱은 이름 prefix `BlowFit` (또는 사용자 정의 prefix `BRELOW`) 로 필터링한다.

### 5.1.2 연결

표 5.2 — 연결 파라미터.

| 항목 | 값 |
|---|---|
| Connection Interval | 15 ~ 30 ms |
| Slave Latency | 0 |
| Supervision Timeout | 4,000 ms |
| ATT MTU | **185 (요청), 23 (최소 fallback)** |

> MTU 185 협상 실패 시 PressureStream 패킷이 분할 전송되어 throughput 이 떨어진다. 본 MVP 는 협상 실패 시 사용자에게 안내 후 재시도를 유도하며, 패킷 분할 자체는 GATT 가 자동 처리하므로 동작 자체는 보장된다.

---

## 5.2 GATT 서비스 구조

### 5.2.1 BlowFit Training Service

기본 UUID: `0000B410-0000-1000-8000-00805F9B34FB`

전체 128-bit UUID 는 suffix 자리만 변경한다: `0000XXXX-0000-1000-8000-00805F9B34FB`.

표 5.3 — Characteristic 목록.

| Char | UUID suffix | Properties | Size | 설명 |
|---|---|---|---|---|
| Pressure Stream | `B411` | Notify | 22 B | 100 Hz 샘플을 20 Hz 로 묶음 전송 |
| Session Control | `B412` | Write | 1 ~ 6 B | 앱 → 기기 명령 |
| Session Summary | `B413` | Read, Notify | 40 B | 세션 종료 시 통계 |
| Device State | `B414` | Read, Notify | 4 B | 현재 상태·오리피스·배터리 |
| History List | `B415` | Read | ≤244 B | 최근 30 세션 요약 배열 |

### 5.2.2 표준 서비스

- **Battery Service** `0x180F` — Battery Level char (`0x2A19`, 0~100 %)
- **Device Information** `0x180A` — Firmware Revision (`0x2A26`), Manufacturer (`0x2A29`)

---

## 5.3 Pressure Stream (Notify, 22 B)

```
offset  size  field        encoding
  0      2    seq          uint16   (패킷 시퀀스, 0-65535 wrap)
  2     20    samples[10]  int16    (cmH₂O × 10, 0.1 해상도)
```

표 5.4 — Pressure Stream 패킷 layout.

- 전송 주기: 50 ms (20 Hz), 샘플 10 개/패킷 = 실측 **100 Hz**.
- 해상도: `cmH₂O = bytes / 10.0` (예: `253` → 25.3 cmH₂O, `-150` → -15.0 cmH₂O).
- 범위: -3,276.8 ~ +3,276.8 (int16 / 10). 실 사용 범위는 펌웨어 saturation clamp 인 ±71 cmH₂O.

### 5.3.1 시퀀스 단조 증가

`seq` 는 패킷마다 +1 (16-bit wrap). 앱은 `SeqGapDetector` 가 누락을 감지하면 `BleHealth` 카운터를 증가시켜 추후 진단에 활용한다 (§10.2).

---

## 5.4 Session Control (Write, 1 ~ 6 B)

```
byte 0:    opcode
byte 1..:  payload (opcode 별)
```

표 5.5 — Opcode 일람 (v4.1).

| Opcode | 명령 | Payload | 설명 |
|---|---|---|---|
| `0x01` | START_SESSION | (a) 1 B `orificeLevel` <br> (b) 2 B `orificeLevel + startPhase` (v4.1) | 훈련 시작. `startPhase`: 0=Exhale 부터, 1=Inhale 부터 |
| `0x02` | STOP_SESSION | — | 훈련 조기 종료 |
| `0x03` | SYNC_TIME | 4 B uint32 epoch (sec) | 세션 타임스탬프 동기화 |
| `0x04` | ZERO_CALIBRATE | — | 영점 재보정 (2 초 측정) |
| `0x05` | SET_TARGET | (a) 2 B `low + high` (legacy v4.0) <br> (b) 5 B `level + pimax×10 + mep×10` (v4.1) | 목표 압력 zone 설정 |
| `0x06` | SET_DURATION | 2 B uint16 LE seconds | Train 세션 길이 (1 ~ 10 분 clamp) |

### 5.4.1 v4.1 변경 — START_SESSION

본 보고서 v4.1 에서 PImax/MEP 측정 화면 도입을 위해 `startPhase` byte 를 추가했다. 길이로 호환성을 유지한다:

```cpp
// firmware-esp32/src/ble_service.cpp
const uint8_t lvl   = (plen >= 1) ? payload[0] : 1;
const uint8_t phase = (plen >= 2) ? payload[1] : 0;
session::startSession(phase == 1 ? session::StartPhase::Inhale
                                 : session::StartPhase::Exhale);
```

### 5.4.2 v4.1 변경 — SET_TARGET (Clinical Payload)

기존 2 byte (`low`, `high`) 절댓값 zone 은 흡기/호기 대칭이라 임상 적용성이 떨어진다. v4.1 은 길이 5 B 의 새 payload 를 도입했다.

```
v4.1 SET_TARGET payload (5 B):
  byte 0:    intensityLevel (u8)         0=Beginner, 1=Normal, 2=Advanced
  bytes 1-2: pimax × 10    (u16 LE)      cmH₂O × 10
  bytes 3-4: mep   × 10    (u16 LE)      cmH₂O × 10
```

펌웨어는 payload 길이로 분기한다 (`plen == 2` legacy, `plen >= 5` v4.1). 흡기/호기 4 개 target 은 펌웨어 측에서 비율 표(`INTENSITY_*_PCT`)와 곱셈으로 자동 계산되며, 안전 상한 초과 시 clamp + Serial 경고가 발생한다.

---

## 5.5 Session Summary (Read / Notify, 40 B)

```
offset  size  field
  0      4    startEpoch     (uint32, SYNC_TIME 전이면 0)
  4      4    durationSec    (uint32)
  8      4    maxPressure    (float, cmH₂O — 호기/양압 최대)
 12      4    avgPressure    (float, cmH₂O — 호기/양압 평균)
 16      4    enduranceSec   (uint32, 목표 구간 유지 합계)
 20      1    orificeLevel   (uint8)
 21      1    targetHits     (uint8, 15 s 이상 유지 횟수)
 22      2    sampleCount    (uint16, 원본 파형 개수)
 24      4    crc32          (uint32, 헤더 + 파형)
 28      4    sessionId      (uint32, 기기 내 고유 ID)
 32      4    avgInhale      (float, cmH₂O — 흡기 평균 magnitude, 양수)
 36      4    maxInhale      (float, cmH₂O — 흡기 최대 magnitude, 양수)
```

표 5.6 — Session Summary layout. 32 ~ 39 byte 는 v4.0+ 부터 추가된 흡기 통계 필드이며, 0 ~ 31 byte 는 구버전 32 B 레이아웃과 호환된다(append-only).

세션 종료 시 펌웨어는 이 패킷을 Notify 로 푸시한다. 앱은 수신 후 Drift DB 의 `Sessions` 테이블에 upsert 하고 `/result` 화면을 표시한다.

---

## 5.6 Device State (Read / Notify, 4 B)

```
offset  size  field
  0      1    state          (enum)
  1      1    orificeLevel   (uint8)
  2      1    batteryPct     (uint8, 0-100)
  3      1    flags          (bit0: charging, bit1: bleConnected, bit2: lowBattery)
```

표 5.7 — Device State layout.

State enum (`include/config.h::DeviceState`):

| 값 | 이름 | 설명 |
|---|---|---|
| 0 | BOOT | 부팅 직후 |
| 1 | STANDBY | 대기 |
| 2 | PREP | 호흡 준비 |
| 3 | TRAIN | 훈련 중 |
| 4 | REST | 세트 간 휴식 |
| 5 | SUMMARY | 세션 요약 |
| 6 | WEEKLY | 주간 기록 |
| 7 | ERROR | 오류 |

상태 전이 시 펌웨어가 자동으로 Notify 발행. 앱은 상태에 따라 UI 를 갱신 (예: TRAIN 진입 시 `/training` 화면 자동 push, 옵션).

---

## 5.7 History List (Read, ≤ 244 B)

```
[count: uint8]
[entry × count]
  entry (8 B):
    sessionId  uint32
    maxPress   uint16  (cmH₂O × 10)
    duration   uint16  (sec)
```

표 5.8 — History List layout.

30 × 8 + 1 = 241 B. 한 번의 Long Read 로 가능 (ATT MTU 244 가정). 앱은 첫 연결 시 이를 읽어 Drift DB 와 비교한 뒤 누락 세션을 보충한다 (re-sync).

---

## 5.8 앱 측 연결 상태 머신

그림 5.1 — 앱의 BLE 연결 상태 머신 (`core/ble/real_ble_manager.dart`).

```
IDLE
  │ startScan
  ▼
SCANNING ──── found ────► CONNECTING
                            │  fail
                            ◄──────┐
                            ▼      │
                       MTU_NEGOTIATE
                            │ success
                            ▼
                       SUBSCRIBING (Pressure + State + Summary)
                            │
                            ▼
                       STREAMING
                            │ disconnect
                            ▼
                       RECONNECT (backoff 2/4/8 s)
                            │
                            ▼ recovered
                       STREAMING
```

### 5.8.1 Foreground Service 기반 자동 재연결

Android 의 메모리 관리 정책 상 앱이 background 로 가면 BLE 연결이 끊길 수 있다. BRELOW 는 `flutter_foreground_task` 로 영구 알림이 표시되는 foreground service 를 실행해 앱 종료 후에도 자동 재연결을 유지한다.

```
1. 첫 페어링 → main app 이 service 시작
2. Service 가 background isolate 에서 실행 (영구 알림)
3. 30 초마다 onRepeatEvent → 본딩된 디바이스 광고 스캔
4. 디바이스 발견 시 connect (autoConnect=true)
5. 연결 성공 시 service notification 갱신
```

⚠️ flutter_blue_plus 의 `BluetoothDevice` 객체는 isolate 단위로 분리된다. 따라서 service isolate 가 잡고 있는 연결을 main app 이 직접 공유할 수는 없으며, main app 이 켜지면 service 가 일시적으로 disconnect 한 뒤 main app 이 재연결하는 패턴을 사용한다.

---

## 5.9 안정성 및 검증

### 5.9.1 SeqGapDetector

앱은 PressureStream 패킷의 `seq` 를 추적해 누락 카운트(loss rate) 와 재연결 카운트(resets) 를 계산한다.

```dart
class BleHealth {
  final int dropped;     // 누락 sample 수
  final int total;       // 총 수신 sample 수
  double get lossRate => dropped / total;
}
```

코드 5.1 — `core/ble/seq_gap_detector.dart` 의 핵심 모델.

### 5.9.2 친화적 에러 메시지

`flutter_blue_plus` 의 예외 메시지는 사용자에게 그대로 노출하기에 너무 기술적이다. `core/ble/ble_error_translator.dart` 가 6 카테고리로 분류해 사용자에게 자연어로 안내한다.

| 카테고리 | 예시 메시지 |
|---|---|
| Bluetooth OFF | "블루투스가 꺼져 있어요. 설정에서 켜주세요." |
| 권한 거부 | "근처 기기 검색 권한이 필요해요." |
| 디바이스 없음 | "주변에서 BRELOW 를 찾지 못했어요." |
| 연결 실패 | "기기와 연결에 실패했어요. 다시 시도해주세요." |
| 서비스 발견 실패 | "기기 정보를 읽지 못했어요. 기기를 재부팅 후 다시 시도해주세요." |
| 알 수 없음 | "일시적 오류 발생. 잠시 후 다시 시도해주세요." |

표 5.9 — 친화적 에러 카테고리.

---

## 5.10 페어링 보안

- **MVP**: Just Works (암호화만, 본딩 없음)
- **v2**: Passkey 인증 (계획)

본 MVP 는 의료 기기가 아닌 호흡 훈련 보조 기기로 분류되어 OTA 조작이나 인증 정보의 노출 가능성이 낮다고 판단, Just Works 만 적용한다. 향후 임상 시험 단계에서는 본딩 + Passkey 로 강화한다.

---

## 5.11 변경 이력

| 버전 | 변경 |
|---|---|
| v1.0 (2026-04) | 초안, FW/앱 양측 구현 시작점 |
| v1.1 (2026-05) | 양방향 차압 센서 도입, Summary 40 B 확장 (avgInhale / maxInhale) |
| **v1.2 (2026-06)** | **START_SESSION 의 `startPhase` byte 추가**, **SET_TARGET 의 v4.1 clinical 5 B payload 추가**. 두 변경 모두 length-prefix 호환. |

표 5.10 — BLE 프로토콜 변경 이력.

---

*— 제 5 장 끝 —*
