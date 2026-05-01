# 개발 계획서 — 잔여 일정 (8주차 ~ 발표)

작성일: 2026-04-25
근거: `BlowFit_개발계획서_v3.docx` (리브랜딩 반영) ↔ 현재 코드 비교

---

## 0. 핵심 결정 사항 (요약)

문서 vs 코드 비교 결과 **MVP 필수 화면 1개 + Dashboard 통계 연동**이 미구현. 펌웨어 알고리즘과 BLE 프로토콜은 문서와 일치. 잔여 일정은 **이번 주 P0 마무리 → 9주차 기기 통합 + Code Freeze → 10주차 검증·발표** 3단계로 진행한다.

| 결정 | 선택 | 근거 |
|---|---|---|
| 마무리(Cooldown) 단계 처리 | **문서를 코드에 맞춰 수정 (Cooldown 제거)** | `state_machine.cpp` 의 3세트 직후 Summary 흐름이 호스트 테스트 8케이스로 검증됨. 추가 30s 단계는 효과 근거가 없음 |
| iOS 빌드 | **이번 학기는 skip** | Android + Python 시뮬레이터로 발표 시연 가능, iOS 초기화 비용 대비 효용 낮음 |
| 4주 단기 자가 검증 | **9주차 Code Freeze 직후 시작** | 발표 시점까지 약 1.5주 데이터 확보 가능 |

> 위 3가지 중 **"마무리 단계 제거"** 만 팀 합의 후 [BlowFit_개발계획서_v3_rebrand.docx](../../../../Users/jaewo/Downloads/BlowFit_개발계획서_v3_rebrand.docx) 의 5.2 표에서 마지막 행 삭제 + 총 시간 "약 13분"으로 수정 필요.
>
> **추가 변경 (2026-04-25)**: 휴식 시간을 1분 → **30초** 로 단축 (UI 가이드 우선 결정 후 펌웨어 `REST_MS` 동기화). 한 사이클 = 시작 4분 + 휴식 30초, 3회 반복으로 총 약 13분.

---

## 1. 주차별 실행 계획

### Week 8 (이번 주, ~04-27 일) — 앱 갭 마무리

**목표**: P0 두 개 완료 + 발표 백업용 FAKE_BLE 데모 시나리오 안정화.

#### 🔴 T1. 훈련 가이드 화면 신규 추가
- **담당**: 컴공 (시각디자인 협업)
- **파일**: `app/lib/features/guide/guide_screen.dart` (신규), `app/lib/main.dart` (라우트 추가)
- **수락 기준**:
  1. Dashboard "훈련 시작" → 가이드 화면 → 사용자가 "시작" 누르면 `/training` push
  2. 단계 카드 7개 (준비 30s / 훈련 1세트 / 휴식 / 훈련 2세트 / 휴식 / 훈련 3세트), 현재 단계 강조
  3. 카드마다 ① 시간 ② 호흡 가이드 1줄 ③ 디스플레이 안내 1줄
  4. 상단 "오리피스 가이드" 칩 — 주차별 단계 추천 (1~4주: 4mm, 5~8주: 3mm, 9~12주: 2mm) — Settings 또는 SharedPreferences 의 "시작일"로 자동 추천
- **테스트**: widget test — 카드 7개 렌더, "시작" 탭 시 `/training` 라우트 검증
- **예상 작업량**: 4시간

#### 🔴 T2. Dashboard 통계 연동
- **담당**: 컴공
- **파일**:
  - `app/lib/core/db/session_repository.dart` — 신규 메서드 3개
  - `app/lib/features/dashboard/dashboard_screen.dart` — `.watch(...)` 로 노출
- **수락 기준**:
  1. `Stream<int> watchConsecutiveDays()` — 오늘부터 거꾸로 빈 날 처음 나올 때까지 연속 일수
  2. `Stream<int> watchWeekHits({int weekStart = DateTime.monday})` — 이번 주 월~오늘 중 1+ 세션 있는 날 수
  3. `Stream<Duration> watchTodayDuration()` — 오늘 누적 `durationSec`
  4. Dashboard `_StatCard` 3개가 placeholder 0 대신 실제 값
  5. "오늘의 목표" `LinearProgressIndicator` 가 `(todayMinutes / 20).clamp(0, 1)`
- **테스트**: in-memory Drift — 최근 3일 세션 시드 후 `watchConsecutiveDays()` 검증
- **예상 작업량**: 3시간

#### 🟢 T3. FAKE_BLE 발표 백업 시나리오 검증
- **담당**: 컴공 (PM 보조)
- **수락 기준**:
  1. `flutter run --dart-define=FAKE_BLE=true` 로 한 번도 끊김 없이 Connect → 자동재연결 → Training → Summary → History 흐름 완주
  2. 시연 영상 30s 수동 녹화 (백업)
- **예상 작업량**: 1시간

#### 결정 회의 (이번 주 일요일 권장)
- 마무리(Cooldown) 단계 제거 합의 → 문서 수정 → docx 재배포

---

### Week 9 (~05-04 월) — 기기 도착 + Code Freeze

> XIAO BLE nRF52840 + 압력 센서 + ST7735 도착 가정. 도착 즉시 통합.

#### 월~화: 펌웨어 통합 + 캘리브레이션

**T4. 부팅 + 시리얼 압력 검증** — 컴공
- 펌웨어 플래시 → 시리얼 모니터에 `adcToCmH2O()` 출력 확인
- 입에 물기 전 5초간 0±0.5 cmH2O (영점 안정)
- 약하게 부는 동안 5~10 cmH2O 범위 응답

**T5. 오리피스 압력 검증 (문서 8.1)** — 기계공 + 컴공
- 4mm / 3mm / 2mm 디스크 각 10회 입력 → 앱 history `maxPressure` 분포 확인
- 합격 기준: 동일 단계 ±1 cmH2O 이내, 단계 간 압력 분리 명확

**T6. BLE 안정성 검증 (문서 8.1)** — 컴공
- 10분 연속 압력 스트림 → 앱 [BleHealth.lossRate](../app/lib/core/ble/seq_gap_detector.dart) < 5%
- `SeqGapDetector.resets == 0` (재연결 없음)

**T7. SessionRepository 멱등 upsert 회귀** — 컴공
- 같은 세션이 BLE notify 재전송 시 중복 row 없음을 실기기로 재현 검증

#### 수요일 Code Freeze (05-06 가정)
- main 브랜치 잠금
- 이후 critical bug fix만, 기능 추가 금지
- CI 4잡 모두 그린: analyze / test / 펌웨어 / Android APK

#### 수~금: 자가 사용 시작
- **T8. 4주 단기 자가 검증** — 팀원 2~3명
  - 매일 1+ 세션, 발표일까지 ~10일 분량 데이터 누적
  - SnoreLab 등 코골이 앱 동시 측정 (밤마다)
  - 주관적 만족도 1~5점 일지

#### 외부 사용자 섭외 (병렬)
- **T9. 사용자 3명 모집** — PM (글비1)
  - 가족·지인 후보 5명 → 3명 확정
  - 10주차 화~목 중 30분 일정 잡기

---

### Week 10 (~05-11 월) — 검증 + 발표

#### 월~화: 사용자 검증
**T10. 외부 사용자 체험 + 설문 (문서 8.2)** — PM + 글비2
- 3명 × 30분 (오리피스 1~3단계 차례 체험)
- 5문항 설문 (Q1~Q5) 응답 수집
- 데이터 정리 → "우리가 입증한 것 vs 한계" 1페이지 요약

#### 화~수: 발표 자료
**T11. 시연 영상** — 미디어영상1
- 30~60초 데모 클립
- 시나리오: 기기 전원 ON → 마우스피스 물기 → 호기 → 앱 그래프 → 세션 요약

**T12. 슬라이드 + 포스터** — 미디어영상2 + 시각디자인
- 발표 흐름 9.1 기준 5파트 (4 + 4 + 5 + 4 + 3 = 20분)
- A1 포스터 2장 → 교내 인쇄

**T13. 백업 데모 준비** — 컴공
- FAKE_BLE APK + 시뮬레이터 PC 양쪽 준비 (실기기 고장 대비)

#### 목: 리허설 2회
- 시간 측정 (목표 20분 ±1분)
- 예상 Q&A 5개 대비

#### 금: 최종 발표
- 오전: 기기 점검 + 시연 시나리오 1회
- 발표 + 시연 + Q&A
- 회고 + GitHub/Notion 최종 정리

---

## 2. 작업 트래킹 표

| ID | 작업 | 담당 | 기한 | 상태 |
|---|---|---|---|---|
| T1 | 훈련 가이드 화면 | 컴공 | 04-27 일 | ⏳ |
| T2 | Dashboard 통계 연동 | 컴공 | 04-27 일 | ⏳ |
| T3 | FAKE_BLE 백업 시나리오 | 컴공 | 04-27 일 | ⏳ |
| — | 마무리 단계 제거 합의 | 전체 | 04-27 일 | ⏳ |
| T4 | 펌웨어 부팅 + 영점 | 컴공 | 기기 도착 +1d | ⏳ |
| T5 | 오리피스 압력 검증 | 기계공+컴공 | 기기 도착 +2d | ⏳ |
| T6 | BLE 안정성 10분 | 컴공 | 기기 도착 +2d | ⏳ |
| T7 | SessionRepository 회귀 | 컴공 | 기기 도착 +2d | ⏳ |
| — | Code Freeze | 전체 | 9주차 수요일 | ⏳ |
| T8 | 4주 단기 자가 사용 시작 | 팀원 2~3 | 9주차 수~ | ⏳ |
| T9 | 외부 사용자 3명 섭외 | PM | 9주차 후반 | ⏳ |
| T10 | 사용자 검증 + 설문 | PM+글비2 | 10주차 월~화 | ⏳ |
| T11 | 시연 영상 | 미디어영상1 | 10주차 화 | ⏳ |
| T12 | 슬라이드 + 포스터 | 미디어영상2+시각 | 10주차 수 | ⏳ |
| T13 | 백업 데모 | 컴공 | 10주차 수 | ⏳ |
| — | 리허설 2회 | 전체 | 10주차 목 | ⏳ |
| — | 최종 발표 | 전체 | 10주차 금 | ⏳ |

---

## 3. 부록 — 갭 분석 결과 (요약)

### 3.1 일치 ✅

- BLE 프로토콜 (4. 문서 ↔ [docs/ble-protocol.md](ble-protocol.md) ↔ [blowfit_uuids.dart](../app/lib/core/ble/blowfit_uuids.dart) ↔ [ble_service.cpp](../firmware/ble_service.cpp))
- 펌웨어 훈련 알고리즘 (5.2 ↔ [config.h](../firmware/config.h)): 준비 30s / 훈련 4min × 3 / 휴식 1min × 2
- 실시간 그래프 + 3세트 phase chip ([training_screen.dart](../app/lib/features/training/training_screen.dart))
- 12주 추세 + 페이징 ([history_screen.dart](../app/lib/features/history/history_screen.dart))
- 펌웨어 모듈 8개 모두 코드 완료 + 호스트 테스트 4개 28 케이스

### 3.2 갭 ❌

| 항목 | 위치 | 우선순위 |
|---|---|---|
| 훈련 가이드 화면 | (없음) | 🔴 P0 — T1 |
| Dashboard 통계 연동 | [dashboard_screen.dart:62](../app/lib/features/dashboard/dashboard_screen.dart#L62) (placeholder 0) | 🔴 P0 — T2 |
| 마무리 단계 30s | `COOLDOWN_MS` 정의됐으나 state_machine 미사용 | 🟡 결정 — 문서 수정 |
| sensor.cpp 호스트 테스트 | (없음) | 🟢 P1 — 발표 후 |
| power.cpp 호스트 테스트 | (없음) | 🟢 P1 — 발표 후 |

### 3.3 보너스 ✨ (문서엔 없으나 코드에 있음)

- Settings 화면 (목표 압력대 / 영점 보정 트리거)
- Connect 자동 재연결 + 권한 트러블슈팅
- BLE 패킷 손실 감지 + 경고 배너 → 문서 8.1 BLE 안정성 검증 자동화에 활용 가능
- 배터리 부족 경고 (Dashboard / Training)
- FAKE_BLE 모드 → 발표 시 기기 고장 시 백업 데모

---

## 4. 리스크 등록부

| 리스크 | 가능성 | 영향 | 완화책 |
|---|---|---|---|
| XIAO 알리 배송 지연 | 중 | 높 | 동급 nRF52840 보드 사전 1개 확보 |
| 압력 센서 5V 오배송 | 낮 | 높 | 디바이스마트 직접 픽업 / 모델명 끝 "33" 확인 |
| BLE MTU 185 협상 실패 | 낮 | 중 | 22B 패킷 — 23B 최소 MTU도 통과, 영향 미미 |
| 마우스피스 실리콘 성형 지연 | 중 | 중 | 5주차 발주 + 3D 프린팅 ABS 백업 |
| 외부 사용자 3명 모집 실패 | 중 | 중 | 가족·지인 백업 + 팀원 자가 데이터로 보완 |
| 발표일 기기 고장 | 낮 | 높 | T13 백업 데모 (FAKE_BLE APK + 시뮬레이터) |
| 9주차 통합 시 펌웨어/앱 불일치 | 중 | 높 | 단위 테스트 60+ 케이스로 사전 차단, 통합일 1일 버퍼 |

---

## 5. 즉시 액션 (이번 주말 ~ 월요일)

1. **T1 / T2 / T3** — 컴공이 일요일까지 PR 1개씩 (4 + 3 + 1 = 약 8시간)
2. **마무리 단계 제거 합의** — 일요일 미팅 의제로 추가
3. **T9 외부 사용자 섭외 시작** — PM 가 5명 후보 명단 작성, 일정 조율 시작
4. **T11 시나리오 스토리보드** — 미디어영상1 초안 (10주차 촬영 준비)

작업 진행 시 이 표의 상태 컬럼을 ✅ 로 갱신하고 PR 에 ID(T1, T2 …) 명시.
