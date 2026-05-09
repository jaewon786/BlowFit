# 한남대학교 디자인팩토리 CPD 2026 팀 DoT

[![CI](https://github.com/jaewon786/BlowFit/actions/workflows/ci.yml/badge.svg)](https://github.com/jaewon786/BlowFit/actions/workflows/ci.yml)

수면무호흡·코골이 개선용 **저항(PEP) 훈련 스마트 디바이스** + Flutter 컴패니언 앱.
입에 물고 호흡하면 호흡근이 강화되고, 앱이 압력·지구력·연속 훈련 일수를 추적합니다.

---

## 주요 기능

- **펌웨어 (v4.0 마이그레이션 중)**: ESP32-S3 (LILYGO T-Display S3) + **양방향 차압 센서** (XGZP6847A010KPGPN33, ±102 cmH₂O) + 1.9" IPS 일체형, BLE 5.0 GATT, LVGL 9.x. (현재 코드는 v3.2 XIAO BLE nRF52840 기준 — `firmware-esp32/` 로 마이그레이션 진행)
- **앱**: 4탭 셸 (홈/기록/추이/프로필), 디자인 v2 (Pretendard + Wanted DS 토큰), Drift SQLite 영속화, 위젯·DB·pure 테스트 139 케이스
- **실시간 훈련**: BreathOrb 호흡 가이드 + 압력 그래프 + phase 별 배경, 세션 종료 후 점수·통계·코칭 노트 자동 생성
- **추이·마일스톤**: 일/주/월/년 4탭 + 5종 마일스톤 자동 감지 (첫 훈련, 7일 연속, 호기 20·25 cmH₂O 돌파, 30일 연속)

---

## 폴더 구조

```
BlowFit/
├── app/               Flutter 앱 (Android 우선, lib/ + test/)
│   ├── lib/core/      ble · db · coach · theme · storage
│   └── lib/features/  9개 화면 (onboarding/connect/dashboard/training/...)
├── firmware/          v3.2 펌웨어 — XIAO BLE nRF52840 (Arduino IDE, mbed BSP)
│   └── tests/         g++ 호스트 단위 테스트 (CI 통과)
├── firmware-esp32/    v4.0 펌웨어 — ESP32-S3 + LVGL (마이그레이션 중)
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
