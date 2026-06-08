# 제 6 장  임상 근거 및 훈련 알고리즘

> 본 장은 BRELOW 의 핵심 차별점이다. 시중 호흡근 훈련 기기 대부분이 절댓값 압력(예: 20 cmH₂O) 으로 강도를 고정하는 데 반해, BRELOW 는 **개인의 최대 호흡압(PImax / MEP) 에 대한 비율(%)** 로 강도를 결정한다. 본 장에서는 임상적 근거와 알고리즘을 함께 기술한다.

---

## 6.1 호흡근 훈련의 정의

### 6.1.1 IMT 와 EMT

| 약어 | 정의 | 표적 근육 |
|---|---|---|
| **IMT** (Inspiratory Muscle Training) | 흡기근 훈련 | 횡격막, 외늑간근, 사각근 |
| **EMT** (Expiratory Muscle Training) | 호기근 훈련 | 복근, 내늑간근 |

표 6.1 — 호흡근 훈련의 두 갈래.

BRELOW 는 양방향 차압 센서를 사용해 **IMT 와 EMT 를 단일 디바이스에서 동시에** 수행한다. 이는 한 방향만 훈련하는 시중 기기 대비 차별점이다.

### 6.1.2 적응증

호흡근 훈련은 다음 분야에서 임상적 효용이 보고되어 있다:

- **수면무호흡(OSA)** — 인후두근 강화로 기도 폐쇄 감소 (본 프로젝트의 1차 표적)
- **만성폐쇄성폐질환(COPD) 재활** — 호기 저항 훈련으로 동적 폐쇄 방지
- **운동 수행 능력** — 운동 선수의 호흡근 피로 지연
- **음성 / 발성** — 가수, 강사 등

---

## 6.2 PImax 와 MEP — 개인 최대 호흡압

### 6.2.1 정의

| 지표 | 정의 |
|---|---|
| **PImax** (Maximal Inspiratory Pressure) | 잔류 폐용량에서 측정한 최대 흡기 저항압의 절댓값 (cmH₂O) |
| **MEP** (Maximal Expiratory Pressure) | 전 폐용량에서 측정한 최대 호기압 (cmH₂O) |

### 6.2.2 정상 성인의 기준값

Black 과 Hyatt (1969) 의 고전적 연구가 가장 널리 인용되는 기준이다 [1]. 일반 성인의 평균 PImax / MEP 는 표 6.2 와 같다.

표 6.2 — 정상 성인의 평균 PImax / MEP (Black & Hyatt, 1969).

| 성별 | PImax (cmH₂O) | MEP (cmH₂O) |
|---|---|---|
| 남성 | 124 ± 22 | 233 ± 42 |
| 여성 | 87 ± 16 | 152 ± 27 |

BRELOW 의 기본값은 보수적으로 **PImax = 80 cmH₂O**, **MEP = 60 cmH₂O** 로 설정한다. 이는 일반인이 측정 기능 없이 시작할 때의 안전한 출발점이며, 사용자가 본 앱의 PImax/MEP 측정 화면에서 실측한 값으로 즉시 갱신된다.

```cpp
// firmware-esp32/include/config.h::session
constexpr float PIMAX_DEFAULT_CMH2O = 80.0f;
constexpr float MEP_DEFAULT_CMH2O   = 60.0f;
```

### 6.2.3 본 프로젝트의 PImax/MEP 측정 방법

BRELOW 앱의 `/pimax-measure` 화면이 다음 절차로 실측한다:

```
1. 호기 측정
   intro (수동 "측정 시작") → 카운트 3 s → measure 5 s
   ▶ 5 초 동안 가능한 가장 강하게 호기
   ▶ 펌웨어가 cycle 시작 phase = Exhale 로 startSession
   ▶ 앱이 pressure stream 의 max(양압) 을 추적 → MEP 결정

2. 흡기 측정 (호기 종료 후 자동 진행 X, 사용자 수동 시작)
   intro → 카운트 3 s → measure 5 s
   ▶ 5 초 동안 가능한 가장 강하게 흡기
   ▶ 펌웨어가 cycle 시작 phase = Inhale 로 startSession
   ▶ 앱이 pressure stream 의 max(|음압|) 을 추적 → PImax 결정

3. summary → 두 값 저장 → BLE SET_TARGET v4.1 payload 전송
```

> **임상 표준 측정 (Black & Hyatt 1969)** 은 1 초간 sustained 압력의 최댓값을 측정하지만, BRELOW 는 사용자가 가정에서 자가 측정한다는 점을 고려해 **5 초간 peak hold** 로 근사한다. 5 초 동안 한 번이라도 최댓값을 기록하면 그것을 채택한다.

---

## 6.3 %PImax 기반 적응형 목표 압력

### 6.3.1 원리

훈련 효과는 절댓값 압력보다 **사용자 본인의 최대치 대비 비율** 에 더 강하게 좌우된다. PImax 60 cmH₂O 인 사용자에게 30 cmH₂O 는 50 % 라 가벼운 부하지만, PImax 100 인 사용자에게 30 cmH₂O 는 30 % 에 불과해 효과가 미미하다.

BRELOW 는 다음 식으로 목표 압력을 계산한다.

```
흡기 목표 [low, high] = [PImax × low_pct,  PImax × high_pct]
호기 목표 [low, high] = [MEP  × low_pct,  MEP  × high_pct]
```

식 6.1 — %PImax / %MEP 기반 목표 압력 계산.

### 6.3.2 강도 단계 (Intensity Level)

본 프로젝트는 임상 문헌에서 권장되는 3 단계를 채택한다.

표 6.3 — 강도 단계별 비율 (`pimax_mep_store.dart::IntensityLevel`).

| 단계 | low ~ high (%) | 근거 |
|---|---|---|
| Beginner | 30 ~ 40 % | Bissett et al. 2019 — 중환자실 호흡 재활 [2] |
| **Normal** (기본) | 50 ~ 60 % | POWERbreathe 임상 표준 — Sustainable Training Zone [3] |
| Advanced | 70 ~ 75 % | Vranish & Bailey 2016 — IMT 6 주 프로토콜 [4] |

### 6.3.3 계산 예시 (Normal · PImax 80, MEP 60)

| 방향 | 계산 | 결과 (cmH₂O) | 표시 |
|---|---|---|---|
| 흡기 low | 80 × 0.50 | 40 | "−40 ~ −48 (55 % PImax)" |
| 흡기 high | 80 × 0.60 | 48 | |
| 호기 low | 60 × 0.50 | 30 | "+30 ~ +36 (55 % MEP)" |
| 호기 high | 60 × 0.60 | 36 | |

표 6.4 — 기본값으로 계산된 목표 영역.

### 6.3.4 단일 변수 전환

강도 변경은 사용자에게 단일 라디오 버튼(초보 / 일반 / 숙련) 만 노출된다. 펌웨어 측에서도 한 줄로 4 개 target 이 재계산된다.

```cpp
// firmware-esp32/src/session.cpp::recomputeTargets()
const float low_pct  = INTENSITY_LOW_PCT[g_intensity];
const float high_pct = INTENSITY_HIGH_PCT[g_intensity];
g_inhale_target_low  = g_pimax * low_pct;
g_inhale_target_high = g_pimax * high_pct;
g_exhale_target_low  = g_mep   * low_pct;
g_exhale_target_high = g_mep   * high_pct;
```

코드 6.1 — Intensity 1 변수가 흡기/호기 4 개 target 을 결정.

---

## 6.4 훈련 시간 구성

### 6.4.1 본 프로젝트의 단위 구조

표 6.5 — 1 세션의 시간 구조.

| 단위 | 구성 | 시간 |
|---|---|---|
| 1 호흡 (breath cycle) | 흡기 5 s + 호기 5 s + 휴식 5 s | **15 s** |
| 1 세트 (set) | 10 호흡 | 150 s (= 2.5 분) |
| 1 세션 | 2 세트 + 세트 사이 30 s 휴식 | 약 **5.5 분** |
| 권장 일일 빈도 | 1 ~ 2 회 (총 5 ~ 11 분) | — |

> 펌웨어 구현은 v4.0 호환을 위해 4-phase Turn enum (Exhale/ExhaleRest/Inhale/InhaleRest) 을 유지하되 `ExhaleRest = 0 ms` 로 사실상 3-phase 로 동작 (§4.4.2).

### 6.4.2 근거

#### Vranish & Bailey 2016 [4]

저강도(75 % PImax) IMT 를 5 분/일 × 5 일/주 × 6 주 수행한 결과, 수면 무호흡 환자의 **수축기 혈압 감소** 및 **수면 효율 개선** 이 보고됨. 30 breaths × 1 set 의 구성.

→ BRELOW 는 이를 **10 breaths × 2 sets** 로 재배분해 한 세트당 부담을 줄이고 휴식을 1 회 둠 (사용자 fatigue 완화).

#### The Breather (PN Medical) 공식 프로토콜 [5]

The Breather 는 양방향 호흡 훈련 디바이스의 산업 표준이다. 공식 권장 프로토콜:
- **10 breaths × 2 sets, 주 6 일**
- 1 set 종료 후 휴식
- IMT 와 EMT 동시 수행

→ BRELOW 의 시간 구조는 이 프로토콜과 일치한다.

#### POWERbreathe — Sustainable Zone [3]

POWERbreathe 는 IMT 전용 기기로 50 ~ 60 % PImax 를 "지속 가능한 훈련 영역(sustainable zone)" 으로 권장한다. 이 범위는 일반인이 매일 5 분간 부담 없이 지속할 수 있는 강도이다.

→ BRELOW 의 **Normal** 단계 (기본값) 비율의 근거.

---

## 6.5 안전 상한 (Safety Ceiling)

### 6.5.1 임계값

표 6.6 — 안전 상한 (`config.h::session`).

| 방향 | 임계 (magnitude, cmH₂O) | 근거 |
|---|---|---|
| 흡기 | **90** | Vranish 2016 의 75 % PImax 상한 + 일반인 PImax 평균 124 의 약 73 % |
| 호기 | **100** | 일반 소비자 디바이스의 일반적 ceiling |

### 6.5.2 적용 — 사용자 입력값 검증

사용자가 PImax / MEP 를 과대 입력해 계산된 target high 가 안전 상한을 초과하면 펌웨어 측 `recomputeTargets()` 에서 자동 clamp 하고 Serial 경고를 출력한다.

```cpp
if (inh_hi > INHALE_SAFETY_LIMIT_CMH2O) {
  Serial.printf("[session] WARN: inhale target %.1f > safety %.1f cmH2O — clamped\n",
                inh_hi, INHALE_SAFETY_LIMIT_CMH2O);
  inh_hi = INHALE_SAFETY_LIMIT_CMH2O;
}
```

앱 측 설정 화면도 동일 검증을 수행해 입력 필드 옆에 ⚠ 아이콘과 안내 문구를 표시한다 (`target_settings_screen.dart::_inhaleExceeds`).

### 6.5.3 적용 — 측정값 saturation

센서 자체의 saturation clamp (±71 cmH₂O, §4.3.4) 는 측정값이 상한선에 도달하기 전에 작동한다. 따라서 사용 중 임상적으로 위험한 압력에 도달할 가능성은 현실적으로 없으나, target 계산값 clamp 는 사용자 입력 오류에 대한 1 차 방어선 역할을 한다.

---

## 6.6 PImax 자동 추적 (향후 개선)

▶ 본 MVP 는 PImax / MEP 를 사용자가 1 회 측정해 고정값으로 사용한다. 그러나 훈련을 지속하면 PImax 가 상승해 동일 % 의 목표 압력이 점점 가벼워지는 문제가 있다.

▶ 향후 개선으로 다음을 제안:

1. **매 세션 종료 후 `maxPressure` / `maxInhale` 을 PImax/MEP 추정치로 업데이트** — 최근 7 세션의 95 퍼센타일 등.
2. **주간 PImax 재측정 알림** — 사용자에게 매주 1 회 측정 권장.
3. **자동 강도 상향 제안** — 일정 기간 hit_percent ≥ 80 % 가 지속되면 다음 단계(예: Normal → Advanced) 로 상향 제안.

---

## 6.7 참고 문헌

| 번호 | 인용 |
|---|---|
| [1] | Black LF, Hyatt RE. *Maximal respiratory pressures: normal values and relationship to age and sex*. Am Rev Respir Dis. 1969;99(5):696-702. |
| [2] | Bissett B, Leditschke IA, Green M, et al. *Inspiratory muscle training for intensive care patients: a multidisciplinary practical guide for clinicians*. Aust Crit Care. 2019;32(3):249-255. |
| [3] | POWERbreathe International. *Clinical IMT Protocol — Sustainable Training Zone*. https://www.powerbreathe.com/ (Accessed 2026-04). |
| [4] | Vranish JR, Bailey EF. *Inspiratory Muscle Training Improves Sleep and Mitigates Cardiovascular Dysfunction in Obstructive Sleep Apnea*. Sleep. 2016;39(7):1453-9. |
| [5] | PN Medical. *The Breather — Respiratory Muscle Training Protocol*. https://www.pnmedical.com/ (Accessed 2026-04). |

표 6.7 — 본 장의 참고 문헌. 전체 참고 문헌 목록은 **부록 E** 에 통합한다.

---

*— 제 6 장 끝 —*
