# BlowFit App (Flutter)

BlowFit 호기 저항 훈련 디바이스의 스마트폰 컴패니언.

## 설정

Flutter SDK 3.22+ 필요.

```bash
flutter --version   # 3.22 이상 확인
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # Drift 코드 생성
```

### 코드 생성 (Drift)

`lib/core/db/app_database.dart` 를 수정한 뒤에는 반드시 build_runner 재실행:

```bash
dart run build_runner build --delete-conflicting-outputs
```

생성된 `*.g.dart` 파일은 `.gitignore` 되어 있다. 개발자 머신마다 직접 생성.

### 플랫폼 초기화 (최초 1회)

Flutter 프로젝트 네이티브 파일이 아직 생성되지 않았다면:

```bash
flutter create . --org com.hannam.blowfit --platforms=android,ios
```

기존 `lib/`, `pubspec.yaml`, `analysis_options.yaml` 은 덮어쓰지 않는다 (flutter create 가 존재하는 파일을 보존).

### Android 권한

`android/app/src/main/AndroidManifest.xml` `<manifest>` 안에 추가:

```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
                 android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
                 android:maxSdkVersion="30" />
```

### iOS 권한

`ios/Runner/Info.plist` 에 추가:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>풍선 운동 디바이스 연결에 필요합니다.</string>
```

## 실행

### 시뮬레이터 대상 (기기 없이)

1. 터미널 A: `cd ../tools && python ble-sim.py`
2. 터미널 B: `flutter run`
3. 앱 → 기기 연결 → `BlowFit-SIM` 선택

### 실기기 대상

1. USB 디버깅 ON, `flutter devices` 로 확인
2. `flutter run --release`

## 구조

```
lib/
├── main.dart                 진입점 + GoRouter
├── core/
│   ├── ble/
│   │   ├── blowfit_uuids.dart     UUID + opcode + enum 단일 출처
│   │   ├── ble_manager.dart       BLE 연결 + 디코더
│   │   └── ble_providers.dart     Riverpod Providers
│   ├── db/
│   │   ├── app_database.dart      Drift 테이블 + DB 인스턴스
│   │   ├── session_repository.dart 세션 저장/조회 API
│   │   └── db_providers.dart      Riverpod Providers (자동 저장 포함)
│   └── models/
│       └── pressure_sample.dart   PressureSample, DeviceSnapshot, SessionSummary
└── features/
    ├── dashboard/            홈 화면
    ├── connect/              기기 스캔·연결
    └── training/             실시간 그래프 + 세션 제어
```

## 테스트

```bash
flutter test
```

## 알려진 제약

- iOS 백그라운드 BLE 미지원 (MVP 범위)
- MTU 185 협상 필수. 실패 시 오류 안내하고 재시도 유도
- Pressure Stream Notify 는 공칭 20Hz. 일시적 누락은 seq 번호로 감지
