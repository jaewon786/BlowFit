# BlowFit

[![CI](https://github.com/jaewon786/BlowFit/actions/workflows/ci.yml/badge.svg)](https://github.com/jaewon786/BlowFit/actions/workflows/ci.yml)

수면무호흡 개선용 호기 저항 훈련(PEP) 스마트 기기. 한남대학교 디자인팩토리 CPD 2026.

## 현재 진행 상황 (2026-05-03)

| 영역 | 상태 | 비고 |
|---|---|---|
| BLE 프로토콜 스펙 v1.0 | ✅ 확정 | [docs/ble-protocol.md](docs/ble-protocol.md) — FW/앱/시뮬 단일 진실 |
| BLE 시뮬레이터 (Python) | ✅ 동작 | `BlowFit-SIM` 광고, 20Hz 압력 Notify, 전체 opcode |
| In-process BLE Fake | ✅ 동작 | `--dart-define=FAKE_BLE=true` 로 폰에서 단독 실행 |
| 펌웨어 모듈 구현 | ✅ 코드 완료 | state_machine / storage / feedback / button / power / sensor / ui_tft |
| 펌웨어 유닛 테스트 | ✅ CI 통과 | g++ 호스트 빌드, 4개 모듈 28 케이스 |
| **디자인 v2 (Claude Design 핸드오프) 적용** | ✅ 완료 | 9개 화면 + Pretendard 폰트 + 디자인 토큰 |
| **실데이터 연동 (Phase A + B)** | ✅ 완료 | Trend / Profile / Dashboard / Result / SessionDetail 모든 placeholder 제거 |
| 4탭 메인 셸 | ✅ 동작 | 홈 / 기록 / 추이 / 프로필 (StatefulShellRoute) |
| 온보딩 + 프로필 설정 | ✅ 동작 | 4 step + 이름/나이/성별 입력 |
| Connect 화면 | ✅ 디자인 v2 | 페어링 펄스 / 통합 레이아웃 / 친화 에러 메시지 |
| Training (시작 전 + 실시간) | ✅ 디자인 v2 | TrainingIntro + BreathOrb + phase 별 배경 |
| Trend 4탭 (일/주/월/년) | ✅ 동작 | 윈도우별 동적 라벨 + Z안 (활성 데이터 < 2 면 변화율 숨김) |
| Result 화면 | ✅ 디자인 v2 | 점수 hero + 4 stat + 코칭 노트 (CoachingEngine) |
| Profile 화면 | ✅ 디자인 v2 | 빈 프로필 CTA + 자동 N주차 + firstSessionStats |
| BLE 디코더 (분리) | ✅ 구현 | [blowfit_codec.dart](app/lib/core/ble/blowfit_codec.dart) — 22B/32B 파싱 |
| BLE 시퀀스 갭 감지 | ✅ 구현 | [seq_gap_detector.dart](app/lib/core/ble/seq_gap_detector.dart) + degraded banner |
| BLE 에러 친화 메시지 | ✅ 구현 | [ble_error_translator.dart](app/lib/core/ble/ble_error_translator.dart) — 6개 카테고리 분류 |
| Drift SQLite 영속화 | ✅ 구현 | `SessionSummary` 자동 저장, deviceSessionId 멱등 upsert |
| MilestoneEngine | ✅ 구현 | 5종 마일스톤 (첫 훈련/7일/호기 20/30일/호기 25) |
| CoachingEngine | ✅ 구현 | Dashboard 위클리 + Result 노트 + 점수 메시지 |
| 자동 재연결 | ✅ 구현 | 마지막 기기 ID SharedPreferences 캐시 |
| Settings 화면 | ✅ 구현 | 목표 압력대 슬라이더, 영점 보정 트리거 |
| 권한 처리 (Android 12+) | ✅ 구현 | BLUETOOTH_SCAN/CONNECT, denied/permanent 분기 |
| GitHub Actions CI | ✅ green | analyze, ruff, 펌웨어 테스트, APK 빌드 |
| **앱 테스트 커버리지** | ✅ **139 케이스** | 16개 파일 — pure helpers + DB + 위젯 |
| 실기기 E2E 검증 | ⏳ 진행 중 | XIAO + 센서 도착 후 |

## 저장소 구조

```
BlowFit/
├── firmware/     nRF52840 펌웨어 (Arduino IDE)
├── app/          Flutter 앱 (Android 우선)
├── tools/        BLE 시뮬레이터 (Python) + 압력 파형 검증
└── docs/         BLE 프로토콜, 캘리브레이션, 디자인 v2 적용 등
```

## 주요 기술 스택

- **펌웨어**: Arduino IDE (mbed BSP), Seeed XIAO BLE nRF52840, C++17
- **디스플레이**: ST7735 0.96" TFT (Adafruit_ST7735 — TFT_eSPI 대신, mbed BSP 호환)
- **센서**: XGZP6847A005KPG (5V 차압, 0.5–4.5V → 0–5 cmH₂O / 약압 감지 후 보정)
- **통신**: Bluetooth LE 5.0 (ArduinoBLE / flutter_blue_plus)
- **앱**: Flutter 3.32+ · Riverpod · Drift(SQLite) · fl_chart · go_router · permission_handler · shared_preferences · Pretendard 폰트
- **테스트**: g++ 호스트 빌드 (펌웨어), `flutter_test` + `drift/native` 인메모리 (앱)

## 빠른 시작

### 1) 폰만으로 앱 체험 (FakeBleManager 모드)

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=FAKE_BLE=true
```

폰 안에서 가짜 BlowFit 디바이스가 광고됨. 7.4초 호흡 사이클, 30초 자동 정지.
Python 시뮬레이터 / 실기기 모두 필요 없음. 자세한 테스트 시나리오는 [app/README.md](app/README.md) 참조.

### 2) 별도 PC를 시뮬레이터로 (FAKE_BLE 없이)

```bash
cd tools
pip install -r requirements.txt
python ble-sim.py     # PC 가 실제 BLE 페리페럴로 광고
```

다른 PC/폰에서 일반 빌드(`flutter run`)로 스캔·연결 — 실기기와 동일한 GATT 인터페이스.

### 3) 펌웨어 개발

[firmware/README.md](firmware/README.md) 참조. 호스트 PC 에서 단위 테스트:

```bash
bash firmware/tests/run_all.sh
```

## 문서

- [개발 계획서 잔여 일정](docs/dev-plan.md) — 주차별 To-Do, 갭 분석 (8~10주차)
- [디자인 v2 + 실데이터 연동 적용 내역](docs/design-v2.md) — Claude Design 핸드오프 + Phase A/B 작업 정리
- [BLE 프로토콜 스펙](docs/ble-protocol.md) — 펌웨어/앱 연동 계약
- [캘리브레이션 절차](docs/calibration.md)
- [UI 리디자인 v2 (와이어프레임)](docs/ui-redesign-plan.md) — 4탭 셸 도입 단계 (1차 리디자인, 완료)
- [앱 README](app/README.md) — Flutter 앱 빌드/구조/테스트
- [펌웨어 README](firmware/README.md) — Arduino 빌드 + 호스트 단위 테스트

## 사용 흐름 (앱)

```
온보딩 4 step → 프로필 설정 (이름/나이/성별) → 기기 연결 (페어링) → 홈
                                                                ├─ 지금 훈련 시작
                                                                │   └→ 시작 전 (체크리스트) → 실시간 훈련 → 결과
                                                                ├─ 기록 (캘린더 + 최근 세션)
                                                                ├─ 추이 (일/주/월/년 4탭 + 마일스톤)
                                                                └─ 프로필 (베이스라인 + 설정)
```

## 개발 원칙

1. **오프라인 우선**: 펌웨어는 앱 없이도 완전 동작
2. **계약 우선**: BLE 프로토콜 문서 먼저, 양측 구현은 그 다음
3. **9주차 수요일 Code Freeze**: 이후 버그 픽스만
4. **CI 그린 유지**: main 브랜치 머지 전 4개 잡 (Flutter analyze/test, ruff, 펌웨어, Android APK) 모두 통과

## 다음 단계 (기기 도착 후 검증)

- 펌웨어 button.cpp 호스트 테스트 시드(`g_hostPressed`)가 ARDUINO 빌드에 영향 없는지 컴파일/플래시 확인
- TrainingScreen phase chip / BreathOrb 가 실제 BLE deviceState 전이에서 정확히 그려지는지
- 세션 종료 후 SessionRepository 멱등 upsert (동일 sessionId 재전송 시 중복 row 없음)
- BLE 패킷 손실 시 [degraded banner](app/lib/features/training/training_screen.dart) + DeviceStatusCard "신호 약함" 트리거 확인
- 배터리 잔량 ≤20% 또는 `lowBattery` 플래그 시 경고 + DeviceStatusCard "배터리" 빨강 처리
- Android 12+ 권한 거부/영구거부 분기 (시스템 권한 다이얼로그 흐름 + BleErrorTranslator 카테고리)

## 다음 단계 (기기 없이도 가능)

- 훈련 알림 / 자동 추천 토글 실구현 (현재 "곧 출시" 표시)
- iOS 플랫폼 초기화 + Info.plist 권한 키 (현재 Android 만 빌드 검증)
- Firmware sensor.cpp 호스트 테스트 (EMA / ADC→cmH2O / 영점 보정)
- Korean/English i18n (현재 한국어 하드코딩)
- 펌웨어 Metrics payload 에 `setIndex` 추가 → 실시간 훈련 화면 "세트 N/3" 동적
