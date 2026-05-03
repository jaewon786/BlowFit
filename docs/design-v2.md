# 디자인 v2 (Claude Design 핸드오프) + 실데이터 연동 적용 내역

작성일: 2026-05-03
근거: Claude Design 핸드오프 번들 (9 화면, Wanted DS 토큰) +
[ui-redesign-plan.md](ui-redesign-plan.md) 1차 리디자인 위에 누적

---

## 0. 개요

[ui-redesign-plan.md](ui-redesign-plan.md) 의 1차 리디자인 (4탭 셸 + 라이트 테마)
이 완료된 시점에서, Claude Design 도구로 만든 9 화면 핸드오프 번들이
들어옴. 이것을 픽셀-수준에 가깝게 Flutter 로 재현 + 영속 데이터에 연결.

크게 3개 단계로 진행됨:

1. **디자인 v2 시각 적용** — 토큰, Pretendard, 9개 화면 리라이트
2. **Phase A — 데이터 인프라** — 집계 메서드, MilestoneEngine, CoachingEngine
3. **Phase B — 화면 wiring** — 모든 placeholder 를 실데이터로 갈아끼움

---

## 1. 디자인 시각 적용 (시각 토큰 + 9 화면)

### 1.1 디자인 토큰 (`core/theme/blowfit_colors.dart`)

```
blue50–700      primary (#0066FF base)
green/amber/red 100/500/Ink semantic
gray50–900      neutrals
shadowLevel1/2/3 카드 elevation 단계
BlowfitRadius   sm/md/lg/xl/xxl
```

### 1.2 Pretendard 폰트

5 weight (Regular 400 / Medium 500 / SemiBold 600 / Bold 700 / ExtraBold 800)
모두 `app/assets/fonts/Pretendard-*.otf` 로 번들. `pubspec.yaml`
`fonts:` 블록에 등록. `BlowfitTheme.light()` 의 `fontFamily: 'Pretendard'` 로
앱 전역 적용.

### 1.3 공통 컴포넌트 (`core/theme/blowfit_widgets.dart`)

| 위젯 | 용도 |
|---|---|
| `BlowfitCard` | 둥근 모서리 + shadowLevel1 카드 컨테이너. 옵셔널 `onTap` (InkWell) |
| `BlowfitChip` | 5 tone (blue/green/amber/red/neutral) 의 라벨 chip |
| `StreakBadge` | "N일 연속" 오렌지 배지 |

### 1.4 9개 화면 적용

| 디자인 시안 | 우리 화면 | 비고 |
|---|---|---|
| 01 온보딩 | `features/onboarding/onboarding_screen.dart` | 4 step (welcome / 마우스피스 / 다이얼 / 호흡), 220×220 일러스트 통일 |
| 02 프로필 설정 (NEW) | `features/profile_setup/profile_setup_screen.dart` | 이름/나이/성별 입력, `UserProfileStore` 영속화 |
| 03 기기 연결 | `features/connect/connect_screen.dart` | 페어링 펄스 + ping ring + 친화 에러 메시지 |
| 04 홈/대시보드 | `features/dashboard/dashboard_screen.dart` | 인사 / 디바이스 카드 (3 metric) / CTA / 통계 / 코칭 |
| 05 훈련 시작 전 | `features/training/training_intro_screen.dart` | 체크리스트 + 팁 (NEW) |
| 06 실시간 훈련 | `features/training/training_screen.dart` | BreathOrb + phase 별 배경 + 그래프 |
| 07 결과 | `features/result/result_screen.dart` | hero 점수 + 4 stat + 코칭 노트 |
| 08 캘린더/기록 | `features/history/history_screen.dart` | streak hero + 월별 그리드 + 최근 세션 |
| 09 추이 | `features/trend/trend_screen.dart` | 4탭 (일/주/월/년) + 마일스톤 카드 |
| 10 프로필 | `features/profile/profile_screen.dart` | 헤더 (자동 N주차) + 베이스라인 + 설정 |

### 1.5 공통 레이아웃 패턴

`_OnboardingStateLayout` (connect_screen.dart 내) 으로 일원화:
- 80px top spacer
- 220×220 frame (일러스트/아이콘 슬롯)
- 32px gap
- minHeight 140 텍스트 블록 (28px 제목 + 16px 설명)

이 패턴을 Onboarding 4 step / Pairing scanning/found/connected /
Permissions / Failed / Empty 모두 동일하게 적용 → 화면 전환 시
로고/텍스트가 흔들리지 않음.

### 1.6 Connect 화면의 친화 에러

`core/ble/ble_error_translator.dart` — `FlutterBluePlusException` /
`PlatformException` / 일반 `Object` 를 6 카테고리로 분류:

| 카테고리 | 매핑 조건 | 사용자 메시지 |
|---|---|---|
| `btOff` | adapterIsOff (FBP code 9), "off"/"disabled" 키워드 | "블루투스가 꺼져 있습니다" |
| `scanThrottled` | Android `SCAN_FAILED_SCANNING_TOO_FREQUENTLY` (code 6) | "잠시 후 다시 시도해주세요 / 30초 후" |
| `permission` | "permission" / "not_authorized" 키워드 | "블루투스 권한이 필요합니다" |
| `locationOff` | "location" + "off"/"disabled" | "위치 서비스가 꺼져 있습니다" |
| `timeout` | FBP code 1 | "응답이 없습니다" |
| `generic` | 그 외 | "연결할 수 없습니다" |

`_FailedView` 가 카테고리별 아이콘 + "자세히" 펼침으로 raw 메시지도
복사 가능하게 노출.

---

## 2. Phase A — 데이터 인프라

### 2.1 SessionRepository 집계 메서드 (`core/db/session_repository.dart`)

새 메서드 4개 + helper (`@visibleForTesting` pure):

```dart
// 첫 세션 호기 통계 (Profile 베이스라인)
Future<FirstSessionStats?> firstSessionStats();

// 12주 (또는 N주) rolling 호기 평균/최대
Stream<List<WeeklyAggregate>> watchWeeklyAggregates({int weeks = 12});

// 이번 주 / 지난 주 평균 호기 (Dashboard delta)
Stream<WeekPressureAvgPair> watchWeekAvgPressurePair();

// Trend 4탭 — 일/주/월/년 버킷
Stream<List<TrendBucket>> watchTrendBuckets(TrendPeriod period);
```

### 2.2 Trend bucketize (`core/db/trend_bucketing.dart`)

`TrendPeriod` enum + `TrendBucket` + 4종 pure helper:

| 탭 | 자리 수 | x축 라벨 | 데이터 윈도우 |
|---|---|---|---|
| 일간 | 7 | 월/화/수/목/금/토/일 | 이번 주 (월~일) |
| 주간 | 4 | 1주/2주/3주/4주 | 이번 달 (1-7/8-14/15-21/22-말일) |
| 월간 | 12 | 1월~12월 | 올해 |
| 년간 | 3 | 2024/2025/2026 (동적) | 최근 3년 (이번 해 포함) |

### 2.3 MilestoneEngine (`core/coach/milestone_engine.dart`)

5종 마일스톤 자동 감지 (sessions + currentStreak 입력):

1. 첫 훈련 완료 — 첫 세션 일자
2. 7일 연속 훈련 — 처음 도달한 날짜 (이후 끊겨도 유지)
3. 호기 20 cmH₂O 돌파 — 첫 maxPressure ≥ 20 세션 일자
4. 30일 연속 훈련 — 처음 도달 또는 진행도 (`(N / 30)`)
5. 호기 25 cmH₂O 돌파 — 첫 maxPressure ≥ 25 세션 일자

### 2.4 CoachingEngine (`core/coach/coaching_engine.dart`)

3개 출력 함수:

```dart
// Dashboard 위클리 코칭
CoachingTip dashboardWeekly({weekHits, currentStreak, thisWeekAvg, lastWeekAvg});

// Result 점수 메시지 (큰 카드의 짧은 문구)
String resultScoreMessage({score, targetHits});

// Result 코칭 노트 (1~2줄)
CoachingTip resultNote({score, targetHits, endurancePct, deltaVsLastWeek});
```

`CoachingTone` (positive/info/warning) 으로 카드 색상도 구분.

---

## 3. Phase B — 화면 wiring (실데이터 연결)

### B-1. Trend 화면

이전: `_weeks` 12개 하드코딩 (16.2 → 23.4 cmH₂O 깔끔한 우상향)
지금:
- `trendBucketsProvider` family watch (period 별)
- 4탭 활성 (이전엔 12주만)
- 헤더 카피 동적: "일간 추이" / "주간 추이" / "월간 추이" / "년간 추이"
- 변화율 라벨 동적: 첫 활성 자리 기반 ("월요일 대비" / "1주차 대비" / "1월 대비" / "2024년 대비")
- 마일스톤 카드 → `MilestoneEngine.compute(...)` 결과
- 차트 좌우 padding (월간 0.15 / 그 외 0.4) — 첫/마지막 점이 가장자리에 붙지 않게
- 마지막 점만 dot (디자인 일치, 모든 점에 dot 찍히던 버그 수정)

**Z안 적용**: 활성 데이터 < 2 면 변화율 숨김. 0 이면 empty card.

### B-2. Profile 화면

이전: '김영호 / 56세 · 남성 / 12주차 / 활성 사용자' / 16.2 / -14.0 모두 하드코딩
지금:
- 빈 프로필이면 "이름을 설정해주세요" CTA → `/profile-setup` (B안)
- 채워졌으면: `userProfileStoreProvider.load()` 의 name/age/gender
- N주차 chip — `firstSessionDate` 또는 `profile.startedAt` 기준 자동 계산
- 활성 사용자 chip — `consecutiveDays >= 3` 일 때만
- 베이스라인 호기 — `firstSessionStatsProvider.avgPressure`
- 흡기 — 항상 `—` (하드웨어 미지원)
- 개인 정보 수정 메뉴 → ProfileSetup 재진입 (prefill 지원)

### B-3. Dashboard

이전: "안녕하세요" / "다이얼 2단" / 23.4 / +3.1 / 코칭 하드코딩
지금:
- 인사 → "안녕하세요, {name}님" (빈 프로필이면 "안녕하세요" 만)
- DeviceStatusCard 통째로 큰 카드로 리라이트:
  - 64×64 avatar (BLE 아이콘) + 기기명 + ● 연결됨/끊김
  - 3 metric grid: 배터리 / 저항 다이얼 / 신호
  - 배터리 < 20% 또는 lowBattery → 빨강
  - 신호 약함 (BleHealth.isDegraded) → 빨강
- TrainingCta 부제 "흡기·호기 3세트 · 다이얼 N단" 동적
- QuickStats 우측 평균 호기 압력 → `weekAvgPressureProvider.thisWeek` 실데이터, delta 자동 (양수 ↑ 초록 / 음수 ↓ 빨강)
- 코칭 카드 → `CoachingEngine.dashboardWeekly(...)` (positive/info/warning 톤별 색)

### B-4. Result coach note

이전: "호흡근이 강해지고 있어요. 오늘처럼 꾸준히 훈련하면 효과가 커집니다." 고정
지금:
- `_scoreMessage` getter 제거 → `CoachingEngine.resultScoreMessage(...)`
- `_CoachNote` → `CoachingEngine.resultNote(...)` 입력
  - score / targetHits / endurancePct / deltaVsLastWeek 종합
  - 톤별 색상 (positive 파랑 트로피 / info 파랑 전구 / warning 주황 경고)
- 별 5개 row 제거 (디자인 v2 결정)

### B-5. Session detail comment

이전: "목표 구간(20-30 cmH₂O)" 하드코딩
지금:
- `targetSettingsStoreProvider` watch
- "목표 구간({zone.low}-{zone.high} cmH₂O)" 동적
- zone null → `TargetSettingsStore.defaultLow/High` 폴백

---

## 4. 라우팅 흐름

```
초기 진입 (앱 첫 실행)
└─ / (Dashboard)
   └─ /onboarding (가이드 다시 보기)
      └─ /profile-setup (이름/나이/성별)
         └─ /connect (페어링)

홈에서 훈련 시작
/ → /training-intro (체크리스트 + 팁)
   → /training (실시간, BreathOrb + 그래프)
      → /result (점수 + 통계 + 코칭)
```

`/training-intro` 와 `/training` 은 메인 셸 안의 push (홈 탭 stack).
`/result`, `/connect`, `/onboarding`, `/profile-setup`, `/session/:id`,
`/settings/target` 은 root nav 의 full-screen push.

---

## 5. 테스트 추가 내역

| 파일 | 케이스 | 영역 |
|---|---|---|
| `trend_bucketing_test.dart` | 20 | 4종 bucketize + sinceForPeriod |
| `milestone_engine_test.dart` | 9 | 5종 마일스톤 + firstStreakReached |
| `coaching_engine_test.dart` | 16 | dashboardWeekly / resultScoreMessage / resultNote 분기 |
| `session_repository_test.dart` 확장 | +11 | weeklyAggregatesFrom / weekAvgPressurePairFrom / firstSessionStats |

총 **139 케이스** (이전 50 → +89).

---

## 6. 알려진 제약 / 후속 작업

- **흡기 (음압) 미지원**: XGZP6847A005KPG 가 양압만 측정. Trend 차트 / Profile / Result 의 흡기는 항상 `—`. 차후 차압 센서 도입 시 자동 활성화.
- **펌웨어 setIndex 미노출**: TrainingScreen "세트 N/3" 표시는 1 고정 (FIXME). 펌웨어 Metrics payload 에 `uint8 setIndex; uint8 totalSets;` 추가 필요.
- **알림 / 자동 추천 / OTA**: UI 항목만 노출, 실제 동작은 "곧 출시" 토스트.
- **iOS**: 아직 초기화 안 됨. Android 우선.

---

## 7. 참고 — 디자인 핸드오프 번들 위치

```
/tmp/blowfit-design-v2/blowfit/
├── README.md            (Claude Design 가이드)
├── chats/               (사용자 ↔ 디자인 어시스턴트 대화 2개)
└── project/
    ├── BlowFit.html     (메인 캔버스)
    ├── app.css          (디자인 토큰)
    ├── app.jsx
    ├── components/
    │   ├── icons.jsx
    │   ├── ui.jsx
    │   ├── device-card.jsx
    │   └── pressure-graph.jsx
    └── screens/
        ├── onboarding.jsx
        ├── profile-setup.jsx
        ├── home.jsx
        ├── training.jsx
        ├── result.jsx
        ├── calendar.jsx
        └── trend-profile.jsx
```

Flutter 구현 시 React/HTML 의 prototype 구조를 따라가지 않고
**시각 결과만** 매칭. 카드 padding / 폰트 weight / 그림자 같은 토큰은
픽셀 수준에 가깝게 옮겼고, layout 은 Flutter 관용 위젯
(`Column / Row / Stack / IntrinsicHeight / Expanded`) 으로 재구성.
