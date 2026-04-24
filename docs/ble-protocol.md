# BLE 프로토콜 스펙 v1.0

**역할**: 펌웨어(nRF52840)와 Flutter 앱 간 단일 진실의 원천. 양측 구현은 이 문서를 기준으로 한다.
**변경 규칙**: 이 문서를 수정하면 PR에 양측 담당자(컴공·시디) 리뷰 필수.

---

## 1. BLE 광고

| 항목 | 값 |
|---|---|
| Advertising Name | `BlowFit` (실기기) / `BlowFit-SIM` (시뮬레이터) |
| Advertising Interval | 100 ms (활성) / 1000 ms (저전력) |
| Service UUID in Adv | `0000B410-0000-1000-8000-00805F9B34FB` |
| TX Power | 0 dBm |

앱은 이름 prefix `BlowFit` 로 필터링한다.

---

## 2. GATT 서비스 구조

### 2.1 BlowFit Training Service
`0000B410-0000-1000-8000-00805F9B34FB`

| Char | UUID (suffix) | Props | Size | 설명 |
|---|---|---|---|---|
| Pressure Stream | `B411` | Notify | 22B | 100Hz 샘플을 20Hz로 묶음 전송 |
| Session Control | `B412` | Write | 1-6B | 앱→기기 명령 |
| Session Summary | `B413` | Read, Notify | 32B | 세션 종료 시 요약 |
| Device State | `B414` | Read, Notify | 4B | 현재 상태·오리피스·배터리 |
| History List | `B415` | Read | ≤244B | 최근 30개 세션 요약 배열 |

전체 128-bit UUID는 suffix 자리를 바꿔 구성한다:
`0000XXXX-0000-1000-8000-00805F9B34FB`

### 2.2 표준 서비스

- Battery Service `0x180F` — Battery Level char (`0x2A19`, 0-100%)
- Device Information `0x180A` — Firmware Revision (`0x2A26`), Manufacturer (`0x2A29`)

---

## 3. 데이터 포맷 (Little-Endian)

### 3.1 Pressure Stream (Notify, 22 B)

```
offset  size  field        encoding
 0      2     seq          uint16   (패킷 시퀀스, 0-65535 wrap)
 2      20    samples[10]  int16    (cmH2O × 10, 0.1 해상도)
```

- 전송 주기: 50 ms (20 Hz), 샘플 10개/패킷 = 실측 100 Hz
- 해상도: `value = bytes / 10.0` (예: 253 → 25.3 cmH2O)
- 범위: -100 ~ +500 (int16 여유 있음)
- 시퀀스 누락 시 앱은 `HistoryList` 재요청 고려

### 3.2 Session Control (Write, 1-6 B)

```
byte 0: opcode
bytes 1..: payload (opcode 별)
```

| Opcode | 명령 | Payload | 설명 |
|---|---|---|---|
| `0x01` | START_SESSION | 1B orificeLevel (0=4mm, 1=3mm, 2=2mm) | 훈련 시작 |
| `0x02` | STOP_SESSION | — | 훈련 조기 종료 |
| `0x03` | SYNC_TIME | 4B uint32 epoch (sec) | 세션 타임스탬프 동기화 |
| `0x04` | ZERO_CALIBRATE | — | 10초간 대기압 측정·보정 |
| `0x05` | SET_TARGET | 1B low + 1B high (cmH2O) | 목표 구간 재설정 (기본 20~30) |

### 3.3 Session Summary (Read/Notify, 32 B)

```
offset  size  field
 0      4     startEpoch      (uint32, SYNC_TIME 전이면 0)
 4      4     durationSec     (uint32)
 8      4     maxPressure     (float, cmH2O)
12      4     avgPressure     (float, cmH2O)
16      4     enduranceSec    (uint32, 목표 구간 유지 합계)
20      1     orificeLevel    (uint8)
21      1     targetHits      (uint8, 15초 이상 유지 횟수)
22      2     sampleCount     (uint16, 원본 파형 개수)
24      4     crc32           (uint32, 헤더 + 파형)
28      4     sessionId       (uint32, 기기 내 고유 ID)
```

세션 종료 시 Notify 로 푸시. 앱은 수신 후 로컬 DB에 저장하고 사용자에게 요약 화면 표시.

### 3.4 Device State (Read/Notify, 4 B)

```
offset  size  field
 0      1     state         (enum, 아래)
 1      1     orificeLevel  (uint8)
 2      1     batteryPct    (uint8, 0-100)
 3      1     flags         (bit0: charging, bit1: bleConnected, bit2: lowBattery)
```

상태 enum:
| 값 | 이름 | 설명 |
|---|---|---|
| 0 | BOOT | 부팅 직후 |
| 1 | STANDBY | 대기 |
| 2 | PREP | 호흡 준비 30초 |
| 3 | TRAIN | 훈련 중 |
| 4 | REST | 세트 간 휴식 |
| 5 | SUMMARY | 세션 요약 표시 중 |
| 6 | WEEKLY | 주간 기록 표시 중 |
| 7 | ERROR | 오류 (센서 불량 등) |

상태 전이 시 Notify 발행.

### 3.5 History List (Read, 최대 244 B per read)

```
[count: uint8]
[entry × count]
  entry (8 B):
    sessionId  uint32
    maxPress   uint16 (cmH2O × 10)
    duration   uint16 (sec)
```

30 × 8 + 1 = 241 B. 한 번의 Long Read 로 가능 (ATT MTU 244 가정).

---

## 4. 연결 파라미터

| 파라미터 | 값 |
|---|---|
| Connection Interval | 15~30 ms |
| Slave Latency | 0 |
| Supervision Timeout | 4000 ms |
| ATT MTU | **185 (요청), 23 (최소 fallback)** |

MTU 협상 실패 시 앱은 PressureStream 패킷 크기를 10B(5샘플)로 축소하는 대체 경로가 필요하다. **MVP 범위에서는 MTU 185 실패 시 오류 안내 후 재시도 유도**.

---

## 5. 페어링

- MVP: **Just Works** (암호화만, 본딩 없음)
- v2: Passkey 인증

---

## 6. 앱 상태 머신 (연결 측면)

```
IDLE ── startScan ──▶ SCANNING ── found ──▶ CONNECTING
                                                │
                                 ◀── connect fail ─┤
                                                ▼
                                          MTU_NEGOTIATE
                                                │
                                          ▼ success
                                        SUBSCRIBING (Pressure + State + Summary)
                                                │
                                                ▼
                                          STREAMING
                                                │
                     ◀── disconnect ────────────┘
                             │
                             ▼
                      RECONNECT (backoff 2/4/8s)
```

---

## 7. 호환성 테스트 체크리스트

| 항목 | 방법 |
|---|---|
| 시퀀스 단조 증가 | 10분 수신 후 정렬 검증 |
| 샘플 레이트 ≥95Hz | `samples.length / duration` |
| Summary CRC | 앱에서 검증, 실패 시 로그 |
| 재연결 자동 복구 | 기기 전원 리셋 3회 모두 복구 |
| MTU 185 협상 성공률 | 안드로이드/iOS 각 2대 |

---

## 8. 변경 이력

- **v1.0 (2026-04)**: 초안. FW/앱 양측 구현 시작점.
