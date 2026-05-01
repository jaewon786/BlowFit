# BlowFit App (Flutter)

BlowFit 호기 저항 훈련 디바이스의 스마트폰 컴패니언.

## 설정

Flutter SDK 3.22+ 필요.

```bash
flutter --version   # 3.22 이상 확인
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # Drift 코드 생성
```

### Drift 코드 생성

`lib/core/db/app_database.dart` 의 테이블/스키마 수정 후에는 build_runner 재실행 필수:

```bash
dart run build_runner build --delete-conflicting-outputs
```

생성 산출물(`*.g.dart`)은 `.gitignore` 처리됨 — 머신마다 직접 생성한다.

## 실행

### 1) 기기 없이 폰에서 단독 실행 (권장)

```bash
flutter run --dart-define=FAKE_BLE=true
```

[FakeBleManager](lib/core/ble/fake_ble_manager.dart) 가 in-process BLE 디바이스를 흉내 냄.
- 800ms 후 `BlowFit-SIM (fake)` 단일 기기 노출
- 7.4 초 호흡 사이클, 피크 25 cmH₂O 합성 파형
- 30 초 후 자동 세션 종료 또는 수동 정지

Settings 의 `setTarget` / `zeroCalibrate` 는 no-op 처리되지만 SharedPreferences 캐시 영속화는 정상 동작.

### 2) 별도 PC 의 Python 시뮬레이터 대상

```bash
# 터미널 A (별도 PC 또는 같은 PC)
cd ../tools && python ble-sim.py

# 터미널 B
flutter run
```

앱에서 `BlowFit-SIM` 으로 스캔 → 연결.

### 3) 실기기 대상

```bash
flutter run --release
```

USB 디버깅 ON, `flutter devices` 로 폰 확인 후 위 명령. APK 만 받으려면:

```bash
flutter build apk --debug --dart-define=FAKE_BLE=true
# build/app/outputs/flutter-apk/app-debug.apk
```

## 권한 (Android)

[AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) 에 이미 선언:

```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
                 android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
                 android:maxSdkVersion="30" />
```

런타임 권한 요청은 [BlePermissions](lib/core/ble/ble_permissions.dart) 가 ConnectScreen 진입 시 처리. denied / permanentlyDenied / notApplicable(iOS) 분기 포함.

> **iOS 미초기화**: 현재 `ios/` 디렉터리는 생성되지 않은 상태. 추후 추가 시
> `Info.plist` 에 `NSBluetoothAlwaysUsageDescription` + `NSLocationWhenInUseUsageDescription` 키 필요.

## 구조

```
lib/
├── main.dart                       진입점 + GoRouter (push 기반 navigation)
├── core/
│   ├── ble/
│   │   ├── blowfit_uuids.dart           UUID + opcode + enum 단일 출처
│   │   ├── ble_manager.dart             추상 인터페이스
│   │   ├── real_ble_manager.dart        flutter_blue_plus 구현
│   │   ├── fake_ble_manager.dart        FAKE_BLE 모드 in-process 구현
│   │   ├── blowfit_codec.dart           22B/32B 순수 디코더 (테스트 용이)
│   │   ├── seq_gap_detector.dart        u16 wrap + 패킷 손실 감지
│   │   ├── ble_permissions.dart         Android 12+ 권한 헬퍼
│   │   ├── discovered_device.dart       UI ↔ flutter_blue_plus 분리 DTO
│   │   └── ble_providers.dart           Riverpod (FAKE_BLE 분기 포함)
│   ├── db/
│   │   ├── app_database.dart            Drift 테이블 + .forTesting() 시드
│   │   ├── session_repository.dart      세션 저장/조회 (deviceSessionId upsert)
│   │   └── db_providers.dart            sessionPersistenceProvider
│   ├── storage/
│   │   ├── last_device_store.dart       자동 재연결용 마지막 기기 캐시
│   │   ├── target_settings_store.dart   목표 압력대 SharedPreferences 캐시
│   │   └── storage_providers.dart       FutureProvider 래퍼
│   └── models/
│       └── pressure_sample.dart         PressureSample/DeviceSnapshot/SessionSummary
└── features/
    ├── dashboard/   홈 화면 + 배터리 경고 배너
    ├── connect/     스캔/권한/자동 재연결/트러블슈팅 (sealed _ConnectStatus)
    ├── training/    실시간 그래프, 3세트 phase chip, BLE 손실 배너, 배터리 경고
    ├── history/     12주 trend + 페이징 ("더 보기" 20개씩)
    └── settings/    목표 압력대 슬라이더 + 영점 보정 트리거
```

## 테스트

```bash
flutter test
```

총 50 케이스, 9개 파일:

| 파일 | 영역 |
|---|---|
| [blowfit_codec_test.dart](test/blowfit_codec_test.dart) | 22B/32B 디코더, wrap, 음수 압력 |
| [seq_gap_detector_test.dart](test/seq_gap_detector_test.dart) | u16 wrap, gap, reset, isDegraded 임계값 |
| [session_repository_test.dart](test/session_repository_test.dart) | Drift 인메모리, upsert 멱등, 페이징 |
| [last_device_store_test.dart](test/last_device_store_test.dart) | SharedPreferences 영속화, equality |
| [target_settings_store_test.dart](test/target_settings_store_test.dart) | 목표 zone validation |
| [session_persistence_test.dart](test/session_persistence_test.dart) | FakeBle → DB E2E |
| [dashboard_screen_test.dart](test/dashboard_screen_test.dart) | 위젯, 비연결 시 비활성, 네비 |
| [training_screen_test.dart](test/training_screen_test.dart) | 위젯, phase chip, orifice 세그먼트 |
| [widget_test.dart](test/widget_test.dart) | FakeBle 단독 동작 검증 |

## 알려진 제약

- iOS 미초기화 (Android 우선)
- MTU 185 협상 실패 시 사용자 안내만, 자동 fallback 없음
- 시퀀스 갭 200+ 패킷 + 5% 이상 시 [BleHealthBanner](lib/features/training/training_screen.dart) 표시 (자동 재구독은 미구현)
- Settings 의 목표 압력대는 기기 저장(`SET_TARGET` opcode) + 로컬 캐시 동시 — 기기 단독으로 변경한 값은 앱이 모름
