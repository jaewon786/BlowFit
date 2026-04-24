# Development Tools

## BLE Simulator

Virtual BLE peripheral that mimics the real device so the Flutter app can be developed without hardware.

### Install

```bash
pip install -r requirements.txt
```

`bless` is a cross-platform BLE peripheral library (macOS / Linux / Windows 10+ with BT adapter).

**Windows 추가 설정**: `bless` 는 WinRT 를 사용. Bluetooth 가 켜져 있어야 한다.

### Run

```bash
python ble-sim.py
```

출력 예:
```
2026-04-25 10:00:01 INFO Advertising as 'BlowFit-SIM'
2026-04-25 10:00:01 INFO Service UUID: 0000b410-0000-1000-8000-00805f9b34fb
2026-04-25 10:00:01 INFO Waiting for central... Ctrl+C to stop.
```

### Test with Flutter App

앱에서 `BlowFit-SIM` 으로 스캔 → 연결 → `START_SESSION` 명령 전송 시 호흡 파형이 20Hz 로 Notify 수신.

### Test with nRF Connect (Mobile)

1. Play Store / App Store 에서 **nRF Connect for Mobile** 설치
2. 스캔 → `BlowFit-SIM` 연결
3. BlowFit Training Service 확장
4. Pressure Stream char 의 Notify 활성화
5. Session Control char 에 `0101` (start, orifice=1) Write
6. 22 byte 패킷이 50ms 주기로 도착하면 정상

### 압력 파형 단독 검증

```bash
python pressure_waveform.py > cycle.csv
```

Excel 에서 cycle.csv 플롯 → 흡기-호기-휴식 패턴 확인.
