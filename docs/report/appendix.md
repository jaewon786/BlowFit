# 부록

---

## 부록 A. 코드 디렉토리 구조

```
BlowFit/
├── firmware-esp32/                펌웨어 (ESP32-S3)
│   ├── platformio.ini             PlatformIO 빌드 설정
│   ├── include/
│   │   ├── config.h               임상 상수 + pins + namespace
│   │   ├── sensor.h               압력 측정 API
│   │   ├── session.h              세션 state machine API
│   │   ├── ble_service.h          BLE GATT API
│   │   ├── ble_uuids.h            UUID + opcode + Orifice/State enum
│   │   ├── battery.h              VBAT 측정 API
│   │   ├── haptic.h               DRV2605L API
│   │   ├── power.h                Deep sleep API
│   │   └── lv_conf.h              LVGL 설정
│   ├── src/
│   │   ├── main.cpp               setup() + loop()
│   │   ├── sensor.cpp             MCP3221 read + EMA + 영점
│   │   ├── session.cpp            state machine + Train cycle + target
│   │   ├── ble_service.cpp        GATT 서버 + opcode 핸들러
│   │   ├── battery.cpp            VBAT ADC + LiPo 곡선
│   │   ├── haptic.cpp             효과 트리거
│   │   ├── power.cpp              deep sleep + wake gate
│   │   └── display/
│   │       ├── lvgl_port.cpp      LVGL ↔ TFT_eSPI bridge
│   │       └── screens/           9 LCD 화면
│   ├── docs/
│   │   ├── wiring.md              하드웨어 배선
│   │   └── mpxv7007_migration.md  센서 이전 기록
│   └── tools/                     i2c_scan / mcp3221_test
│
├── app/                           Flutter 앱 (Android)
│   ├── pubspec.yaml               의존성
│   ├── lib/
│   │   ├── main.dart              앱 진입점 + 라우트
│   │   ├── core/
│   │   │   ├── ble/               BLE 매니저 + 코덱 + 권한 + 백그라운드
│   │   │   ├── db/                Drift DB + repository
│   │   │   ├── storage/           SharedPreferences store
│   │   │   ├── coach/             코칭 카피 엔진
│   │   │   ├── health/            Samsung Health 연동
│   │   │   ├── pairing/           Firebase 동반자 모드
│   │   │   ├── notifications/     로컬 알림
│   │   │   ├── theme/             디자인 토큰 + 공통 위젯
│   │   │   └── models/            PressureSample / DeviceSnapshot / SessionSummary
│   │   └── features/
│   │       ├── role/              /role-select
│   │       ├── onboarding/        /onboarding (4 slide)
│   │       ├── profile_setup/     /profile-setup + /pimax-measure
│   │       ├── connect/           /connect
│   │       ├── home_pager/        / (홈 ↔ 추이 swipe)
│   │       ├── dashboard/         홈 (대시보드)
│   │       ├── trend/             /trend
│   │       ├── history/           /history
│   │       ├── training/          /training-intro + /training
│   │       ├── result/            /result
│   │       ├── session_detail/    /session/:id
│   │       ├── settings/          /settings + /settings/target
│   │       ├── profile/           /profile
│   │       ├── guide/             /guide
│   │       ├── sleep/             /sleep-effect + /sleep-trend
│   │       ├── companion/         /companion + 코드 입력
│   │       ├── pairing/           /my-code
│   │       └── shell/             메인 4-탭 셸
│   ├── assets/
│   │   ├── fonts/                 Pretendard 5 weight
│   │   ├── character/             BreLow Rive 3 단계
│   │   ├── dot/                   기타 SVG / 이미지
│   │   └── backgrounds/           배경 이미지
│   └── test/                      단위 / 위젯 테스트
│
├── docs/
│   ├── report/                    본 졸업 보고서 (12 파일)
│   ├── ble-protocol.md            BLE 명세 (1차 자료)
│   ├── calibration.md             영점 보정 절차
│   ├── design-v2.md               디자인 v2 적용 내역
│   ├── dev-plan.md                개발 계획서
│   └── archive/                   1차 디자인 등 아카이브
│
└── tools/
    └── ble-sim.py                 BLE 시뮬레이터 (Python)
```

---

## 부록 B. BLE 프로토콜 전체 명세

> `docs/ble-protocol.md` 의 전문을 본 보고서 일관성 맞춰 v4.1 까지 반영해 첨부한다.

### B.1 광고

| 항목 | 값 |
|---|---|
| Advertising Name | `BlowFit` / `BlowFit-SIM` |
| Advertising Interval | 100 ms (활성) / 1000 ms (저전력) |
| Service UUID | `0000B410-0000-1000-8000-00805F9B34FB` |
| TX Power | 0 dBm |

### B.2 Service: BlowFit Training (`B410`)

| Char | UUID suffix | Props | Size |
|---|---|---|---|
| Pressure Stream | B411 | Notify | 22 B |
| Session Control | B412 | Write | 1 ~ 6 B |
| Session Summary | B413 | Read, Notify | 40 B |
| Device State | B414 | Read, Notify | 4 B |
| History List | B415 | Read | ≤ 244 B |

### B.3 Pressure Stream (22 B)

| offset | size | field | encoding |
|---|---|---|---|
| 0 | 2 | seq | u16 LE |
| 2 | 20 | samples[10] | i16 LE × 10 |

### B.4 Session Control (1 ~ 6 B)

| Opcode | 명령 | Payload |
|---|---|---|
| 0x01 | START_SESSION | 1 B (orifice) 또는 2 B (orifice + startPhase) |
| 0x02 | STOP_SESSION | — |
| 0x03 | SYNC_TIME | 4 B (epoch u32 LE) |
| 0x04 | ZERO_CALIBRATE | — |
| 0x05 | SET_TARGET | 2 B (low + high, legacy) 또는 5 B (level + pimax×10 + mep×10) |
| 0x06 | SET_DURATION | 2 B (seconds u16 LE) |

### B.5 Session Summary (40 B)

| offset | size | field |
|---|---|---|
| 0 | 4 | startEpoch (u32) |
| 4 | 4 | durationSec (u32) |
| 8 | 4 | maxPressure (float, 호기) |
| 12 | 4 | avgPressure (float, 호기) |
| 16 | 4 | enduranceSec (u32) |
| 20 | 1 | orificeLevel (u8) |
| 21 | 1 | targetHits (u8) |
| 22 | 2 | sampleCount (u16) |
| 24 | 4 | crc32 (u32) |
| 28 | 4 | sessionId (u32) |
| 32 | 4 | avgInhale (float, 흡기 magnitude) |
| 36 | 4 | maxInhale (float, 흡기 magnitude) |

### B.6 Device State (4 B)

| offset | size | field |
|---|---|---|
| 0 | 1 | state (enum 0~7) |
| 1 | 1 | orificeLevel |
| 2 | 1 | batteryPct |
| 3 | 1 | flags (bit0:charging / bit1:bleConnected / bit2:lowBattery) |

### B.7 History List (≤ 244 B)

```
count: u8
entry × count (8 B each):
  sessionId: u32
  maxPress:  u16 (×10)
  duration:  u16 (sec)
```

### B.8 표준 서비스

- Battery `0x180F` (Battery Level `0x2A19`)
- Device Information `0x180A` (Firmware Revision `0x2A26`, Manufacturer `0x2A29`)

### B.9 연결 파라미터

| 항목 | 값 |
|---|---|
| Connection Interval | 15 ~ 30 ms |
| Slave Latency | 0 |
| Supervision Timeout | 4000 ms |
| ATT MTU | 185 (요청) / 23 (fallback) |

---

## 부록 C. 핀 맵 및 회로도

### C.1 핀 맵 (config.h::pins 와 1:1)

| GPIO | 신호 | 방향 |
|---|---|---|
| 0 | BUTTON_BOOT | IN |
| 4 | BAT_ADC | AIN |
| 10 | HAPTIC_EN | OUT |
| 11 | LED_STATUS | OUT |
| 12 | PWR_BUTTON | IN (PU) |
| 13 | PWR_LED | OUT |
| 14 | BUTTON_USER | IN |
| 15 | TFT_POWER_ON | OUT |
| 43 | I²C SDA | OD |
| 44 | I²C SCL | OD |

### C.2 I²C 버스

| 장치 | 주소 | 클럭 |
|---|---|---|
| MCP3221 (압력 ADC) | 0x4D | 100 kHz |
| DRV2605L (햅틱) | 0x5A | 100 kHz |

### C.3 회로도

> 회로도 파일은 본 부록과 별도로 첨부 (Eagle/KiCad). 본 보고서 인쇄본에는 다음을 권장:
> - 전원 트리 다이어그램 (§3.2)
> - I²C 버스 결선도 (§3.4)
> - PB61412L 결선도 (§3.6)

### C.4 인클로저 도면

> 기계공 산출물. 3D 도면 + 사출 사양 별도 첨부.

---

## 부록 D. 화면 스크린샷 (placeholder)

> 보고서 인쇄본 작업 시 각 라우트의 실제 스크린샷을 첨부한다. 권장 캡쳐 목록:

### D.1 첫 실행 (5 화면)

- [ ] `/role-select` — 디바이스 / 동반자 선택
- [ ] `/onboarding` — 4 슬라이드 × 4 컷
- [ ] `/profile-setup`
- [ ] `/pimax-measure` — 7 단계 × 7 컷
- [ ] `/connect` — 스캔 / 페어링 / 성공 × 3 컷

### D.2 메인 (9 화면)

- [ ] `/` — 홈 (NoData / Up / Down 분기 × 3 컷)
- [ ] `/training-intro`
- [ ] `/training` — 호기 / 흡기 / 휴식 × 3 컷
- [ ] `/result`
- [ ] `/history`
- [ ] `/trend` — 일 / 주 / 월 / 년 × 4 컷
- [ ] `/profile`
- [ ] `/settings`
- [ ] `/settings/target`

### D.3 보조 (3 화면)

- [ ] `/guide`
- [ ] `/sleep-effect`
- [ ] `/sleep-trend`

### D.4 동반자 (3 화면)

- [ ] `/my-code` (디바이스)
- [ ] `/companion` (동반자)
- [ ] 동반자 코드 입력

### D.5 디바이스 LCD (8 화면)

- [ ] screen_boot
- [ ] screen_standby
- [ ] screen_pairwait
- [ ] screen_pairconnected
- [ ] screen_training (호기 / 흡기 / 휴식 × 3 컷)
- [ ] screen_rest
- [ ] screen_summary
- [ ] screen_charging

---

## 부록 E. 참고 문헌

### E.1 학술 / 임상

| 번호 | 인용 |
|---|---|
| [1] | Black LF, Hyatt RE. *Maximal respiratory pressures: normal values and relationship to age and sex*. Am Rev Respir Dis. 1969;99(5):696-702. |
| [2] | Bissett B, Leditschke IA, Green M, et al. *Inspiratory muscle training for intensive care patients: a multidisciplinary practical guide for clinicians*. Aust Crit Care. 2019;32(3):249-255. |
| [3] | Vranish JR, Bailey EF. *Inspiratory Muscle Training Improves Sleep and Mitigates Cardiovascular Dysfunction in Obstructive Sleep Apnea*. Sleep. 2016;39(7):1453-9. |
| [4] | 한국수면학회. *대한민국 성인의 수면 무호흡 유병률 조사*. Sleep Med Research. 2018. |

### E.2 산업 / 제품

| 번호 | 인용 |
|---|---|
| [5] | POWERbreathe International. *Clinical IMT Protocol — Sustainable Training Zone*. https://www.powerbreathe.com/ (Accessed 2026-04). |
| [6] | PN Medical. *The Breather — Respiratory Muscle Training Protocol*. https://www.pnmedical.com/ (Accessed 2026-04). |

### E.3 데이터시트

| 번호 | 자료 |
|---|---|
| [7] | NXP Semiconductors. *MPXV7007DP Datasheet*. Rev. 4, 2019. |
| [8] | Microchip. *MCP3221 12-Bit A/D Converter with I²C Interface Datasheet*. DS21732, 2007. |
| [9] | Texas Instruments. *DRV2605L Haptic Driver Datasheet*. SLOS854, 2018. |
| [10] | LILYGO. *T-Display-S3 Hardware Specification*. https://lilygo.cc/ (Accessed 2026-03). |

### E.4 라이브러리 / 프레임워크

| 자료 | 버전 |
|---|---|
| Flutter | ≥ 3.22.0 |
| Riverpod | 2.5.1 |
| flutter_blue_plus | 1.32.0 |
| Drift | 2.18.0 |
| go_router | 14.2.0 |
| LVGL | 9.x |
| TFT_eSPI | 2.5.43 |
| ESP32 Arduino Core | 3.x |
| PlatformIO | 6.x |

---

## 부록 F. 작품 시연 시나리오

### F.1 발표 시연 시퀀스 (5 분)

1. **앱 첫 실행** (1 분)
   - /role-select → /onboarding 짧게 swipe
   - /profile-setup 빠른 입력
2. **PImax / MEP 측정** (1 분)
   - 호기 측정 시연 → 흡기 측정 시연
   - "강도 자동 계산" 의 의미 강조
3. **페어링** (30 s)
   - 디바이스 ON → 자동 스캔 → 연결
4. **훈련 시연** (1.5 분)
   - /training-intro → /training
   - 호기 / 흡기 phase 전환 + 햅틱 cue 시연
   - 디바이스 LCD 동기 강조
5. **결과 + BreLow 캐릭터** (30 s)
   - /result → 홈 → happy 모션
   - 7 일 / 30 일 진화 설명 (모형)
6. **동반자 모드** (30 s)
   - 별도 폰에서 /companion → 코드 입력
   - 눈치주기 → 첫 폰에 알림 표시

### F.2 백업 시연 — FAKE_BLE

디바이스 미연결 / 페어링 실패 등 상황을 대비.

```bash
flutter run --dart-define=FAKE_BLE=true
```

`FakeBleManager` 가 sine wave 압력 패턴을 자동 발생 + 5 분 후 자동 Summary. 디바이스 없이 앱만으로 전체 흐름 시연 가능.

### F.3 시연 영상

발표 백업용 30 초 ~ 1 분 시연 영상을 사전 녹화 (개발 계획서 T3 참조).

---

*— 부록 끝 —*

---

# 마치며

본 보고서는 BRELOW 프로젝트의 v4.1 시점 (2026-06) 상태를 기록한다. 코드와 1:1 매핑되도록 작성되었으며, 향후 코드 변경 시 본 보고서 갱신이 함께 이루어져야 한다.

본 작품과 보고서가 호흡근 훈련 분야의 작은 진전이 되기를 바라며, 이 작업을 가능하게 해 준 한남대학교 디자인팩토리 CPD 와 협업한 모든 분께 감사를 전한다.

— BRELOW 팀
