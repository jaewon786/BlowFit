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
- **Adafruit GFX Library** + **Adafruit ST7735 and ST7789 Library** — TFT 렌더링
- **Adafruit_LittleFS**, **InternalFileSystem** (Seeed 보드 패키지에 포함)

### 4. TFT 드라이버 — Adafruit_ST7735

[ui_tft.cpp](ui_tft.cpp) 는 **Adafruit_ST7735** 를 사용한다 (TFT_eSPI 는 nRF52 mbed BSP 와 호환 안 되는 이슈로 사용 안 함). User_Setup.h 같은 별도 설정 파일이 필요 없고, 핀맵은 [config.h](config.h) 의 `pins::TFT_CS / TFT_DC / TFT_RST` 단일 출처:

```cpp
// ui_tft.cpp 발췌
static Adafruit_ST7735 tft(pins::TFT_CS, pins::TFT_DC, pins::TFT_RST);
// Hardware SPI: SCK=D8, MOSI=D10 자동.
```

ST7735 0.96" (80×160) 패널 가정. 다른 사이즈로 바뀌면 [ui_tft.cpp](ui_tft.cpp) 의 `SCREEN_W / SCREEN_H` 와 `tft.initR(INITR_MINI160x80)` 호출만 변경.

> **TFT 가 아직 없다면**: [config.h](config.h) 의 `HAS_TFT` 를 0 으로 토글하면 `ui_tft::begin/render/invalidate` 모두 no-op 으로 컴파일됨 — Adafruit 라이브러리 설치 자체가 불필요.

### 4.5. Flash 영속화 (LittleFS)

> **mbed-enabled BSP 사용 시 (현재 권장 — ArduinoBLE 호환)**: Adafruit_LittleFS 가 BSP 에 번들되어 있지 않으므로 [config.h](config.h) 의 `HAS_FLASH` 가 기본값 0. `storage::saveSession/readHistory/saveConfig/loadConfig` 가 모두 no-op 으로 컴파일됨 — 세션은 RAM 에만 보관되어 재부팅 시 사라짐. 앱 측 Drift SQLite 가 1차 영속화 책임.
>
> Flash 영속화 활성화 옵션:
> - Adafruit-based Seeed BSP 로 전환 + Bluefruit BLE 라이브러리로 ble_service 재작성, 또는
> - mbed core 의 `mbed::LittleFileSystem` + `FlashIAPBlockDevice` 로 storage.cpp 재작성 (추후 작업)

## 빌드 & 업로드

1. `firmware/firmware.ino` 더블클릭으로 스케치 열기 (폴더 이름과 일치 필요)
2. USB-C 케이블로 XIAO 연결
3. 첫 업로드 시 리셋 버튼을 두 번 빠르게 눌러 부트로더 진입
4. ✓ 컴파일 → → 업로드

## 호스트 단위 테스트

Arduino 툴체인 없이 PC 의 g++ 로 빌드·실행. CI(Ubuntu) 와 동일한 흐름:

```bash
bash firmware/tests/run_all.sh
```

총 4개 파일 28 케이스가 순차 실행됨:

| 테스트 | 검증 영역 |
|---|---|
| `test_state_machine.cpp` | Boot→Standby→Prep(30s)→Train(4min)→Rest(30s)→Train→…→Summary 3세트 전이, 타깃 hold 15s |
| `test_storage.cpp` | LittleFS 링버퍼 (MAX_HISTORY=30), 최신순 정렬, max/duration clamping |
| `test_feedback.cpp` | 진동 시퀀스, Pattern → pulseVibration 매핑, idle 패턴 |
| `test_button.cpp` | 30ms 디바운스, short/long(2000ms) 판별, chatter 거부 |

호스트 빌드를 위해 `button.cpp` 는 ARDUINO 매크로 분기 안에 `g_hostPressed` 시드를 둔다 — 실기기 빌드에는 영향 없음.

## 시리얼 디버그

Tools → Serial Monitor 115200 baud. `Serial.print` 로 압력값/상태 확인.

## 주차별 진행 상황

PM 트래킹은 [docs/dev-plan.md](../docs/dev-plan.md) 의 작업 트래킹 표 (T1~T16) 를 단일 출처로 참조. 본 README 에 중복하지 않는다.

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
- TFT 렌더링은 SPI 충돌을 일으킬 수 있음 — BLE 스택과의 타이밍 검증 필수 (5주차).
