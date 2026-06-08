# 제 2 장  시스템 개요

> 본 장은 BRELOW 의 전체 시스템 아키텍처, 사용자 시나리오, 그리고 한 페이지 분량의 기능 인벤토리를 제공한다. 이후 장들은 본 장의 각 블록을 상세 기술한다.

---

## 2.1 시스템 아키텍처

그림 2.1 — BRELOW 의 5-layer 아키텍처.

```
┌─────────────────────────────────────────────────────────────────┐
│                         사용자 / 동반자                          │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│   동반자 폰 (Android · Flutter · 동반자 모드)                    │
│   └─ /companion 화면 · 눈치주기 · 세션 카드                       │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ Firebase (Firestore + Auth)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│   사용자 폰 (Android · Flutter · 디바이스 모드)                  │
│   └─ /home /training /history /trend /profile /settings ...     │
│   └─ Drift DB · SharedPreferences · Samsung Health SDK          │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ BLE 5.0 (GATT, 100 Hz pressure stream)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│   BRELOW 디바이스 (ESP32-S3 펌웨어)                              │
│   └─ State machine · 4-phase Turn · %PImax target · LCD · 햅틱   │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ I²C
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│   하드웨어                                                       │
│   └─ MPXV7007DP 차압 센서 · MCP3221 ADC · DRV2605L 햅틱 ·         │
│      LiPo 배터리 · LCD · 마우스피스 · 오리피스 디스크              │
└─────────────────────────────────────────────────────────────────┘
```

### 2.1.1 계층별 책임

표 2.1 — 5-layer 별 책임.

| Layer | 책임 | 본 보고서 |
|---|---|---|
| 하드웨어 | 압력 측정, 햅틱 출력, 디스플레이, 배터리 | §3 |
| 펌웨어 | 측정값 처리, 세션 state machine, BLE 서비스, LCD UI | §4 |
| 통신 | BLE GATT (5 char, 6 opcode) | §5 |
| 앱 | 사용자 UX, 영속 데이터, 게이미피케이션, 코칭 | §7 |
| 클라우드 | 동반자 모드 데이터 공유 (Firestore) | §9 |

### 2.1.2 외부 의존성

- **Firebase** — 익명 인증 + Firestore (동반자 모드 전용)
- **Samsung Health Data SDK** — 수면 / SpO₂ / 무호흡 징후 (선택 사용)

두 의존성 모두 **선택** 이다. Firebase 미연결 시 디바이스 사용자는 동반자 기능을 제외한 모든 기능을 정상 사용할 수 있다.

---

## 2.2 사용자 시나리오

### 2.2.1 페르소나

표 2.2 — BRELOW 의 2 페르소나.

| 페르소나 | 설명 | 주된 사용 화면 |
|---|---|---|
| **디바이스 사용자** | 수면 무호흡 / 호흡근 약화 개선이 필요한 본인 | 홈 / 훈련 / 기록 / 추이 / 프로필 / 설정 |
| **동반자** | 사용자의 배우자 / 가족. 응원과 격려를 통해 동기 부여 | /companion |

### 2.2.2 시나리오 1 — 디바이스 사용자의 첫 사용

```
1. 앱 설치 → 첫 실행
2. /role-select → "디바이스 사용자" 선택
3. /onboarding 4 단계 슬라이드
4. /profile-setup → 이름·나이·성별 입력
5. /pimax-measure → 호기 측정 5 s → 흡기 측정 5 s → 강도 자동 계산
6. /connect → BLE 페어링 (BRELOW 디바이스 전원 ON)
7. 자동으로 BLE SET_TARGET v4.1 전송 (계산된 PImax/MEP 펌웨어로)
8. / (홈) 진입
```

### 2.2.3 시나리오 2 — 매일의 훈련

```
1. 디바이스 전원 ON (PB61412L 3 초 hold = wake gate)
2. 앱이 자동 재연결 (foreground service)
3. 홈 → "훈련하기" → /training-intro → /training
4. 디바이스 LCD 가 측정 화면으로 전환 + 햅틱 cue
5. 10 호흡 × 2 set (약 5.5 분)
6. Summary 자동 → /result
7. 결과 저장 → 홈으로 복귀
8. BreLow 캐릭터가 happy 모션 1 회 재생
9. 7 / 30 일 누적 시 진화 (bloom 모션 후 다음 단계)
```

### 2.2.4 시나리오 3 — 동반자의 응원

```
1. 디바이스 사용자가 /my-code 에서 6 자리 코드 발급
2. 동반자에게 코드 전달 (메신저 등)
3. 동반자가 별도 앱 설치 → /role-select → "동반자" 선택
4. 코드 입력 → Firestore links/{companionUid} 생성
5. 디바이스 사용자가 훈련하면 → Firestore users/{uid}/sessions
   에 백필 → 동반자에게 실시간 알림
6. 동반자가 "눈치주기" 버튼 → 디바이스 사용자 폰에 시스템 알림
```

---

## 2.3 기능 인벤토리 (한 페이지 요약)

### 2.3.1 디바이스 (펌웨어)

| 카테고리 | 기능 | 구현 위치 |
|---|---|---|
| 측정 | 100 Hz 차압 측정 + EMA 필터 + 영점 보정 + ±71 saturation | `sensor.cpp` |
| 세션 | 6-state machine + 4-phase Turn cycle + cycle offset | `session.cpp` |
| 통신 | GATT 5 char + 6 opcode (legacy + v4.1 clinical) | `ble_service.cpp` |
| UI | LVGL 9 화면 + status bar | `display/screens/` |
| 햅틱 | DRV2605L 6 효과 (start/exhale/inhale/rest/done/power) | `haptic.cpp` |
| 전원 | Deep sleep (~10 μA) + wake gate 3 s hold | `power.cpp` |
| 배터리 | VBAT 측정 + LiPo 방전곡선 + 충전 감지 | `battery.cpp` |
| 영속 | NVS — sessionId, 영점 offset, 강도 설정 | Preferences |

### 2.3.2 앱 (Flutter)

| 카테고리 | 기능 | 구현 위치 |
|---|---|---|
| BLE | 추상 매니저 + 실/가짜 구현 + 자동 재연결 + foreground service | `core/ble/` |
| 영속 (DB) | Sessions / SleepRecords (Drift schema v4) | `core/db/` |
| 영속 (KV) | UserProfile / PimaxMep / TrainDuration / TargetSettings / CharacterStage / LastDevice / Role | `core/storage/` |
| 코칭 | GrowthMessage + MilestoneEngine + CoachingEngine | `core/coach/` |
| 동반자 | Firestore 연결 코드 + 데이터 공유 + 눈치주기 | `core/pairing/` |
| 수면 | Samsung Health Data SDK + SleepSync + SleepAnalysis | `core/health/` |
| 알림 | flutter_local_notifications + Foreground Service 알림 | `core/notifications/` |
| 캐릭터 | Rive 3 단계 진화 (Egg → Baby → Oxygen) | `features/dashboard/widgets/brelow_character*.dart` |
| 디자인 | Pretendard 5 weight + BlowfitColors + 공통 위젯 | `core/theme/` |

### 2.3.3 화면 수

| 그룹 | 화면 수 |
|---|---|
| 첫 실행 | 5 |
| 메인 셸 (4 탭) | 4 + 5 (홈 sub) = 9 |
| 보조 (가이드/수면) | 3 |
| 동반자 | 3 |
| 개발용 | 1 |
| **합계** | **21** |

---

## 2.4 본 보고서 이후 장 매핑

표 2.3 — 본 시스템 개요 ↔ 상세 장.

| 본 장의 블록 | 상세 |
|---|---|
| 하드웨어 (3.1) | **제 3 장** 하드웨어 설계 |
| 펌웨어 (3.1) | **제 4 장** 펌웨어 설계 |
| BLE 통신 (3.1) | **제 5 장** 통신 프로토콜 |
| 임상 알고리즘 | **제 6 장** 임상 근거 |
| 앱 (3.1) | **제 7 장** 앱 설계 |
| 영속 데이터 (3.2) | **제 8 장** 데이터 관리 |
| 동반자 모드 (3.3) | **제 9 장** 동반자 모드 |

---

*— 제 2 장 끝 —*
