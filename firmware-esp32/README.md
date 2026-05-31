# Firmware v4.0 — BlowFit (ESP32-S3)

Target: **LILYGO T-Display S3** (ESP32-S3R8, 듀얼코어 240MHz, 16MB Flash, 8MB PSRAM, 1.9" IPS 170×320) — **PlatformIO** + Arduino framework.

화면 방향: **세로 (170 × 320)** — `setRotation(0)`.

## 현재 제품 구성 (BOM)

| 구성품 | 부품 | 비고 |
|---|---|---|
| 메인보드 / MCU | **LILYGO T-Display-S3** (ESP32-S3) | 일체형 1.9" IPS 170×320, USB-C, BLE 내장 |
| 압력 센서 | **MPXV7007DP** (MikroE Diff Press Click) | 양방향 차압 ±7 kPa(±71 cmH₂O), MCP3221 12-bit I²C ADC(0x4D) |
| 배터리 | **LiPo 400 mAh** | 보드 내장 충전/VBAT 모니터 회로 |
| 전원 버튼 | **PB61412L** | 외부 tact 스위치 + LED, deep-sleep wake (EXT0) |
| 햅틱 모터 | **코인형 ERM 진동 모터 (DC 3V)** | 목표 압력 도달/호흡 cue 시 피드백 |
| 햅틱 드라이버 | **DRV2605L** | SparkFun Qwiic Haptic Motor Driver, I²C(0x5A), EN=GPIO10, 모터=OUT+/OUT− |

> I²C 버스(SDA=GPIO43, SCL=GPIO44)에 MCP3221 ADC(0x4D)와 DRV2605L 햅틱(0x5A)이 함께 연결됨.
> ⚠️ 두 보드 모두 I²C 풀업을 가지고 있어 병렬 시 합성 저항이 과도하게 낮아짐 →
> SparkFun 보드의 풀업 제거 점퍼(`I2C`, clearable)를 잘라 한쪽만 남길 것.
> DRV2605L `EN` 핀은 HIGH 여야 동작(GPIO10), 효과 트리거는 I²C GO bit (internal trigger).

> v3.2 (XIAO BLE nRF52840) 펌웨어는 [`../firmware/`](../firmware/) 에 backup 으로 유지. 본 폴더는 v4.0 마이그레이션 작업 디렉토리.

## 개발 흐름 (마일스톤)

| M | 내용 | 상태 |
|---|---|---|
| M1 | PlatformIO 변환 + Setup206 + TFT_eSPI hello world | ✅ |
| M2 | LVGL 통합 (flush 콜백 + 더블 버퍼 + perf monitor) | ✅ |
| M3 | 한글 폰트 (Pretendard subset) + theme tokens | ✅ |
| M4 | screen_standby 정적 UI | ✅ |
| M5 | screen_training + 압력 게이지 (시뮬레이션 입력) | ✅ |
| M6 | 실 sensor 통합 | ✅ (MS1~MS4 단계로 확장) |
| M7 | State machine + 화면 전환 | ✅ |
| M8 | BLE GATT service + 본딩 + 자동 재연결 | ✅ |
| M9 | NVS + 영점 보정 화면 | ⏳ (영점 자동, 게인 캘리브는 선택) |
| M10 | 햅틱 / LED / 버튼 입력 | ⏳ |
| M11 | 폴리싱 + 전력 최적화 | ⏳ |

### MPXV7007 마이그레이션 (M6 확장, 2026-05 완료)

| MS | 내용 | 상태 |
|---|---|---|
| MS1 | 브랜치 분기 + plan doc + I²C 핀 정의 | ✅ |
| MS2 | I²C 스캔 sketch (tools/i2c_scan/) — `device @ 0x4D` 검출 | ✅ |
| MS3 | MCP3221 read sketch (tools/mcp3221_test/) — 호기/흡기 검증 | ✅ |
| MS4 | sensor.cpp Wire/I²C 교체 + 100kHz 안정화 | ✅ |
| MS5 | 전체 빌드 + LVGL 표시 (M7 lv_tick_set_cb fix 포함) | ✅ |
| MS6 | 영점 자동 보정 + saturation guard ±71 cmH₂O | ✅ |
| MS7 | state machine 사이클 + 호흡 그래프 시각화 | ✅ |
| MS8 | README + migration doc 정리 | ✅ |

자세한 내용은 [docs/mpxv7007_migration.md](docs/mpxv7007_migration.md).

## 하드웨어 변경 요약 (v3.2 → v4.0)

| 영역 | v3.2 | v4.0 |
|---|---|---|
| 보드 | XIAO BLE nRF52840 (64MHz) | **LILYGO T-Display S3 (ESP32-S3, 240MHz)** |
| 디스플레이 | ST7735 0.96" 별도 (SPI) | **일체형 1.9" IPS 170×320 (8-bit 병렬, ST7789V)** |
| 압력 센서 | XGZP6847A005KPG (양압 0~5 kPa) | **MikroE Diff Press Click — MPXV7007DP (±7 kPa) + MCP3221 12-bit I²C ADC** |
| GUI 라이브러리 | 직접 그림 (Adafruit_GFX) | **LVGL 9.2** + BlowFit.html 다크 테마 |
| BLE | ArduinoBLE (mbed) | **ESP32 BLE Arduino + 본딩 + autoConnect** |
| Flash 영속화 | mbed BSP 미지원 → 미사용 | **NVS / LittleFS** (ESP32 native) |
| 자동 재연결 | 매번 수동 | **앱: AppLifecycle observer + Foreground Service**, **펌웨어: BLE bonding** |
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

## 3. 핀 매핑 (LILYGO T-Display S3 + MikroE Diff Press Click)

### 외부 부품 (사용자 배선)

| 핀 | 부품 | 비고 |
|---|---|---|
| GPIO43 | Click SDA | I²C SDA (UART0 TX default — USB-CDC 모드라 free) |
| GPIO44 | Click SCL | I²C SCL (UART0 RX default) |
| 3V3 | Click 3V3 + Click 5V (분기 or 보드 위 short) | 단일 3.3V 레일 운용 (B1) |
| GND | Click GND | |
| GPIO10 | 햅틱 모터 EN/트리거 (DRV2605L) | DRV2605L I²C(0x5A) 경유 구동 (M10 예정) |
| GPIO11 | LED (선택) | 상태 표시 (M10 예정) |

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
| GPIO0 | 부트 버튼 (사용자 입력 활용 가능 — `pins::BUTTON_BOOT`) |
| GPIO14 | 사용자 버튼 (`pins::BUTTON_USER`) |

## 4. 압력 센서 — MikroE Diff Press Click (MPXV7007DP + MCP3221)

### 4.1 보드 구성

- **MPXV7007DP** (NXP): 차압 센서, ±7 kPa (≈ ±71 cmH₂O), ratiometric output
- **MCP3221A5T** (Microchip): 12-bit I²C ADC, 0x4D 주소 (JP1 = 3V3 위치)
- **JP1 (VCC SEL)**: MCP3221 VDD 선택 (3V3 위치 권장)
- **R2/R3 (4.7k 풀업)**: I²C SDA/SCL 풀업 (VCC = JP1 선택값)
- 자세한 회로 분석은 [docs/mpxv7007_migration.md §7](docs/mpxv7007_migration.md) 참조

### 4.2 전원 토폴로지 (Option B1)

```
T-Display 3V3 ──┬──→ Click 3V3 → MCP3221 VDD + I²C 풀업
                └──→ Click 5V  → MPXV7007 VCC (under-spec 3.3V 운용)
T-Display GND ────→ Click GND
T-Display GPIO43 ─→ Click SDA
T-Display GPIO44 ─→ Click SCL
```

총 4선 외부 배선. Click 보드 위에서 3V3 ↔ 5V 짧은 점퍼 와이어로 bridge.
schematic 확인 결과 **5V 핀에 3.3V 인가 손상 위험 0%** (LDO/op-amp 없음).

배터리 모드에서도 추가 boost converter 불필요 — T-Display 내장 LDO 가 그대로 3.3V 공급.

### 4.3 변환 공식 (ratiometric)

```cpp
// MCP3221 read: 12-bit unsigned, 2-byte
Wire.requestFrom(MCP3221_ADDR, 2);
uint8_t hi = Wire.read();
uint8_t lo = Wire.read();
uint16_t adc = ((hi & 0x0F) << 8) | lo;

// 변환 (ratiometric, Vs 무관)
float ratio = adc / 4095.0f;
float kPa = (ratio - 0.5f) / 0.057f;
float cmH2O = kPa * 10.197f;
```

- 호기 (양압): ratio > 0.5 → cmH₂O > 0
- 흡기 (음압): ratio < 0.5 → cmH₂O < 0
- 정지: ratio ≈ 0.5 → cmH₂O ≈ 0

### 4.4 영점 보정 + saturation

부팅 후 첫 200 sample × 10ms = 2초 평균을 `zeroOffset` 으로 저장. 실측 자연
offset ≈ 2.09 cmH₂O (under-spec 3.3V Vs 운용 시 정상 범위).

`adcToCmH2O()` 내부에서 ±71 cmH₂O 로 clamp (MPXV7007 풀스케일 보수적 한계).

### 4.5 I²C 안정화

`sensor::readMcp3221()` — 5회 retry + 2ms 사이 delay. BLE/LVGL task 와의
일시적 timing 충돌 흡수. I²C frequency 100 kHz (standard-mode) — 400 kHz
Fast-mode 도 가능하지만 본 펌웨어 환경엔 100 kHz 가 더 안정.

## 5. BLE GATT 서비스

[../docs/ble-protocol.md](../docs/ble-protocol.md) 참조 — 같은 UUID + payload 사용.

차이점:
- v3.2: int16 cmH2O × 10 양수만 사용 (0 ~ +500)
- v4.0: int16 cmH2O × 10 양/음 모두 사용 (-1020 ~ +1020)

프로토콜 자체는 호환 — 앱 측 별도 변경 불필요.

## 6. 폴더 구조

```
firmware-esp32/
├── platformio.ini              빌드 설정
├── include/
│   ├── config.h                핀맵 + 상수 + enum + display::SCREEN_W/H
│   ├── lv_conf.h               LVGL 설정
│   ├── sensor.h                압력 센서 API
│   ├── session.h               state machine API
│   ├── ble_service.h           BLE GATT service API
│   └── ble_uuids.h             BLE UUID 단일 출처
├── src/
│   ├── main.cpp                setup() / loop() — state machine + sensor + BLE 통합
│   ├── sensor.cpp              MCP3221 I²C read + EMA + 영점 + saturation
│   ├── session.cpp             state machine (Boot/Standby/Prep/Train/Rest/Summary)
│   ├── ble_service.cpp         BLE GATT — Pressure Stream / Session Control / State / Summary + 본딩
│   └── display/
│       ├── lvgl_port.{h,cpp}   LVGL ↔ TFT_eSPI bridge + lv_tick_set_cb
│       ├── theme.h             색상 토큰 (DEV_* 다크 테마)
│       ├── fonts/              Pretendard 한글 subset (14/20/28pt)
│       └── screens/
│           ├── screen_boot.{h,cpp}             부팅 화면 (logo + spinner)
│           ├── screen_pairwait.{h,cpp}         BLE 페어링 대기
│           ├── screen_pairconnected.{h,cpp}    BLE 연결 완료
│           ├── screen_standby.{h,cpp}          훈련 준비 (READY chip)
│           ├── screen_training.{h,cpp}         세로 양방향 bar + 압력값
│           ├── screen_rest.{h,cpp}             REST chip + Arc 카운트다운
│           └── screen_summary.{h,cpp}          green Arc + 호기/흡기 평균
├── tools/                      Standalone 검증 sketches
│   ├── i2c_scan/               I²C 버스 스캐너 (MS2)
│   └── mcp3221_test/           MCP3221 단독 read + 호흡 검증 (MS3)
├── docs/
│   └── mpxv7007_migration.md   MPXV7007 마이그레이션 plan + 결과
└── lib/
    └── TFT_eSPI_Setup/
        └── Setup206_LilyGo_T_Display_S3.h     TFT_eSPI 핀맵 (build_flags 로 자동 include)
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

- LILYGO T-Display S3: https://github.com/Xinyuan-LilyGO/T-Display-S3
- TFT_eSPI: https://github.com/Bodmer/TFT_eSPI
- LVGL 9.x docs: https://docs.lvgl.io/9.0/
- ESP32 Arduino BLE: https://github.com/nkolban/ESP32_BLE_Arduino
- MikroE Diff Press Click: https://www.mikroe.com/diff-press-click
- MPXV7007DP datasheet: https://download.mikroe.com/documents/datasheets/MPXV7007.pdf
- Diff Press Click schematic: https://download.mikroe.com/documents/add-on-boards/click/diff-press/diff-press-schematic-v100.pdf
- MCP3221 datasheet (Microchip): https://www.microchip.com/en-us/product/MCP3221
