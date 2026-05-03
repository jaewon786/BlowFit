# BlowFit

[![CI](https://github.com/jaewon786/BlowFit/actions/workflows/ci.yml/badge.svg)](https://github.com/jaewon786/BlowFit/actions/workflows/ci.yml)

수면무호흡·코골이 개선용 **호기 저항(PEP) 훈련 스마트 디바이스** + Flutter 컴패니언 앱.
입에 물고 약 13분 호흡하면 호흡근이 강화되고, 앱이 압력·지구력·연속 훈련 일수를 추적합니다.

<!-- TODO: docs/images/hero.png — 앱 + 디바이스 한 장짜리 사진 또는 30초 GIF -->
![Hero placeholder](docs/images/hero.png)

**누구를 위한 저장소인가**
- 한남대학교 디자인팩토리 CPD 2026 BlowFit 팀 (개발·발표 협업)
- 호흡근 훈련 효과를 직접 검증하려는 외부 베타 사용자 (FAKE_BLE 모드 = 기기 불필요)
- BLE 페리페럴 + 차압 센서 + Flutter 앱 통합 사례를 찾는 개발자

---

## 5분 Quick Start (폰 하나로 시연)

기기 없이 폰 안의 가짜 BLE 디바이스로 전체 흐름을 체험합니다. Flutter 3.32+ 필요.

```bash
git clone https://github.com/jaewon786/BlowFit.git
cd BlowFit/app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=FAKE_BLE=true
```

폰 안에서 `BlowFit-SIM (fake)` 가 광고됨 → 페어링 → 7.4초 호흡 사이클 합성 파형 30초 자동 종료.

> 실기기 / Python 시뮬레이터 / Android 권한 등 자세한 빌드 모드는 [`app/README.md`](app/README.md).

---

## 주요 기능

- **펌웨어**: nRF52840 + 차압 센서 100Hz 샘플링, BLE 5.0 GATT (22B/패킷, 4종 char), 호스트 g++ 단위 테스트 28 케이스
- **앱**: 4탭 셸 (홈/기록/추이/프로필), 디자인 v2 (Pretendard + Wanted DS 토큰), Drift SQLite 영속화, 위젯·DB·pure 테스트 139 케이스
- **실시간 훈련**: BreathOrb 호흡 가이드 + 압력 그래프 + phase 별 배경, 세션 종료 후 점수·통계·코칭 노트 자동 생성
- **추이·마일스톤**: 일/주/월/년 4탭 + 5종 마일스톤 자동 감지 (첫 훈련, 7일 연속, 호기 20·25 cmH₂O 돌파, 30일 연속)
- **기기 없는 데모**: `FAKE_BLE=true` in-process 디바이스 + Python 시뮬레이터 양쪽 지원 → 발표·CI·신규 기여자 온보딩 모두 동일 코드 경로

---

## 폴더 구조

```
BlowFit/
├── app/               Flutter 앱 (Android 우선, lib/ + test/)
│   ├── lib/core/      ble · db · coach · theme · storage
│   └── lib/features/  9개 화면 (onboarding/connect/dashboard/training/...)
├── firmware/          nRF52840 펌웨어 (Arduino IDE)
│   └── tests/         g++ 호스트 단위 테스트 (CI 통과)
├── tools/             Python BLE 시뮬레이터 + 압력 파형 검증
└── docs/              프로토콜 · 디자인 · 운영 SOP · 잔여 일정
    └── archive/       (히스토리)
```

---

## 자세한 문서

| 문서 | 내용 |
|---|---|
| [`app/README.md`](app/README.md) | 앱 빌드 모드 3종, lib/ 구조, 테스트 16 파일 139 케이스, 권한 |
| [`firmware/README.md`](firmware/README.md) | Arduino IDE 설정, Adafruit_ST7735 핀맵, 호스트 g++ 테스트 |
| [`tools/README.md`](tools/README.md) | Python BLE 시뮬레이터 실행 + nRF Connect 검증 |
| [`docs/ble-protocol.md`](docs/ble-protocol.md) | BLE GATT 스펙 v1.0 (펌웨어·앱 단일 진실) |
| [`docs/design-v2.md`](docs/design-v2.md) | 현재 디자인 시스템 + Phase A/B 데이터 wiring 상세 |
| [`docs/calibration.md`](docs/calibration.md) | 부팅 영점·수동 재보정·공장 보정 SOP |
| [`docs/dev-plan.md`](docs/dev-plan.md) | 잔여 일정·작업 트래킹·갭 분석·리스크 (PM) |
| [`docs/archive/ui-redesign-v1.md`](docs/archive/ui-redesign-v1.md) | 1차 UI 리디자인 아카이브 (4탭 셸 도입, design-v2 로 대체됨) |

---

## 기여하기

- **계약 우선**: BLE 프로토콜 변경은 [`docs/ble-protocol.md`](docs/ble-protocol.md) 먼저 갱신 → 펌웨어/앱 양측 PR 리뷰
- **CI 그린 유지**: `flutter analyze`, `flutter test`, 펌웨어 호스트 테스트, Android APK 빌드 4잡 모두 통과
- **테스트 우선**: pure helper 는 단위 테스트, BLE/DB 는 in-memory Drift, 화면은 widget test
- **9주차 수요일 Code Freeze**: 이후 critical bug fix만

라이선스는 미정 (CPD 2026 산학 협력 결과물).
