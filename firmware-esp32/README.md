# Firmware v4.0 — BlowFit (ESP32-S3)

Target: **LILYGO T-Display S3** (ESP32-S3R8, 듀얼코어 240MHz, 16MB Flash, 8MB PSRAM, 1.9" IPS 170×320) — **PlatformIO** + Arduino framework.

화면 방향: **세로 (170 × 320)** — `setRotation(0)`.

> v3.2 (XIAO BLE nRF52840) 펌웨어는 [`../firmware/`](../firmware/) 에 backup 으로 유지. 본 폴더는 v4.0 마이그레이션 작업 디렉토리.

## 개발 흐름 (마일스톤)

| M | 내용 | 상태 |
|---|---|---|
| **M1** | PlatformIO 변환 + Setup206 + TFT_eSPI hello world | ✅ 현재 |
| M2 | LVGL 통합 (flush 콜백 + 더블 버퍼 + perf monitor) | ⏳ |
| M3 | 한글 폰트 (Pretendard subset) + theme tokens | ⏳ |
| M4 | screen_standby 정적 UI | ⏳ |
| M5 | screen_training + 압력 게이지 (시뮬레이션 입력) | ⏳ |
| M6 | 실 sensor 통합 | ⏳ |
| M7 | State machine + 화면 전환 | ⏳ |
| M8 | BLE GATT service | ⏳ |
| M9 | NVS + 영점 보정 화면 | ⏳ |
| M10 | 햅틱 / LED / 버튼 입력 | ⏳ |
| M11 | 폴리싱 + 전력 최적화 | ⏳ |

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

## 1. PlatformIO 빌드 환경

### 1.1 사전 설치

- **VSCode + PlatformIO IDE 확장** (가장 쉬움) 또는
- **PlatformIO Core CLI** (`pip install platformio`)

USB-Serial 드라이버는 ESP32-S3 의 USB-CDC 내장이라 별도 불필요 (Windows 가 자동 인식).

### 1.2 디렉토리 구조

```
firmware-esp32/
├── platformio.ini          ← 빌드 설정 (board, libs, build_flags)
├── lv_conf.h               ← LVGL 설정 (외부 파일 — LV_CONF_PATH 로 참조)
├── include/
│   ├── config.h            ← 핀맵 + 상수 + enum
│   └── sensor.h
├── src/
│   ├── main.cpp            ← setup() / loop()
│   └── sensor.cpp          ← 압력 센서 + EMA + 영점 보정
└── lib/
    └── TFT_eSPI_Setup/
        └── Setup206_LilyGo_T_Display_S3.h   ← TFT_eSPI 핀맵
```

### 1.3 빌드 / 업로드

```bash
cd firmware-esp32

pio run                     # 빌드
pio run -t upload           # 빌드 + USB 업로드
pio device monitor          # 시리얼 모니터 (115200)
pio run -t clean            # 클린

# VSCode: PlatformIO 좌측 사이드바의 Build / Upload / Monitor 버튼
```

### 1.4 사용 라이브러리 (`platformio.ini` 의 `lib_deps`)

| 라이브러리 | 버전 | 용도 |
|---|---|---|
| `bodmer/TFT_eSPI` | ^2.5.43 | 1.9" IPS 디스플레이 드라이버 (Setup206) |
| `lvgl/lvgl` | ^9.2.2 | GUI 위젯 (M2 이후) |

ESP32 BLE Arduino + Preferences 는 framework (arduino-esp32) 에 포함되어 별도 설치 불요.

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
| GPIO7 | 디스플레이 DC |
| GPIO8 | 디스플레이 WR (쓰기 strobe) |
| GPIO9 | 디스플레이 RD |
| **GPIO15** | **LDO 전원 enable — 배터리 모드 HIGH 필수** ⚠️ (`pins::TFT_POWER_ON`) |
| GPIO38 | 백라이트 PWM (TFT_eSPI 자동 제어) |
| GPIO39~48 | 디스플레이 데이터 (8-bit 병렬) |
| GPIO0 | 부트 버튼 (사용자 입력 활용 가능) |
| GPIO14 | 사용자 버튼 |

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

## 6. 폴더 구조 (M1 완료, 점진적 확장)

```
firmware-esp32/
├── platformio.ini              빌드 설정
├── lv_conf.h                   LVGL 설정 (M2~)
├── include/
│   ├── config.h                핀맵 + 상수 + enum + display::SCREEN_W/H (세로 170x320)
│   └── sensor.h
├── src/
│   ├── main.cpp                setup() / loop() — M1: TFT_eSPI hello world
│   ├── sensor.cpp              압력 센서 + EMA + 영점 보정 (양방향) — v3.2 그대로 포팅
│   ├── display/                (M2~) LVGL 통합 layer + 화면들
│   │   ├── lvgl_port.{h,cpp}
│   │   ├── theme.{h,cpp}
│   │   └── screens/
│   │       ├── screen_standby.{h,cpp}
│   │       ├── screen_calibrate.{h,cpp}
│   │       ├── screen_training.{h,cpp}
│   │       ├── screen_rest.{h,cpp}
│   │       └── screen_summary.{h,cpp}
│   ├── ble/                    (M8) BLE GATT service
│   │   ├── ble_service.{h,cpp}
│   │   └── ble_uuids.h
│   ├── state_machine.{h,cpp}   (M7) 훈련 세션 상태·지표 (v3.2 firmware/state_machine.cpp 포팅)
│   ├── feedback.{h,cpp}        (M10) 진동 + LED 패턴
│   └── storage.{h,cpp}         (M9) NVS (Preferences) 세션 이력 + 설정
└── lib/
    └── TFT_eSPI_Setup/
        └── Setup206_LilyGo_T_Display_S3.h   TFT_eSPI 핀맵 (build_flags 로 자동 include)
```

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
