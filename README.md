# BlowFit

[![CI](https://github.com/jaewon786/BlowFit/actions/workflows/ci.yml/badge.svg)](https://github.com/jaewon786/BlowFit/actions/workflows/ci.yml)

수면무호흡 개선용 호기 저항 훈련(PEP) 스마트 기기. 한남대학교 디자인팩토리 CPD 2026.

## 현재 진행 상황 (2026-04-25)

| 영역 | 상태 | 비고 |
|---|---|---|
| BLE 프로토콜 스펙 v1.0 | ✅ 확정 | [docs/ble-protocol.md](docs/ble-protocol.md) — FW/앱/시뮬 단일 진실 |
| BLE 시뮬레이터 | ✅ 동작 | `BlowFit-SIM` 광고, 20Hz 압력 Notify, 전체 opcode 처리 |
| 펌웨어 스캐폴드 | ✅ 코드 완료 | XIAO 배송 대기 (~5주차 도착 예정) |
| 펌웨어 상태머신 유닛 테스트 | ✅ CI 통과 | g++ 로 PC 빌드, 8개 케이스 |
| Flutter 앱 스캐폴드 | ✅ 동작 | Dashboard / Connect / Training / History |
| BLE 연결 + 디코더 | ✅ 구현 | 22B pressure / 32B summary 파싱 |
| Drift SQLite 세션 저장 | ✅ 구현 | `SessionSummary` 자동 영속화 |
| 12주 추세 History 화면 | ✅ 구현 | fl_chart 주간 평균 버킷 |
| GitHub Actions CI | ✅ green | Flutter analyze, ruff, 펌웨어 테스트 |
| 실기기 E2E 검증 | ⏳ 다음 | 시뮬+앱 수동 통합 테스트 |
| 펌웨어 하드웨어 bring-up | ⏳ 대기 | XIAO + 센서 도착 후 |

## 저장소 구조

```
BlowFit/
├── firmware/     nRF52840 펌웨어 (Arduino IDE)
├── app/          Flutter 앱 (Android/iOS)
├── tools/        BLE 시뮬레이터 등 개발 보조 스크립트
└── docs/         BLE 프로토콜, 캘리브레이션 절차 등
```

## 주요 기술 스택

- **펌웨어**: Arduino IDE, Seeed XIAO BLE nRF52840, C++
- **디스플레이**: ST7735 0.96" TFT (TFT_eSPI)
- **통신**: Bluetooth LE 5.0 (ArduinoBLE / flutter_blue_plus)
- **앱**: Flutter 3.x + Riverpod + Drift(SQLite) + fl_chart
- **BLE 시뮬레이터**: Python + `bless` (기기 배송 전 앱 개발 병렬화)

## 빠른 시작

### 1) 기기 없이 앱 개발하기 (권장, 4주차부터)

```bash
cd tools
pip install -r requirements.txt
python ble-sim.py
```

가상 BLE 페리페럴이 `BlowFit-SIM` 이름으로 광고됩니다. 앱에서 스캔 → 연결하면 실기기와 동일한 GATT 인터페이스로 모의 압력 파형이 스트리밍됩니다.

### 2) 펌웨어 개발

[firmware/README.md](firmware/README.md) 참조.

### 3) 앱 개발

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # Drift 코드 생성
flutter run
```

Drift 테이블 수정 시 `build_runner` 재실행 필수. 상세는 [app/README.md](app/README.md).

## 문서

- [BLE 프로토콜 스펙](docs/ble-protocol.md) — 펌웨어/앱 연동 계약
- [캘리브레이션 절차](docs/calibration.md)
- SW 개발 Ultraplan — 상위 CPD 프로젝트 문서

## 개발 원칙

1. **오프라인 우선**: 펌웨어는 앱 없이도 완전 동작
2. **계약 우선**: BLE 프로토콜 문서 먼저, 양측 구현은 그 다음
3. **9주차 수요일 Code Freeze**: 이후 버그 픽스만
4. **CI 그린 유지**: main 브랜치 머지 전 3개 잡 (Flutter / ruff / 펌웨어) 모두 통과

## 다음 단계

1. **시뮬레이터 E2E 검증** — `ble-sim.py` + 앱 연결, 세션 시작→종료→DB 저장→History 표시 수동 테스트
2. **Flutter 테스트 추가** — `SessionRepository` in-memory Drift 테스트, BLE 디코더 유닛 테스트
3. **앱 UX 갭** — Connect 화면 스캔 상태, 오리피스 선택 다이얼로그, Dashboard 실제 통계
