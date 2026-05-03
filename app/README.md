# BlowFit App (Flutter)

BlowFit 호기 저항 훈련 디바이스의 스마트폰 컴패니언.

## 설정

Flutter SDK 3.32+ 필요.

```bash
flutter --version   # 3.32 이상 확인
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
스캔/연결 실패 시 [BleErrorTranslator](lib/core/ble/ble_error_translator.dart) 가
6개 카테고리 (btOff / scanThrottled / permission / timeout / locationOff / generic)
로 분류해서 사용자 친화 메시지 + 카테고리별 아이콘으로 노출.

> **iOS 미초기화**: 현재 `ios/` 디렉터리는 생성되지 않은 상태. 추후 추가 시
> `Info.plist` 에 `NSBluetoothAlwaysUsageDescription` + `NSLocationWhenInUseUsageDescription` 키 필요.

## 구조

```
lib/
├── main.dart                       진입점 + GoRouter (StatefulShellRoute 4탭)
├── core/
│   ├── ble/
│   │   ├── blowfit_uuids.dart           UUID + opcode + enum 단일 출처
│   │   ├── ble_manager.dart             추상 인터페이스
│   │   ├── real_ble_manager.dart        flutter_blue_plus 구현
│   │   ├── fake_ble_manager.dart        FAKE_BLE 모드 in-process 구현
│   │   ├── blowfit_codec.dart           22B/32B 순수 디코더 (테스트 용이)
│   │   ├── seq_gap_detector.dart        u16 wrap + 패킷 손실 감지
│   │   ├── ble_permissions.dart         Android 12+ 권한 헬퍼
│   │   ├── ble_error_translator.dart    예외 → 친화 메시지 + 카테고리 매퍼
│   │   ├── discovered_device.dart       UI ↔ flutter_blue_plus 분리 DTO
│   │   └── ble_providers.dart           Riverpod (FAKE_BLE 분기 포함)
│   ├── coach/
│   │   ├── milestone_engine.dart        5종 마일스톤 (pure)
│   │   └── coaching_engine.dart         Dashboard / Result 코칭 카피 (pure)
│   ├── db/
│   │   ├── app_database.dart            Drift 테이블 + .forTesting() 시드
│   │   ├── session_repository.dart      세션 저장/조회 + 집계 메서드
│   │   ├── trend_bucketing.dart         일/주/월/년 4종 bucketize (pure)
│   │   └── db_providers.dart            sessionPersistence + 집계 family
│   ├── storage/
│   │   ├── last_device_store.dart       자동 재연결용 마지막 기기 캐시
│   │   ├── target_settings_store.dart   목표 압력대 SharedPreferences 캐시
│   │   ├── user_profile_store.dart      이름/나이/성별/시작일 영속화
│   │   └── storage_providers.dart       FutureProvider 래퍼
│   ├── theme/
│   │   ├── blowfit_colors.dart          디자인 토큰 (Wanted DS 기반)
│   │   ├── blowfit_theme.dart           ThemeData.light + Pretendard
│   │   └── blowfit_widgets.dart         BlowfitCard / BlowfitChip / StreakBadge
│   └── models/
│       └── pressure_sample.dart         PressureSample/DeviceSnapshot/SessionSummary
└── features/
    ├── onboarding/         첫 사용 4 step 슬라이드 (welcome / 마우스피스 / 다이얼 / 호흡)
    ├── profile_setup/      이름/나이/성별 입력 (UserProfile 영속화)
    ├── connect/            페어링 펄스 + 친화 에러 + 자동 재연결
    ├── shell/              4탭 메인 셸 (홈/기록/추이/프로필)
    ├── dashboard/          홈 — 인사 / 디바이스 카드 (3 metric) / CTA / 통계 / 코칭
    ├── training/
    │   ├── training_intro_screen.dart   시작 전 — 체크리스트 + 팁
    │   └── training_screen.dart          실시간 — BreathOrb + 그래프
    ├── result/             결과 — hero 점수 + 4 stat + 코칭 노트 + 세션 요약
    ├── history/            기록 — streak hero + 캘린더 + 최근 세션
    ├── trend/              추이 — 일/주/월/년 4탭 + 변화율 + 마일스톤
    ├── profile/            프로필 — 헤더 + 베이스라인 + 설정 메뉴
    ├── session_detail/     세션 상세 (history / result 에서 진입)
    ├── settings/           목표 압력대 슬라이더 + 영점 보정
    └── guide/              (legacy) 첫 사용 가이드 — onboarding 으로 대체됨
```

## 테스트

```bash
flutter test
```

총 **139 케이스**, 16개 파일:

| 파일 | 영역 |
|---|---|
| [blowfit_codec_test.dart](test/blowfit_codec_test.dart) | 22B/32B 디코더, wrap, 음수 압력 |
| [seq_gap_detector_test.dart](test/seq_gap_detector_test.dart) | u16 wrap, gap, reset, isDegraded 임계값 |
| [session_repository_test.dart](test/session_repository_test.dart) | Drift 인메모리, upsert 멱등, 페이징, 주간 집계 |
| [trend_bucketing_test.dart](test/trend_bucketing_test.dart) | 일/주/월/년 4종 bucketize pure |
| [milestone_engine_test.dart](test/milestone_engine_test.dart) | 5종 마일스톤 + firstStreakReached |
| [coaching_engine_test.dart](test/coaching_engine_test.dart) | Dashboard / Result 코칭 분기 |
| [last_device_store_test.dart](test/last_device_store_test.dart) | SharedPreferences 영속화, equality |
| [target_settings_store_test.dart](test/target_settings_store_test.dart) | 목표 zone validation |
| [session_persistence_test.dart](test/session_persistence_test.dart) | FakeBle → DB E2E |
| [dashboard_screen_test.dart](test/dashboard_screen_test.dart) | 위젯 — 비연결, 통계, 코칭 |
| [training_screen_test.dart](test/training_screen_test.dart) | 위젯 — phase chip, BreathOrb |
| [history_screen_test.dart](test/history_screen_test.dart) | 위젯 — 캘린더 그리드, streak hero |
| [session_detail_screen_test.dart](test/session_detail_screen_test.dart) | 위젯 — stat 행 + 분석 코멘트 |
| [settings_screen_test.dart](test/settings_screen_test.dart) | 위젯 — 슬라이더 / 영점 보정 |
| [guide_screen_test.dart](test/guide_screen_test.dart) | 위젯 — (legacy) 4단계 카드 |
| [widget_test.dart](test/widget_test.dart) | FakeBle 단독 동작 검증 |

## 디자인 시스템 (디자인 v2 적용)

[Claude Design 핸드오프 v2](../docs/design-v2.md) 의 토큰을 그대로 도입:

- **컬러**: blue50–700 (primary `#0066FF`) / green/amber/red semantic / gray50–900 / shadowLevel 1–3
- **폰트**: Pretendard 5 weight (Regular/Medium/SemiBold/Bold/ExtraBold)
- **컴포넌트**:
  - `BlowfitCard` — 12/14/16 padding 옵션, optional `onTap` (InkWell)
  - `BlowfitChip` — 5 tone (blue/green/amber/red/neutral)
  - `StreakBadge` — 연속 훈련 N일 표시
- **레이아웃 패턴**: 온보딩/페어링/에러/Empty 모두 동일한 `_OnboardingStateLayout`
  (80 top spacer + 220×220 frame + 32 gap + 140 minHeight 텍스트)

## 알려진 제약

- iOS 미초기화 (Android 우선)
- MTU 185 협상 실패 시 사용자 안내만, 자동 fallback 없음
- 시퀀스 갭 200+ 패킷 + 5% 이상 시 [BleHealthBanner](lib/features/training/training_screen.dart) 표시 (자동 재구독은 미구현)
- Settings 의 목표 압력대는 기기 저장(`SET_TARGET` opcode) + 로컬 캐시 동시 — 기기 단독으로 변경한 값은 앱이 모름
- 흡기 (음압) 데이터는 하드웨어 미지원 — Trend 차트 / Profile 베이스라인 / Result 통계에 흡기는 항상 `—` (차후 차압 센서 도입 시 자동 활성화)
- 훈련 알림 / 자동 추천 / 펌웨어 OTA — UI 항목 노출만, 실제 동작은 "곧 출시" 토스트
- Training 화면의 "세트 N/3" 표시는 펌웨어가 setIndex 를 BLE 로 노출 안 해서 1 고정 (FIXME)
