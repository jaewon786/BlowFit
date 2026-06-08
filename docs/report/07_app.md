# 제 7 장  앱 설계

> 본 장은 BRELOW 컴패니언 앱(Android, Flutter) 의 설계를 화면 단위로 기술한다. 앱은 디바이스의 단순한 컨트롤러를 넘어, 훈련 데이터의 영속·시각화·코칭, 그리고 동반자와의 데이터 공유까지 담당한다.

---

## 7.1 기술 스택

표 7.1 — `app/pubspec.yaml` 의 주요 의존성.

| 영역 | 라이브러리 | 버전 |
|---|---|---|
| UI 프레임워크 | Flutter | ≥ 3.22 |
| 상태 관리 | Riverpod / flutter_riverpod | 2.5 |
| 라우팅 | go_router | 14 |
| BLE | flutter_blue_plus | 1.32 |
| 로컬 DB | drift / drift_flutter | 2.18 |
| 영속 (key-value) | shared_preferences | 2.3 |
| Android 백그라운드 | flutter_foreground_task | 8.10 |
| 인증 / 클라우드 | firebase_auth / cloud_firestore | 5.3 / 5.5 |
| 알림 | flutter_local_notifications | 17 |
| 캐릭터 애니메이션 | rive | 0.14 |
| 차트 | fl_chart | 0.68 |
| 폰트 | Pretendard 5 weight (asset) | — |
| 그래픽 | flutter_svg | 2.0 |

> 본 MVP 는 **Android 전용** 이다 (iOS 디렉토리 부재 — `pubspec.yaml::flutter_launcher_icons.ios: false`). iOS 미지원은 발표 시점까지 작업 우선순위 조정의 결과.

---

## 7.2 라우트 맵

`app/lib/main.dart` 의 `GoRouter` 설정 기준.

### 7.2.1 메인 셸 (4-탭 stateful shell)

```
StatefulShellRoute.indexedStack:
  ├── Branch 1: 홈
  │   ├── /                 HomePagerScreen (홈 ↔ 추이 좌우 swipe)
  │   ├── /training-intro
  │   ├── /training
  │   ├── /settings
  │   └── /settings/target
  ├── Branch 2: 기록
  │   └── /history
  ├── Branch 3: 추이
  │   └── /trend
  └── Branch 4: 프로필
      └── /profile
```

### 7.2.2 전체 화면 라우트 (셸 외부)

표 7.2 — 전체 라우트 일람.

| 라우트 | 화면 | 그룹 |
|---|---|---|
| `/role-select` | 역할 선택 (디바이스 / 동반자) | 첫 실행 |
| `/onboarding` | 4 단계 슬라이드 | 첫 실행 |
| `/profile-setup` | 이름 · 나이 · 성별 | 첫 실행 |
| `/pimax-measure` | **PImax / MEP 측정** (v4.1 신규) | 첫 실행 |
| `/connect` | BLE 페어링 | 첫 실행 / 재연결 |
| `/training-intro` | 훈련 시작 전 체크리스트 | 메인 |
| `/training` | 실시간 훈련 | 메인 |
| `/result` | 세션 결과 | 메인 |
| `/session/:id` | 세션 상세 | 메인 |
| `/settings` | 설정 메뉴 | 메인 |
| `/settings/target` | 강도 · PImax / MEP · 영점 | 메인 |
| `/guide` | 훈련 가이드 | 보조 |
| `/sleep-effect` | 수면 효과 (Samsung Health) | 보조 |
| `/sleep-trend` | 수면 추이 | 보조 |
| `/companion` | 동반자 홈 | 동반자 |
| `/my-code` | 연결 코드 (디바이스 사용자) | 동반자 |
| `/shealth-test` | Samsung Health 연동 검증 | 개발용 |

---

## 7.3 디자인 시스템

### 7.3.1 색상 토큰 (`core/theme/blowfit_colors.dart`)

```
blue50-700        primary (#0066FF base)
green/amber/red   semantic (100/500/Ink)
gray50-900        neutrals
shadowLevel1/2/3  카드 elevation 단계
BlowfitRadius     sm / md / lg / xl / xxl
ink / ink2 / ink3 텍스트 3 단계 명도
```

### 7.3.2 폰트 — Pretendard 5 weight

`assets/fonts/Pretendard-{Regular, Medium, SemiBold, Bold, ExtraBold}.otf`. `BlowfitTheme.light()` 의 `fontFamily: 'Pretendard'` 로 앱 전역 적용.

### 7.3.3 공통 위젯 (`core/theme/blowfit_widgets.dart`)

| 위젯 | 용도 |
|---|---|
| `BlowfitCard` | 둥근 모서리 + shadow 카드, 옵셔널 `onTap` |
| `BlowfitChip` | 5-tone 라벨 chip (blue/green/amber/red/neutral) |
| `StreakBadge` | "N일 연속" 오렌지 배지 |

### 7.3.4 공통 레이아웃 — `_OnboardingStateLayout`

Onboarding 4 step + Pairing 5 state (scanning/found/connected/permissions/failed/empty) 가 동일한 레이아웃을 공유한다.

```
80 px      top spacer
220×220    일러스트/아이콘 슬롯
32 px      gap
≥140 px    텍스트 블록 (28 px 제목 + 16 px 설명)
```

화면 전환 시 로고/텍스트가 흔들리지 않고 자연스럽게 morph 한다.

---

## 7.4 첫 실행 흐름

그림 7.1 — 첫 실행 라우트 흐름.

```
앱 첫 실행
  ▼
/role-select   ───► (동반자)  ──► /companion (Firestore 연결 코드 입력)
  │ 디바이스 사용자
  ▼
/onboarding    ───► 4 단계 슬라이드 (환영 / 마우스피스 / 다이얼 / 호흡)
  ▼
/profile-setup ───► 이름 · 나이 · 성별 (UserProfileStore 영속)
  ▼
/pimax-measure ───► (NEW) 호기 측정 → 흡기 측정 → 강도 자동 계산
  ▼
/connect       ───► BLE 페어링 + 자동 SET_TARGET v4.1 전송
  ▼
/              메인 셸 진입
```

> Role 이 `device` 인 사용자가 `/companion` 으로 접근하거나 그 반대인 경우, `redirect` 로 차단된다 (`main.dart::redirect`).

---

## 7.5 PImax / MEP 측정 화면 (v4.1 핵심 신규)

`app/lib/features/profile_setup/pimax_measure_screen.dart` (약 700 줄).

### 7.5.1 7-단계 상태 머신

표 7.3 — `_Step` enum 의 7 단계.

| # | Step | 시간 | 트리거 |
|---|---|---|---|
| 1 | introExhale | — | 진입 직후, "측정 시작" 버튼 노출 |
| 2 | countdownExhale | 3 s | 버튼 클릭 |
| 3 | measureExhale | 5 s | 카운트 0 도달 시 `_armDeviceMeasureMode(exhale)` → BLE startSession(phase=0) → 펌웨어 Train 진입 |
| 4 | introInhale | — | 호기 측정 종료 후 자동 진입, "측정 시작" 버튼 노출 |
| 5 | countdownInhale | 3 s | 버튼 클릭 |
| 6 | measureInhale | 5 s | 카운트 0 도달 시 `_armDeviceMeasureMode(inhale)` → BLE startSession(phase=1) → 펌웨어 Train + Inhale phase |
| 7 | summary | — | 두 결과 표시 + "저장하고 시작" / "처음부터 다시 측정" |

### 7.5.2 측정 로직

```dart
_sub = ref.read(bleManagerProvider).pressureStream.listen((s) {
  if (dir == _Direction.exhale) {
    if (s.cmH2O <= 0) return;        // 음압은 호기 측정 대상 아님
    if (s.cmH2O > _mep) setState(() => _mep = s.cmH2O);
  } else {  // inhale
    final mag = -s.cmH2O;
    if (mag <= 0) return;
    if (mag > _pimax) setState(() => _pimax = mag);
  }
});
```

코드 7.1 — 측정 방향에 맞는 부호만 추적하는 peak hold.

### 7.5.3 동기화 설계 결정 (시행착오 기록)

본 화면 개발 중 다음 두 문제를 겪었다:

1. **측정이 안 됨 (둘 다 0)** — 디바이스가 Standby 상태였기 때문. 펌웨어는 standby 에서도 압력 stream 을 흘려보내지만, 사용자가 LCD "훈련대기" 를 보고 측정 의지가 떨어졌고 약하게 호흡함. 해결: 측정 시작 시 BLE `startSession` 호출로 펌웨어를 Train state 로 들여놓음 + 측정 종료 시 `stopSession`.

2. **앱 카운트와 디바이스 LCD 가 불일치** — `startSession` 을 카운트다운 시작 직전에 호출하면 펌웨어 `PREP_MS=0` 으로 즉시 Train 으로 진입해 LCD 가 카운트다운 없이 측정 화면으로 점프. 해결: `_armDeviceMeasureMode()` 호출을 `_startCountdown` 이 아닌 `_startMeasure` 진입 시점으로 미룸.

3. **흡기 측정인데 LCD 가 "내쉬기" 표시** — 펌웨어 cycle 은 항상 Exhale 부터 시작. 해결: BLE `START_SESSION` payload 에 `startPhase` byte 추가 + 펌웨어 `g_cycle_offset_ms` 로 cycle 시작점 조정.

세 단계의 동기화 작업을 거쳐 앱과 디바이스가 정확히 동기된 측정 UX 를 완성했다.

---

## 7.6 홈 / 대시보드

`app/lib/features/dashboard/dashboard_screen.dart`.

### 7.6.1 구성

```
┌─────────────────────────────────┐
│  BRELOW 로고  ⚙ 설정  🔔 알림    │
│  안녕하세요. {이름}님 😊          │
│  지난주보다 평균 압력이           │
│  10% 증가했어요!                  │
│       (헤드라인)                  │
│                                  │
│        🐣 BreLow 캐릭터           │
│                                  │
│  ╭─ 말풍선 ─────────╮             │
│  │ 저와 함께 훈련해요!│            │
│  ╰────────────────╯              │
│                                  │
│            [훈련하기]             │
│                                  │
│  ┌────── 통계 카드 ──────┐         │
│  │ 오늘 총 몇 번 했어요!  │        │
│  │ ▓▓▓▓▓░░░░░░ 65%      │        │
│  │ 호기 8회 5분 | 흡기 6회 4분│   │
│  └─────────────────────┘         │
└─────────────────────────────────┘
```

### 7.6.2 헤드라인 (CoachingEngine + GrowthMessage)

이번 주 / 지난주 호기 평균 압력 비교로 카피가 분기된다 (`core/coach/growth_message.dart`).

| Trend | 카피 |
|---|---|
| Up (+1.5 cmH₂O 이상) | "지난주보다 평균 압력이 N% 증가했어요!" |
| Down (-1.5 cmH₂O 이상) | "지난주보다 평균 압력이 N% 감소했어요!" |
| Flat | "지난주와 평균 압력이 비슷해요!" |
| NoData | "꾸준히 훈련을 시작해봐요!" |

### 7.6.3 BreLow 진화형 캐릭터 (Rive)

호흡 훈련의 동기 부여를 위해 도입한 게이미피케이션 요소.

표 7.4 — 진화 단계 (`core/storage/character_stage_store.dart`).

| 단계 | 임계 | 자산 |
|---|---|---|
| Egg (알) | 0 일 (기본) | `assets/character/stage1_egg.riv` |
| Baby (아기) | 누적 distinct 훈련일 7 일 | `assets/character/stage2_baby.riv` |
| Oxygen (성체) | 누적 30 일 | `assets/character/stage3_oxygen.riv` |

#### Rive Path B 제어 방식

각 .riv 는 단일 아트보드에 3 개 timeline (`alive`, `happy`, `bloom`) 을 갖는다. State Machine 이 없으므로 `RiveWidgetController` 를 서브클래싱 (`_StageRiveController`) 해 `artboard.animationNamed(...).advanceAndApply(dt)` 로 timeline 을 직접 구동.

| Timeline | 트리거 | 동작 |
|---|---|---|
| alive | 기본 idle (무한 loop) | 항상 |
| happy | 세션 1 회 완료 | 1 회 재생 → alive 복귀 |
| bloom | 진화 임계 도달 | 1 회 재생 → 다음 단계로 .riv 교체 |

#### 진화 매끄러움 (선로딩)

진화 시 .riv 비동기 로드의 공백을 없애기 위해 3 단계 .riv 를 앱 시작 시 모두 캐시한다 (`Map<CharacterStage, rive.File>`). 진화 순간 동기로 즉시 교체 → 시각적 공백 없음.

---

## 7.7 실시간 훈련 화면

`app/lib/features/training/training_screen.dart`.

### 7.7.1 4-Phase Phase Machine (앱 측)

앱은 펌웨어 cycle 과 sync 되는 자체 phase 머신을 돌려 즉각 UI 반응을 보장한다.

```dart
const _phaseDuration = <_Phase, double>{
  _Phase.exhale:     5.0,   // 펌웨어 BREATH_EXHALE_MS 와 일치
  _Phase.exhaleRest: 0.0,   // 펌웨어와 동일 skip
  _Phase.inhale:     5.0,
  _Phase.inhaleRest: 5.0,
};
```

### 7.7.2 BreathOrb (원형 게이지)

화면 중앙의 원형 호 + 점:
- 파란색 호 = 호기 실시간 압력 비율
- 초록색 호 = 흡기 실시간 압력 비율
- 가운데 라벨 = 현재 phase 한글명 + 남은 초

### 7.7.3 Phase 별 목표 압력 표시 (v4.1)

상단 우측 컬럼은 현재 phase 가 흡기인지 호기인지에 따라 분기.

| Phase | 표시 |
|---|---|
| Exhale / ExhaleRest | "+30 ~ +36 cmH₂O" + "목표 55 % MEP" |
| Inhale / InhaleRest | "−40 ~ −48 cmH₂O" + "목표 55 % PImax" |

휴식(Rest) phase 는 직전 phase 의 표시를 유지한다.

---

## 7.8 결과 / 기록 / 추이

### 7.8.1 `/result` — 세션 결과

`features/result/result_screen.dart`. Hero 점수 (hit %) + 4 stat (max 호기 / avg 호기 / max 흡기 / avg 흡기) + 코칭 노트.

### 7.8.2 `/history` — 캘린더

`features/history/history_screen.dart`. 월별 grid + 연속 일수 hero + 최근 세션 카드.

### 7.8.3 `/trend` — 추이

`features/trend/trend_screen.dart`. 일/주/월/년 4 탭 + 마일스톤 카드 (첫 훈련 / 7 일 연속 / 호기 20 돌파 / 30 일 연속 / 호기 25 돌파).

집계는 `core/db/trend_bucketing.dart` 의 pure 함수가 담당.

---

## 7.9 설정 — `/settings/target`

`features/settings/target_settings_screen.dart` (v4.1 전면 재작성).

### 7.9.1 3 카드 구성

1. **강도 단계** — Beginner / Normal / Advanced 라디오
2. **내 PImax / MEP** — 숫자 입력 필드 (안전 상한 초과 시 ⚠ 경고)
3. **계산된 목표 압력 미리보기** — 흡기/호기 절댓값 + (X % PImax/MEP) + ⚠ 표시

추가로 **영점 보정** 카드 — `bleManagerProvider.zeroCalibrate()` 호출.

### 7.9.2 저장 흐름

```
"저장하고 기기로 전송" 클릭
  ▼
1. PimaxMepStore.saveLevel / savePimax / saveMep   (로컬 영속)
2. bleManager.setIntensityTarget(level, pimax, mep) (BLE wire 5 B 전송)
3. SnackBar 안내
```

펌웨어가 OFF 또는 미연결이면 (2) 실패. 다음 연결 시 `targetSyncProvider` 가 자동 재전송 (`core/db/db_providers.dart`).

---

## 7.10 동반자 모드 (요약)

자세한 내용은 **제 9 장** 참조. 본 절에서는 라우트만 명시.

- `/role-select` 에서 "동반자" 선택 → 항상 `/companion` 으로 redirect
- `/companion` — 동반자 홈 (연결된 사용자의 훈련 카드 + "눈치주기" 버튼)
- 디바이스 사용자가 `/my-code` 에서 발급한 6 자리 코드를 동반자가 입력해 연결

---

## 7.11 디바이스 사용자의 추가 화면

| 라우트 | 화면 |
|---|---|
| `/profile` | 프로필 헤더 (자동 N 주차 표시) + 베이스라인 + 설정 진입 |
| `/guide` | 훈련 가이드 (단계 카드 + 호흡 안내) |
| `/sleep-effect` | 수면 효과 비교 (전/후 + SpO₂ 추이) |
| `/sleep-trend` | 수면 추이 (수면 점수 + 무호흡 징후) |

`/sleep-effect`, `/sleep-trend` 는 Samsung Health Data SDK 연동이 필요하다 (§8.5 참조).

---

## 7.12 빌드 / 실행

```bash
cd app
flutter pub get
flutter analyze                      # 정적 분석
flutter test                         # 단위 / 위젯 테스트
flutter build apk --debug            # 디버그 APK
flutter run                          # 디바이스에 직접 실행

# FAKE BLE 시뮬레이터 (발표 백업)
flutter run --dart-define=FAKE_BLE=true
```

`FAKE_BLE=true` 시 `core/ble/fake_ble_manager.dart` 가 활성화되어 실제 디바이스 없이 시연 가능 (sine wave 압력 패턴 + 자동 세션 종료).

---

*— 제 7 장 끝 —*
