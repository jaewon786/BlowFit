# BlowFit

수면무호흡 개선용 호기 저항 훈련(PEP) 스마트 기기. 한남대학교 디자인팩토리 CPD 2026.

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
flutter run
```

## 문서

- [BLE 프로토콜 스펙](docs/ble-protocol.md) — 펌웨어/앱 연동 계약
- [캘리브레이션 절차](docs/calibration.md)
- SW 개발 Ultraplan — 상위 CPD 프로젝트 문서

## 개발 원칙

1. **오프라인 우선**: 펌웨어는 앱 없이도 완전 동작
2. **계약 우선**: BLE 프로토콜 문서 먼저, 양측 구현은 그 다음
3. **9주차 수요일 Code Freeze**: 이후 버그 픽스만
