# 제 8 장  데이터 관리

> BRELOW 는 4 개의 영속 계층을 사용한다 — 펌웨어 NVS, 앱 SharedPreferences, 앱 Drift DB (SQLite), 그리고 클라우드 Firestore. 본 장은 각 계층의 스키마와 데이터 흐름을 기술한다.

---

## 8.1 영속 계층 개요

표 8.1 — 4 영속 계층.

| 계층 | 위치 | 보관 항목 |
|---|---|---|
| 펌웨어 NVS | ESP32 Preferences | 세션 ID, 영점 offset, 강도 / PImax / MEP |
| 앱 SharedPreferences | Android 기기 | 사용자 설정 / 캐시 (key-value) |
| 앱 Drift (SQLite) | Android 기기 | 세션 통계 / 수면 데이터 (시계열) |
| Firestore | Google Cloud | 동반자 모드 데이터 공유 |

### 8.1.1 진실의 원천 (Single Source of Truth)

각 데이터의 SSOT 를 명확히 정의해 충돌을 방지한다.

| 데이터 | SSOT | 앱 측 |
|---|---|---|
| 압력 측정값 | 펌웨어 sensor | 일회성 스트림 (저장 X) |
| 세션 통계 (max/avg) | 펌웨어 Summary | 앱 Drift `Sessions` 에 upsert |
| sessionId | 펌웨어 NVS | 앱이 받아 저장만 |
| 영점 offset | 펌웨어 NVS | 앱 UI 에서 트리거만 |
| PImax / MEP / 강도 | 앱 PimaxMepStore | BLE 로 펌웨어에 sync |
| 훈련 시간 | 앱 TrainDurationStore | BLE 로 펌웨어에 sync |
| 사용자 프로필 | 앱 UserProfileStore | (펌웨어 미보관) |

---

## 8.2 앱 로컬 DB — Drift (SQLite)

### 8.2.1 스키마 (v4)

```dart
// app/lib/core/db/app_database.dart
class Sessions extends Table {
  IntColumn  get id              => integer().autoIncrement()();
  IntColumn  get deviceSessionId => integer()();              // 펌웨어 sessionId
  DateTimeColumn get startedAt   => dateTime().nullable()();
  IntColumn  get durationSec     => integer()();
  RealColumn get maxPressure     => real()();                 // 호기 최대
  RealColumn get avgPressure     => real()();                 // 호기 평균
  RealColumn get avgInhale       => real().withDefault(Constant(0))();  // 흡기 평균 (v2+)
  RealColumn get maxInhale       => real().withDefault(Constant(0))();  // 흡기 최대 (v2+)
  IntColumn  get enduranceSec    => integer()();
  IntColumn  get orificeLevel    => integer()();
  IntColumn  get targetHits      => integer()();
  IntColumn  get sampleCount     => integer()();
  IntColumn  get crc32           => integer()();
  DateTimeColumn get receivedAt  => dateTime().withDefault(currentDateAndTime)();
  // 유일 제약: 펌웨어 sessionId 가 같으면 같은 세션 (멱등 재전송)
  @override
  List<Set<Column>> get uniqueKeys => [{deviceSessionId}];
}
```

### 8.2.2 마이그레이션 이력

표 8.2 — Drift schema 변경.

| schema 버전 | 변경 |
|---|---|
| v1 | 최초 — 호기 통계만 |
| v2 | `avgInhale`, `maxInhale` 추가 (펌웨어 v4.0 양방향 센서 대응) |
| v3 | `SleepRecords` 테이블 추가 (Samsung Health 연동) |
| v4 | `SleepRecords` 에 `apneaSign` 컬럼 추가 |

마이그레이션은 `AppDatabase::migration::onUpgrade` 에서 `from` 버전별 분기 처리.

### 8.2.3 주요 쿼리 (`session_repository.dart`)

표 8.3 — `SessionRepository` 의 핵심 API.

| 메서드 | 반환 | 용도 |
|---|---|---|
| `insertFromSummary(SessionSummary)` | `Future<int>` | BLE Summary 수신 시 upsert (deviceSessionId 충돌 시 덮어쓰기) |
| `watchRecent({limit=30})` | `Stream<List<Session>>` | 기록 화면의 최근 30 세션 |
| `watchSince(DateTime)` | `Stream<List<Session>>` | 추이 차트 (since 시점 이후) |
| `watchConsecutiveDays()` | `Stream<int>` | 연속 훈련 일수 (오늘 기준) |
| `watchWeekHits()` | `Stream<int>` | 이번 주 1+ 세션 일수 |
| `watchTodayDuration()` | `Stream<Duration>` | 오늘 누적 훈련 시간 |
| `watchCharacterStats()` | `Stream<({trainingDays, sessionCount})>` | BreLow 진화 임계 판정용 |

### 8.2.4 트렌드 집계 — `trend_bucketing.dart`

`/trend` 화면의 일/주/월/년 4 탭은 모두 같은 세션 리스트를 다른 bucket 으로 집계한다.

```dart
List<TrendBucket> bucketByDay(List<Session>, {required from, required to});
List<TrendBucket> bucketByWeek(List<Session>, ...);
List<TrendBucket> bucketByMonth(List<Session>, ...);
List<TrendBucket> bucketByYear(List<Session>, ...);
```

각 bucket 은 시작 시각 + maxPressure 평균 + 세션 수를 포함한다. 모두 pure 함수이며 단위 테스트(`test/trend_bucketing_test.dart`) 로 검증.

---

## 8.3 앱 SharedPreferences — 7 store

`app/lib/core/storage/` 에 7 개 store 클래스가 정의되어 있다.

표 8.4 — Store 카탈로그.

| Store | 보관 항목 | 본 보고서 |
|---|---|---|
| `UserRoleStore` | 디바이스 / 동반자 역할 (변경 불가) | §7.4 |
| `UserProfileStore` | 이름 · 나이 · 성별 · 시작일 | §7.4 |
| `PimaxMepStore` (NEW v4.1) | PImax · MEP · IntensityLevel | §6.3, §7.9 |
| `TrainDurationStore` | 훈련 시간 (분, 옵션 [5, 10]) | §7.9 |
| `TargetSettingsStore` (legacy) | 절댓값 zone (low, high) — 호환 유지 | — |
| `CharacterStageStore` | BreLow 표시 단계 + 본 세션 baseline | §7.6 |
| `LastDeviceStore` | 마지막 페어링 디바이스 MAC + 이름 | §5.8 |

### 8.3.1 PimaxMepStore (v4.1 핵심)

```dart
// app/lib/core/storage/pimax_mep_store.dart
class PimaxMepStore {
  static const _kPimax = 'pimax_cmh2o_x10';   // ×10 정수로 저장
  static const _kMep   = 'mep_cmh2o_x10';
  static const _kLevel = 'intensity_level';
  static const defaultPimax = 80.0;
  static const defaultMep   = 60.0;
  static const defaultLevel = IntensityLevel.normal;
  static const inhaleSafetyLimitCmH2O = 90.0;
  static const exhaleSafetyLimitCmH2O = 100.0;
  ...
}
```

값을 정수 ×10 으로 저장하는 이유: BLE wire format 과 일치시켜 부호 변환 오차를 줄이고, SharedPreferences 의 int 컬럼을 사용할 수 있다.

---

## 8.4 펌웨어 NVS

ESP32 의 NVS(Non-Volatile Storage) 는 Arduino `Preferences` 라이브러리로 접근한다.

표 8.5 — 펌웨어가 NVS 에 보관하는 키.

| 키 | 타입 | 값 |
|---|---|---|
| `blowfit.sess_id` | uint32 | 마지막 세션 ID (`startSession` 마다 +1) |
| `blowfit.zero_off` | float | 영점 offset (cmH₂O) |

> v4.1 의 `PImax / MEP / Intensity` 는 NVS 에 보관하지 않는다. 매 연결 시 앱이 BLE SET_TARGET v4.1 payload 로 sync 하기 때문에 펌웨어가 직접 영속할 필요가 없다. 이는 SSOT 를 앱 측에 두기 위한 의도적 설계이다.

---

## 8.5 Samsung Health Data SDK 연동

### 8.5.1 동기화 모델

`core/health/sleep_sync.dart`. Samsung Health 에서 다음 3 종 데이터를 읽어 Drift `SleepRecords` 에 upsert.

표 8.6 — Samsung Health 에서 가져오는 데이터.

| 데이터 | 출처 | 빈도 |
|---|---|---|
| 수면 구간 (start, end, score, durationMin) | Samsung Health Sleep | 밤당 1 건 |
| 혈중산소 SpO₂ (min, avg, max) | Samsung Watch SpO₂ 측정 | 가변 (잠 자는 동안 수십 건) |
| 무호흡 징후 (DETECTED / NOT_DETECTED / UNDEFINED) | Samsung Watch 무호흡 감지 기능 | 밤당 1 건 (있을 때만) |

### 8.5.2 동기화 알고리즘

```dart
1. 최근 N 일의 수면 / SpO₂ / 무호흡 데이터를 모두 읽음
2. 무호흡 징후를 밤(end 날짜) 기준으로 indexing
3. 각 수면 구간에 대해:
   a. 같은 밤의 SpO₂ 샘플들을 filter (start ∈ [sleep.start, sleep.end])
   b. SpO₂ min / avg / max 집계
   c. 무호흡 징후 매핑
   d. SleepRepository.upsertNight(night, score, spo2*, apneaSign, ...)
```

### 8.5.3 표시 — `/sleep-effect`

훈련 시작일 (UserProfileStore.startedAt) 을 기준으로:
- **Before** = 시작일 이전 평균 SpO₂ / 수면 점수
- **After** = 시작일 이후 평균

두 값을 비교 카드로 표시. 사용자에게 "훈련을 시작한 뒤 수면 점수가 +N 점 향상됐어요" 식의 코칭 메시지.

---

## 8.6 Firestore (동반자 모드)

### 8.6.1 컬렉션 구조

```
users/{uid}                  { displayName, connectionCode, updatedAt }
codes/{CODE}                 { uid }                          ← 6 자리 코드 → 사용자 역참조
links/{companionUid}         { userId, userName, linkedAt }   ← 동반자 → 사용자 연결
users/{uid}/sessions/{sid}   { startedAt, durationSec, maxPressure, ... }  ← 세션 백필
users/{uid}/nudges/{nid}     { from, message, sentAt }        ← 동반자가 보낸 응원
```

### 8.6.2 백필 (User Data Service)

디바이스 사용자가 새 세션을 끝낼 때마다 `UserDataService.uploadSession()` 이 Firestore 에 백필한다. 인증은 Firebase Anonymous Auth.

### 8.6.3 동반자 측 (Companion Data Service)

`/companion` 화면이 `links/{myUid}` 의 `userId` 로 사용자 세션을 listen. 새 세션이 추가되면 자동 알림.

---

## 8.7 데이터 흐름 종합

그림 8.1 — 한 세션이 영속되는 전체 흐름.

```
사용자가 훈련 시작 → 펌웨어 startSession
  ▼
펌웨어가 100 Hz 압력 측정 → BLE Pressure Stream
  ▼
앱이 stream 수신 → /training 화면 실시간 그래프
  ▼
펌웨어가 세션 종료 → finalizeStats() → Summary BLE notify
  ▼
앱이 Summary 수신
  ├─► SessionRepository.insertFromSummary() → Drift Sessions 테이블
  ├─► UserDataService.uploadSession() → Firestore users/{uid}/sessions
  ├─► CharacterStageStore baseline 갱신 → BreLow happy 모션 트리거
  └─► /result 화면 push
  ▼
동반자 폰의 /companion 화면이 Firestore listen → 새 세션 카드 표시
```

---

*— 제 8 장 끝 —*
