# Firmware v4.0 — BlowFit (ESP32-S3)

Target: **LILYGO T-Display S3 Touch** (ESP32-S3R8, 듀얼코어 240MHz, 16MB Flash, 8MB PSRAM, 1.9" IPS 170×320, 정전식 터치) via Arduino IDE.

> v3.2 (XIAO BLE nRF52840) 펌웨어는 [`../firmware/`](../firmware/) 에 backup 으로 유지. 본 폴더는 v4.0 마이그레이션 작업 디렉토리.

## 하드웨어 변경 요약 (v3.2 → v4.0)

| 영역 | v3.2 | v4.0 |
|---|---|---|
| 보드 | XIAO BLE nRF52840 (64MHz) | **LILYGO T-Display S3 (ESP32-S3, 240MHz)** |
| 디스플레이 | ST7735 0.96" 별도 (SPI) | **일체형 1.9" IPS 170×320 (8-bit 병렬, ST7789V)** |
| 압력 센서 | XGZP6847A005KPG (양압 0~5 kPa) | **XGZP6847A010KPGPN33 (양방향 ±10 kPa = ±102 cmH₂O)** |
| GUI 라이브러리 | 직접 그림 (Adafruit_GFX) | **LVGL 9.x** |
| BLE | ArduinoBLE (mbed) | **ESP32 BLE Arduino / NimBLE** |
| Flash 영속화 | mbed BSP 미지원 → 미사용 | **NVS / LittleFS** (ESP32 native) |
| 가격 | 122,600원 | **104,600원** (-18,000원) |

## 1. Arduino IDE 설정

### 1.1 ESP32 보드 매니저 추가

File → Preferences → Additional Boards Manager URLs 에 추가:
```
https://espressif.github.io/arduino-esp32/package_esp32_index.json
```

Tools → Board → Boards Manager → `esp32 by Espressif Systems` 설치 (3.0+ 권장).

### 1.2 보드 선택

Tools → Board → ESP32 Arduino → **`Lilygo T Display S3`**

### 1.3 빌드 설정

| 항목 | 값 |
|---|---|
| Partition Scheme | 16M Flash (3MB APP / 9.9MB FATFS) |
| USB CDC On Boot | **Enabled** |
| Upload Speed | 921600 |
| PSRAM | OPI PSRAM |

## 2. 라이브러리 (Library Manager)

| 라이브러리 | 용도 |
|---|---|
| **TFT_eSPI** (Bodmer) | 1.9" IPS 디스플레이 드라이버 |
| **lvgl** (≥9.x) | GUI 위젯 (Arc, Bar, Label) |
| ESP32 BLE Arduino (보드 패키지 포함) | BLE GATT |
| Preferences (보드 패키지 포함) | NVS 영속화 |

### 2.1 TFT_eSPI 설정

`Arduino/libraries/TFT_eSPI/User_Setup_Select.h` 에서:
```c
//#include <User_Setup.h>          // 기본 비활성화
#include <User_Setups/Setup206_LilyGo_T_Display_S3.h>  // 이거 활성화
```

### 2.2 LVGL 9.x 설정

`Arduino/libraries/lvgl/src/lv_conf.h` 또는 `lv_conf_template.h` 복사 후 활성화:
```c
#define LV_COLOR_DEPTH 16
#define LV_TICK_CUSTOM 1
#define LV_USE_PERF_MONITOR 0
```

## 3. 핀 매핑 (LILYGO T-Display S3)

### 외부 부품 (사용자 배선)

| 핀 | 부품 | 비고 |
|---|---|---|
| GPIO4 (ADC1) | 압력 센서 OUT | 0.2~2.7V 아날로그 입력 |
| 3V3 | 압력 센서 VCC | XGZP6847A010KPGPN33 (3.3V 모델) |
| GND | 압력 센서 GND | |
| GPIO10 | 진동 모터 (PWM) | 목표 도달 시 진동 |
| GPIO11 | LED (선택) | 상태 표시 |

### 내장 핀 (수정 불가)

| 핀 | 용도 |
|---|---|
| GPIO5 | 디스플레이 RST |
| GPIO6 | 디스플레이 CS |
| GPIO7 | 디스플레이 DC |
| **GPIO15** | **백라이트 — 배터리 모드 시 HIGH 필수** ⚠️ |
| GPIO38 | 백라이트 PWM |
| GPIO39~48 | 디스플레이 데이터 (8-bit 병렬) |

## 4. 압력 센서 — XGZP6847A010KPGPN33

### 4.1 모델명 분석

```
XGZP6847 A 010 KP GPN 33
─────────────────────
시리즈: XGZP6847
A: Analog 출력
010: 압력 범위 숫자
KP: 단위 (kPa)
GPN: 양방향 (Gauge + Negative)
33: 3.3V 전원
```

### 4.2 변환 공식 (데이터시트 기준)

```cpp
// 12-bit ADC, 3.3V 기준
int adc = analogRead(4);
float voltage = adc * 3.3 / 4095;
float K = 0.125;  // -10~10 kPa, 3.3V 모델 K값
float kPa = (voltage - 1.45) / K;  // 1.45V = 0 압력 중심
float cmH2O = kPa * 10.197;
```

- 호기 (양압): voltage > 1.45V → cmH2O > 0
- 흡기 (음압): voltage < 1.45V → cmH2O < 0
- 정지: voltage ≈ 1.45V → cmH2O ≈ 0

### 4.3 영점 보정

부팅 후 첫 5초간 ADC 평균을 zeroOffsetCmH2O 로 저장. 사용자가 마우스피스 입에 물기 전 대기압 측정.

## 5. BLE GATT 서비스

[../docs/ble-protocol.md](../docs/ble-protocol.md) 참조 — 같은 UUID + payload 사용.

차이점:
- v3.2: int16 cmH2O × 10 양수만 사용 (0 ~ +500)
- v4.0: int16 cmH2O × 10 양/음 모두 사용 (-1020 ~ +1020)

프로토콜 자체는 호환 — 앱 측 별도 변경 불필요.

## 6. 폴더 구조 (계획)

```
firmware-esp32/
├── firmware-esp32.ino        스케치 진입점 + LVGL 메인 루프
├── config.h                  핀맵 + 상수 + enum
├── ble_uuids.h              UUID (v3.2 firmware/ble_uuids.h 와 동일)
├── sensor.{h,cpp}            압력 센서 + EMA + 영점 보정 (양방향)
├── ui_lvgl.{h,cpp}           LVGL 위젯 (Arc 게이지, 압력값, 정보 라벨)
├── state_machine.{h,cpp}     훈련 세션 상태·지표 (v3.2 와 거의 동일)
├── feedback.{h,cpp}          진동 + LED 패턴
├── ble_service.{h,cpp}       ESP32 BLE Arduino GATT
├── storage.{h,cpp}           NVS (Preferences) 세션 이력 + 설정
└── tests/                    호스트 g++ 단위 테스트 (v3.2 그대로 활용 가능)
```

## 7. 마이그레이션 작업 항목 (TODO)

| 항목 | 상태 | 메모 |
|---|---|---|
| Arduino IDE + ESP32 보드 매니저 설치 | ⏳ 보드 도착 후 | |
| TFT_eSPI Setup206 활성화 | ⏳ | LilyGo T-Display S3 |
| Hello World — USB-C 인식 + 화면 출력 | ⏳ | Phase 1 |
| 압력 센서 wiring + adcToCmH2O 검증 | ⏳ | Phase 2 |
| LVGL 메인 화면 (원형 게이지) | ⏳ | Phase 3 |
| BLE GATT — Pressure Stream + Session Control + State + Summary | ⏳ | Phase 4 |
| State machine 포팅 (firmware/ 에서 그대로) | ⏳ | Phase 4 |
| 케이스 통합 + 호흡 부품 + 누설 테스트 | ⏳ | Phase 5 |
| Flutter 앱 BLE 연결 검증 | ⏳ | Phase 6 |

## 8. 주요 학습 항목 (컴공 팀원)

| 영역 | 예상 학습 시간 |
|---|---|
| ESP32-S3 (Arduino IDE 보드 추가, 핀맵, GPIO15 백라이트) | 3~5일 |
| TFT_eSPI 라이브러리 (Setup206, 8-bit 병렬) | 2~3일 |
| LVGL 9.x (Arc, Bar, Label, 한국어 폰트, 애니메이션) | 1~2주 |
| ESP32 BLE Arduino (Service / Characteristic / Notify / Bonding) | 3~5일 |
| **합계** | **2~3주** |

## 9. 참고 자료

- LILYGO 공식 GitHub: https://github.com/Xinyuan-LilyGO/T-Display-S3
- TFT_eSPI: https://github.com/Bodmer/TFT_eSPI
- LVGL 공식 docs: https://docs.lvgl.io/9.0/
- ESP32 Arduino BLE: https://github.com/nkolban/ESP32_BLE_Arduino
- XGZP6847 데이터시트: CFSensor 공식 사이트
