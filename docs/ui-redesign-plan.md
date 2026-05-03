# UI 리디자인 계획 — 와이어프레임 v2 적용 (1차, 완료)

작성일: 2026-04-25 · **상태: 1차 리디자인 완료, 디자인 v2 (Claude Design 핸드오프) 로 추가 갱신됨**
근거: 디자인 와이어프레임 6개 화면 (홈 / 가이드 / 실시간 / 세션 기록 / 추이 / 설정)

> ⚠️ **이 문서는 1차 리디자인 (4탭 셸 도입) 의 작업 계획.**
> 2026-05-02 이후 [Claude Design 핸드오프 v2](design-v2.md) 가 적용되어
> 9개 화면이 추가 리디자인됨. 단계별 적용 내역과 현재 화면 구조는
> [docs/design-v2.md](design-v2.md) 참조.
>
> 본 문서는 4탭 셸 / 라이트 테마 / 블루 토큰 도입의 1차 리디자인을 정리한
> 아카이브 문서로 유지.

## 진행 상태 (2026-05-03)

| Phase | 작업 | 상태 |
|---|---|---|
| **0** | 테마 + ShellRoute + 하단 탭 | ✅ 완료 (StatefulShellRoute 4탭) |
| **1** | Dashboard 리디자인 | ✅ 완료 → 추가로 디자인 v2 적용 |
| **2** | 훈련 가이드 리디자인 | ✅ 완료 → onboarding + training_intro 분리 |
| **3** | Training 리디자인 | ✅ 완료 → 추가로 BreathOrb (디자인 v2) |
| **4** | History (주간/월간 탭 + bar chart) | ✅ 부분 완료 → calendar 스타일 (디자인 v2) 로 변경 |
| **5** | Session Detail (신규) | ✅ 완료 |
| **6** | Settings 리디자인 (7항목) | ✅ 완료 |
| **7** | 폴리싱 + 테스트 + APK | ✅ 완료 |

---

## 0. 와이어프레임 vs 현재 코드 — 핵심 차이

| 영역 | 현재 | 와이어프레임 | 영향 |
|---|---|---|---|
| **테마** | Dark, teal seed (`Color(0xFF0F766E)`) | Light, blue accent | ColorScheme + 모든 화면 색상 재검토 |
| **메인 네비게이션** | AppBar 액션 + push 라우팅 | 하단 4탭(홈/기록/가이드/설정) | ShellRoute + BottomNavigationBar 도입 |
| **Dashboard 진척률** | LinearProgressIndicator | 원형 progress (CustomPaint) | 신규 위젯 |
| **세션 모달** | bottom sheet 1회성 | 별도 라우트 `/session/:id` (history 에서 진입) | 신규 화면 |
| **History 추이** | 12주 line chart | 주간/월간 탭 + bar chart + 전주 대비 % | 차트 재구성 |
| **반복 횟수** | 펌웨어 3세트 (`TOTAL_SETS=3`) | 와이어프레임 "반복 5회" / "총 20분" | ⚠️ **결정 필요** |
| **Settings 항목** | 목표 압력 + 영점 보정 (2개) | 7개 (내 기기/압력/알림/오리피스/OTA/도움말/정보) | 5개 신규 (대부분 스텁) |
| **TrainingScreen 추가 위젯** | phase chip + 3세트 dot + BLE 손실/배터리 banner | 와이어프레임에 없음 (단순화됨) | **유지 vs 제거 결정** |

---

## 1. 결정 필요 (구현 시작 전)

| # | 항목 | 옵션 | 권장 |
|---|---|---|---|
| D1 | **반복 횟수** | A) 펌웨어를 5세트로 수정 (config.h `TOTAL_SETS=5`) + 호스트 테스트 갱신 / B) 와이어프레임을 "3회 반복, 총 14분"으로 표기 | **B** — 펌웨어 단위 테스트 8케이스 + state_machine 안정성 우선. 와이어프레임 숫자는 협의로 조정 |
| D2 | **하단 4탭 구성** | 홈/기록/가이드/설정 (와이어프레임) | 그대로 채택. **Connect 는 설정 안의 "내 기기" 항목으로 흡수** |
| D3 | **TrainingScreen phase chip / 3세트 dot 유지 여부** | 유지(정보 보존) / 제거(와이어프레임 단순화 따름) | **유지** — degraded banner 와 함께 위치만 더 압축. 핵심 정보 제거 비용이 큼 |
| D4 | **알림(매일 20:00) 구현 범위** | A) 실구현 (flutter_local_notifications) / B) Settings 항목만 표시 + "곧 출시" 토스트 | **B** — MVP 범위 밖. v2 표기 |
| D5 | **펌웨어 업데이트(OTA) 구현 범위** | A) DFU 실구현 / B) 항목만 표시 + 현재 버전 readonly | **B** — 펌웨어 OTA 미구현. 표시만 |
| D6 | **다크/라이트 토글 제공** | 강제 라이트 / 사용자 선택 | 강제 라이트 (와이어프레임 일관성) |

> **D1 변경하면** 펌웨어 [config.h](../firmware/config.h) `TOTAL_SETS=5`, [state_machine.cpp](../firmware/state_machine.cpp), [tests/test_state_machine.cpp](../firmware/tests/test_state_machine.cpp) 의 `test_three_sets_auto_complete` 모두 수정 필요. 9주차 통합 테스트에서 부담.

---

## 2. 단계별 실행 계획

진행 순서는 **인프라 → 화면별 위에서 아래** 순. 각 Phase 끝에서 APK 빌드 + 폰 테스트로 검증.

### Phase 0 — 테마 + 하단 탭 인프라 (4h)

**목표**: 4개 탭 ShellRoute 도입 + Light/Blue 테마 전환. 기존 화면은 일단 새 탭 안에 그대로 옮긴다.

**작업**
1. [main.dart](../app/lib/main.dart) `ThemeData`:
   - `brightness: Brightness.light`
   - `seedColor: Color(0xFF3B82F6)` (와이어프레임 메인 블루)
   - 화이트 카드 + 10% 회색 배경 (`scaffoldBackgroundColor: Color(0xFFF7F8FA)`)
2. `ShellRoute` 도입 (go_router):
   - 4 탭: 홈(`/`), 기록(`/history`), 가이드(`/guide`), 설정(`/settings`)
   - Connect/Training/SessionDetail 은 ShellRoute *밖*에서 push
   - `BottomNavigationBar` (또는 `NavigationBar` Material3) — 아이콘: home, insights, menu_book, settings
3. 기존 5개 화면 그대로 ShellRoute 자식으로 이동. 외관은 다음 Phase 에서 처리

**수락 기준**
- 폰에서 4탭 전환 가능
- 시스템 뒤로가기는 탭 안에서 동작 (e.g., 가이드 → 훈련 → 뒤로 = 가이드 복귀)
- 다크→라이트 전환 후 모든 텍스트가 가독성 유지 (`Colors.white70` 같은 하드코딩 → `Theme.of(context).hintColor` 또는 `Colors.black54` 로 일괄 치환)

**위험**: 다크→라이트 전환으로 모든 화면의 색상이 깨질 수 있음. 컴파일은 되지만 글자가 흰 배경에 흰색이 되는 등.

**대응**: Phase 0 끝나면 APK 빌드해서 모든 탭 시각 검수 후 Phase 1 시작.

---

### Phase 1 — Dashboard 리디자인 (3h)

**목표**: 와이어프레임 ① 매칭. 원형 진척률 + 2개 stat 카드 + 빠른 시작 CTA.

**작업**
1. AppBar 제거, 커스텀 헤더 (로고 텍스트 "BlowFit" + 우측 알림 종 아이콘 placeholder)
2. **원형 진척률 위젯** (`_CircularGoalCard`):
   - `CustomPaint` 또는 `fl_chart` `PieChart` (배경 회색 / 전경 진행 색)
   - 중앙 텍스트: `"$todayMinutes / 20분"` 또는 "목표 달성!" (≥ 20)
3. 2개 stat 카드: 연속 사용일, 주간 달성률(%)
   - 와이어프레임 "85%" 표기 — 현재 `weekHits` (7일 중 N일) 을 백분율로 변환: `(weekHits / 7 * 100).round()%`
4. 빠른 시작 카드:
   - "훈련 시작" 큰 블루 버튼 (둥근 모서리 12px)
   - 미연결 시 "기기를 먼저 연결해주세요" 안내 텍스트 + 비활성

**수락 기준**
- 와이어프레임 ①과 시각적 유사도 ≥ 80%
- 기존 Dashboard 위젯 테스트 5개 통과 (UI 상수 변경에 따라 일부 텍스트 매처 갱신 필요)
- 배터리 경고 banner 는 유지 (와이어프레임에 없으나 안전 기능)

---

### Phase 2 — 훈련 가이드 리디자인 (2h)

**목표**: 와이어프레임 ② 매칭.

**작업**
1. 단계 리스트 단순화: 현재 6개 step card → **4개 phase 항목** (준비/본 운동/휴식/반복)
   - 항목 형식: `1. 준비 (1분) — 편안하게 앉아서 호흡하세요` 한 줄
   - **D1 결정에 따라** "반복 (총 3회 / 14분)" 또는 "(총 5회 / 20분)" 텍스트 변경
2. 오리피스 교체 가이드 카드:
   - 기존 추천 로직 유지 (firstSessionDate 기반 4mm/3mm/2mm)
   - 와이어프레임처럼 **오리피스 디스크 일러스트** 아이콘 추가 (`Icons.album` 또는 SVG 자산)
3. "훈련 시작" CTA 는 그대로 `/training` push (Phase 0 의 ShellRoute 가 인식)

**수락 기준**
- guide_screen_test 5개 통과 (텍스트 매처 갱신 필요)
- "단계 카드 7개" 테스트 → "4개" 로 수정

---

### Phase 3 — 실시간 훈련 리디자인 (3h)

**목표**: 와이어프레임 ③ 매칭. 핵심 정보 그대로 유지하되 시각 단순화.

**작업**
1. 상단 우측에 "● 연결 중" / "● 끊김" 칩 (connectionProvider 기반)
2. 큰 압력 표시 박스: "현재 압력 28 cmH2O" — 폰트 사이즈 48
3. "목표 구간 20-30 cmH2O" 한 줄 (Settings 의 TargetZone 동기화)
4. 차트 색을 와이어프레임 톤 (라이트 그린)으로 조정
5. 하단 통계 행: 지구력 시간 / 훈련 시간 (HH:MM 포맷)
   - 지구력 시간: SeqGapDetector 와 별개로, 클라이언트 측 `enduranceCounter` 도입 — 현재는 firmware Summary 까지 안 보임
6. **단일 "훈련 종료" 블루 버튼** (와이어프레임)
7. 기존 phase chip + 3세트 dot 은 우측 상단으로 압축 (D3 결정에 따라 유지)
8. BLE 손실 / 배터리 경고 banner 그대로 유지

**수락 기준**
- 폰에서 FAKE_BLE 모드로 훈련 시작 → 차트 + 압력 + 시간 카운터 모두 작동
- training_screen_test 3개 통과 (비활성 버튼 텍스트 매처 갱신)

**리스크**: 클라이언트 측 enduranceCounter 추가는 위험. 현재 펌웨어가 Summary 시점에만 endurance 를 알려줌. 실시간 표시는 프록시 (목표 구간 안에 있는 시간을 클라이언트가 누적)로 구현 → 펌웨어 값과 미세 차이 가능.

---

### Phase 4 — 주간/월간 추이 (3h)

**목표**: 와이어프레임 ⑤ 매칭. 주간/월간 탭 + 막대 그래프 + 전주 대비 비교.

**작업**
1. HistoryScreen 을 두 영역으로 분할:
   - 상단: TabBar 2탭 ("주간" / "월간")
   - 본문: 탭별 차트
2. 주간 탭:
   - `BarChart` (fl_chart) — 월~일 7개 막대, 평균 압력
   - 하단 카드: "이번 주 평균 N cmH2O ▲ N% (지난주 대비)"
   - 비교 로직: 이번 주 평균 vs 지난주 평균 → 차이 백분율 + 화살표
3. 월간 탭:
   - 30일 BarChart 또는 4주 BarChart
4. 세션 리스트는 **별도 화면 또는 하단 별도 섹션**:
   - 옵션 A: 추이 화면에 그대로 스크롤 아래 세션 리스트
   - 옵션 B: 추이 = 차트만, "세션 보기" 버튼 → 세션 리스트 화면 push
   - **권장 A** (스크롤 통합, 와이어프레임은 ⑤에 리스트 없음 — 추이 전용 화면)

**수락 기준**
- session_repository_test 추가: `weeklyAverage()`, `previousWeekAverage()` 메서드 + 테스트
- 세션 0개 시 빈 상태 안내

---

### Phase 5 — 세션 기록 상세 (NEW, 2h)

**목표**: 와이어프레임 ④ 매칭. 별도 라우트 `/session/:id`.

**작업**
1. 신규 파일 `lib/features/session_detail/session_detail_screen.dart`
2. 파라미터: `int sessionId` (Drift 의 `Sessions.id` 또는 `deviceSessionId`)
3. 5개 stat row:
   - 최대 압력 / 평균 압력 / 지구력 시간 / 훈련 시간 / 성공 횟수 (`targetHits / totalSets`)
4. 분석 코멘트 카드:
   - 규칙 기반: `targetHits >= totalSets * 0.8 ? "목표 잘 달성" : "꾸준한 훈련 권장"`
   - MVP 는 2~3개 메시지 분기로 충분
5. History 리스트에서 세션 탭 → push `/session/:id`
6. **기존 TrainingScreen 의 세션 종료 모달**도 → "상세 보기" 버튼 추가 → 같은 화면 push

**수락 기준**
- 세션 ID 잘못된 경우 빈 상태 안내
- 위젯 테스트 1개 (특정 세션 ID 로 stat 5개 노출)

---

### Phase 6 — 설정 화면 리디자인 (3h)

**목표**: 와이어프레임 ⑥ 매칭. ListTile 기반 7개 항목.

**작업**
1. 기존 슬라이더/영점보정 화면 → "목표 압력 설정" 항목의 *하위 화면* 으로 이동 (`/settings/target`)
2. 7개 항목 (위→아래):

| 항목 | trailing | 동작 | 구현 상태 |
|---|---|---|---|
| 내 기기 | "BlowFit_001" 또는 "연결 안 됨" | tap → `/connect` | LastDeviceStore 기반 |
| 목표 압력 설정 | "20-30 cmH2O" | tap → `/settings/target` (기존 슬라이더) | 구현됨, 이동만 |
| 훈련 알림 | "매일 20:00" / "꺼짐" | tap → 토스트 "곧 출시" (D4 결정) | 스텁 |
| 오리피스 단계 관리 | "중강도 (3.0mm)" | tap → 단계 변경 다이얼로그 | 신규 (간단) |
| 펌웨어 업데이트 | "v1.0.3" 또는 "최신" | tap → 토스트 "곧 출시" (D5 결정) | 스텁 |
| 도움말 | — | tap → 외부 URL 또는 in-app FAQ | 스텁 |
| 앱 정보 | — | tap → 버전/라이선스 다이얼로그 | 실구현 (`package_info_plus`) |

3. 상단 "내 기기" 카드는 와이어프레임처럼 좀 더 큰 영역. 연결 상태 LED 도트 (녹색/회색)
4. 영점 보정 버튼은 "목표 압력 설정" 화면 안으로 이동 또는 별도 항목 추가

**수락 기준**
- 설정 화면 1탭에서 모든 항목 노출 (스크롤 불필요)
- 펌웨어 업데이트 / 알림 / 도움말 항목은 명확히 "v2 예정" 표기

---

### Phase 7 — 폴리싱 + 테스트 + APK (2h)

**작업**
1. 모든 화면 시각 검수 — 폰에서 다크→라이트 전환 결과 확인
2. 위젯 테스트 갱신:
   - dashboard_screen_test: 텍스트 매처 ("훈련 시작" → 그대로, "기기 연결" → 위치 변경 가능성)
   - guide_screen_test: 4단계로 줄임
   - training_screen_test: 종료 버튼 텍스트 변경 가능
   - 신규: session_detail_screen_test
3. analyze 에러 0 확인
4. `flutter test` 전체 통과
5. APK 빌드 (FAKE_BLE 포함)
6. 폰에서 6개 와이어프레임 시나리오 한번씩 완주

---

## 3. 작업 트래킹

| Phase | 작업 | 예상 | 상태 |
|---|---|---|---|
| **0** | 테마 + ShellRoute + 하단 탭 | 4h | ⏳ |
| **1** | Dashboard (원형 진척률) | 3h | ⏳ |
| **2** | Guide (4단계 + 오리피스 카드) | 2h | ⏳ |
| **3** | Training (단순화) | 3h | ⏳ |
| **4** | History (주간/월간 탭 + bar chart) | 3h | ⏳ |
| **5** | Session Detail (신규) | 2h | ⏳ |
| **6** | Settings (7항목 ListTile) | 3h | ⏳ |
| **7** | 폴리싱 + 테스트 + APK | 2h | ⏳ |
| | **합계** | **~22h (3일)** | |

---

## 4. 리스크

| 리스크 | 가능성 | 영향 | 완화 |
|---|---|---|---|
| 다크→라이트 전환 시 흰 배경에 흰 글자 등 시각 깨짐 | 높 | 중 | Phase 0 직후 APK 검수, 하드코딩된 `Colors.white*` 일괄 치환 |
| 위젯 테스트 다수 실패 (텍스트 / 위치 / 위젯 트리 변경) | 높 | 중 | Phase 마다 테스트 갱신 후 다음 진행 |
| ShellRoute 도입 시 기존 push 기반 네비게이션 호환성 | 중 | 높 | 기존 `context.push('/training')` 등은 Shell 밖 라우트로 유지 — Shell 내부는 `context.go` 로 탭 전환 |
| 5세트 vs 3세트 (D1) 결정 지연 | 중 | 중 | 기본은 3세트 + 와이어프레임 텍스트 조정 (B 옵션). 변경 시 펌웨어 영향 |
| 9주차 Code Freeze 까지 시간 부족 | 중 | 높 | Phase 0+1+2 만 적용해도 와이어프레임 인상 70% 달성 가능. 나머지는 Code Freeze 후 |

---

## 5. 권장 진행 순서

1. **D1~D6 결정** — 시작 전 팀 미팅 30분 (특히 D1: 5세트 vs 3세트)
2. **Phase 0 (인프라)** 완료 → 폰 검수 → 모든 탭 작동 확인
3. **Phase 1+2** (홈/가이드 동시 가능) → 1차 데모 가능
4. **Phase 3+5** (훈련/세션 상세) — 코어 사용자 흐름 완성
5. **Phase 4+6** (추이/설정) — 디테일
6. **Phase 7** — 마무리

> **Code Freeze 까지 여력 적으면**: Phase 0+1+2+6(상단부분만) 정도가 와이어프레임 시각 일관성을 보여주는 최소 셋. 나머지는 발표 후 v1.1.

---

## 6. 즉시 다음 액션

1. 일요일 미팅 의제: D1~D6 6개 결정
2. 결정 확정 후 Phase 0 시작 (브랜치 분리 권장: `feat/ui-redesign-v2`)
3. 각 Phase 별 PR 1개 — 누적 머지로 회귀 차단
