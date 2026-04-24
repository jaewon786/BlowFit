# Firmware — BlowFit

Target: **Seeed XIAO BLE nRF52840** via Arduino IDE.

## 설정 (3주차 필수 완료)

### 1. Arduino IDE 설치
Arduino IDE 2.x 권장.

### 2. 보드 매니저
File → Preferences → Additional Boards Manager URLs 에 추가:
```
https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
```
Tools → Board → Boards Manager → `Seeed nRF52 mbed-enabled Boards` 설치.

Tools → Board → `Seeed XIAO nRF52840 (Sense)` 선택 (non-Sense 도 가능).

### 3. 라이브러리 (Library Manager)
- **ArduinoBLE** (Arduino 공식)
- **TFT_eSPI** (Bodmer)
- **Adafruit_LittleFS**, **InternalFileSystem** (Seeed 보드 패키지에 포함)

### 4. TFT_eSPI 설정
`Arduino/libraries/TFT_eSPI/User_Setup.h` 를 수정해야 한다. 편의를 위해 본 저장소 `firmware/TFT_eSPI_User_Setup.h` (추후 추가 예정) 를 라이브러리 폴더에 복사.

ST7735 80×160 세로 설정 핵심:
```c
#define ST7735_DRIVER
#define TFT_WIDTH  80
#define TFT_HEIGHT 160
#define ST7735_GREENTAB160x80

#define TFT_MOSI 10   // XIAO D10
#define TFT_SCLK 8    // XIAO D8
#define TFT_CS    4   // XIAO D4
#define TFT_DC    5   // XIAO D5
#define TFT_RST   6   // XIAO D6

#define LOAD_GLCD
#define LOAD_FONT2
#define SPI_FREQUENCY 27000000
```

## 빌드 & 업로드

1. `firmware/firmware.ino` 더블클릭으로 스케치 열기 (폴더 이름과 일치 필요)
2. USB-C 케이블로 XIAO 연결
3. 첫 업로드 시 리셋 버튼을 두 번 빠르게 눌러 부트로더 진입
4. ✓ 컴파일 → → 업로드

## 시리얼 디버그

Tools → Serial Monitor 115200 baud. `Serial.print` 로 압력값/상태 확인.

## 주차별 마일스톤

| 주 | 목표 |
|---|---|
| 3 | Blink 업로드, 시리얼 출력, ADC 읽기 |
| 4 | `sensor::adcToCmH2O` 검증, EMA 필터 적용, 시리얼 플로터 |
| 5 | 100 Hz 샘플 루프, TFT 막대 그래프, LED/진동 |
| 6 | 상태 머신, 버튼 입력, 세션 플로우 |
| 7 | BLE GATT 연동, 앱 연결 확인, Flash 세션 저장 |
| 8 | 배터리 모니터, Deep sleep, 캘리브레이션 영구 저장 |
| 9 | 버그 픽스만, 수요일 Code Freeze |

## 구조

```
firmware/
├── firmware.ino        스케치 진입점 + 스케줄러
├── config.h            핀맵 + 상수 + enum
├── ble_uuids.h         UUID 단일 출처
├── sensor.{h,cpp}      압력 센서 + EMA + 링버퍼
├── state_machine.{h,cpp}  훈련 세션 상태·지표 계산
├── ui_tft.{h,cpp}      ST7735 렌더링 (더티 영역)
├── feedback.{h,cpp}    LED + 진동 패턴 (non-blocking)
├── button.{h,cpp}      디바운싱 + 길게/짧게 판별
├── storage.{h,cpp}     LittleFS 세션 이력 + 설정
├── ble_service.{h,cpp} ArduinoBLE GATT
└── power.{h,cpp}       배터리 측정 + Deep Sleep
```

## 주의사항

- `loop()` 안 어디에도 `delay()` 사용 금지. 모든 주기 작업은 `millis()` 델타.
- `ArduinoBLE.poll()` 을 주기적으로 호출해야 연결이 유지됨.
- TFT_eSPI 는 SPI 충돌을 일으킬 수 있음 — BLE 스택과의 타이밍 검증 필수 (5주차).
