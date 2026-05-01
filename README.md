# BlowFit

[![CI](https://github.com/jaewon786/BlowFit/actions/workflows/ci.yml/badge.svg)](https://github.com/jaewon786/BlowFit/actions/workflows/ci.yml)

수면무호흡 개선용 호기 저항 훈련(PEP) 스마트 기기. 한남대학교 디자인팩토리 CPD 2026.

## 현재 진행 상황 (2026-04-25)

| 영역 | 상태 | 비고 |
|---|---|---|
| BLE 프로토콜 스펙 v1.0 | ✅ 확정 | [docs/ble-protocol.md](docs/ble-protocol.md) — FW/앱/시뮬 단일 진실 |
| BLE 시뮬레이터 (Python) | ✅ 동작 | `BlowFit-SIM` 광고, 20Hz 압력 Notify, 전체 opcode |
| **In-process BLE Fake** | ✅ 신규 | `--dart-define=FAKE_BLE=true` 로 폰에서 단독 실행 |
| 펌웨어 모듈 구현 | ✅ 코드 완료 | state_machine / storage / feedback / button / power |
| 펌웨어 유닛 테스트 | ✅ CI 통과 | g++ 호스트 빌드, 4개 모듈 28 케이스 |
| Flutter 앱 화면 | ✅ 구현 | Dashboard / Connect / Training / History / **Settings** |
| BLE 디코더 (분리) | ✅ 구현 | [blowfit_codec.dart](app/lib/core/ble/blowfit_codec.dart) — 22B/32B 파싱 |
| BLE 시퀀스 갭 감지 | ✅ 구현 | [seq_gap_detector.dart](app/lib/core/ble/seq_gap_detector.dart) + degraded banner |
| Drift SQLite 영속화 | ✅ 구현 | `SessionSummary` 자동 저장, deviceSessionId 멱등 upsert |
| 12주 추세 + 페이징 | ✅ 구현 | 20개씩 "더 보기", fl_chart |
| 자동 재연결 | ✅ 구현 | 마지막 기기 ID SharedPreferences 캐시 |
| Settings 화면 | ✅ 구현 | 목표 압력대 슬라이더, 영점 보정 트리거 |
| 3세트/휴식 phase chip | ✅ 구현 | TrainingScreen 상단 진행도 dot |
| 배터리 부족 / BLE 손실 경고 | ✅ 구현 | Dashboard / Training 배너 |
| 권한 처리 (Android 12+) | ✅ 구현 | BLUETOOTH_SCAN/CONNECT, denied/permanent 분기 |
| 시스템 뒤로가기 / SafeArea | ✅ 구현 | go_router push 기반, 시스템 nav 회피 |
| GitHub Actions CI | ✅ green | analyze, ruff, 펌웨어 테스트, **APK 빌드** |
| 앱 테스트 커버리지 | ✅ 50 케이스 | unit + widget + integration |
| 실기기 E2E 검증 | ⏳ 대기 | XIAO + 센서 도착 후 |

## 저장소 구조

```
BlowFit/
├── firmware/     nRF52840 펌웨어 (Arduino IDE)
├── app/          Flutter 앱 (Android 우선)
├── tools/        BLE 시뮬레이터 (Python) + 압력 파형 검증
└── docs/         BLE 프로토콜, 캘리브레이션 절차 등
```

## 주요 기술 스택

- **펌웨어**: Arduino IDE, Seeed XIAO BLE nRF52840, C++17
- **디스플레이**: ST7735 0.96" TFT (TFT_eSPI)
- **통신**: Bluetooth LE 5.0 (ArduinoBLE / flutter_blue_plus)
- **앱**: Flutter 3.22+ · Riverpod · Drift(SQLite) · fl_chart · go_router · permission_handler · shared_preferences
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

- [개발 계획서 갭 분석 + 잔여 일정](docs/dev-plan.md) — 개발계획서 v3 vs 현재 코드 비교, 주차별 To-Do
- [UI 리디자인 계획 v2](docs/ui-redesign-plan.md) — 와이어프레임 6화면 적용을 위한 단계별 계획
- [BLE 프로토콜 스펙](docs/ble-protocol.md) — 펌웨어/앱 연동 계약
- [캘리브레이션 절차](docs/calibration.md)
- [앱 README](app/README.md) — Flutter 앱 빌드/구조/테스트
- [펌웨어 README](firmware/README.md) — Arduino 빌드 + 호스트 단위 테스트

## 개발 원칙

1. **오프라인 우선**: 펌웨어는 앱 없이도 완전 동작
2. **계약 우선**: BLE 프로토콜 문서 먼저, 양측 구현은 그 다음
3. **9주차 수요일 Code Freeze**: 이후 버그 픽스만
4. **CI 그린 유지**: main 브랜치 머지 전 4개 잡 (Flutter analyze/test, ruff, 펌웨어, Android APK) 모두 통과

## 다음 단계 (기기 도착 후 검증)

- 펌웨어 button.cpp 호스트 테스트 시드(`g_hostPressed`)가 ARDUINO 빌드에 영향 없는지 컴파일/플래시 확인
- TrainingScreen phase chip / 3세트 dot 이 실제 BLE deviceState 전이에서 정확히 그려지는지
- 세션 종료 후 SessionRepository 멱등 upsert (동일 sessionId 재전송 시 중복 row 없음)
- BLE 패킷 손실 시 [BleHealthBanner](app/lib/features/training/training_screen.dart) 가 트리거되는지
- 배터리 잔량 ≤20% 또는 `lowBattery` 플래그 시 경고 배너
- Android 12+ 권한 거부/영구거부 분기 (시스템 권한 다이얼로그 흐름)

## 다음 단계 (기기 없이도 가능)

- iOS 플랫폼 초기화 + Info.plist 권한 키 (현재 Android 만 빌드 검증)
- Firmware sensor.cpp 호스트 테스트 (EMA / ADC→cmH2O / 영점 보정)
- 코드 커버리지 리포트 (lcov + codecov)
- Korean/English i18n (현재 한국어 하드코딩)
- 첫 실행 온보딩 플로우
