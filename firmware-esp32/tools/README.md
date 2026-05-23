# firmware-esp32/tools — Standalone Verification Sketches

본 폴더의 sketch 는 메인 펌웨어 (`firmware-esp32/src/`) 와 별개의 PlatformIO
프로젝트. **TFT_eSPI / LVGL 같은 무거운 의존성을 안 가져와서 빌드가 빠르고**,
하드웨어/드라이버 한 가지만 격리해서 검증할 때 사용.

## 목록

| 폴더 | 목적 | 검증 단계 |
|---|---|---|
| `i2c_scan/` | I²C 버스 전체 스캔 → Click 보드의 MCP3221 주소 확인 (예상 0x4D) | MS2 |
| `mcp3221_test/` | MCP3221 단독 read + ratio + cmH₂O 변환 검증 (호흡 입력) | MS3 *(예정)* |

## 사용 (각 sketch 공통)

```bash
cd firmware-esp32/tools/<sketch_name>
pio run -t upload
pio device monitor
```

USB-CDC 모드라 `pio device monitor` 가 USB 시리얼을 자동으로 잡음.
업로드가 안 잡히면 보드의 BOOT 버튼 누른 채 RST 한 번 → BOOT 떼서 download mode 진입.

## 신규 sketch 추가 가이드

1. `firmware-esp32/tools/<name>/` 폴더 생성
2. `platformio.ini` — env 이름은 `[env:<name>]`, board=lilygo-t-display-s3
   - USB-CDC: `-DARDUINO_USB_CDC_ON_BOOT=1 -DARDUINO_USB_MODE=1` 필수
3. `src/main.cpp`
4. `.gitignore` — `.pio` 포함
5. 본 README 의 목록 표 갱신
