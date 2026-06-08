# 제 10 장  검증 및 평가

> 본 장은 BRELOW 의 빌드 / 정적 분석 / 단위 테스트 결과와 BLE 안정성, PImax 측정 정확도, 그리고 사용자 시나리오 점검을 정리한다.

---

## 10.1 빌드 및 CI

### 10.1.1 펌웨어 빌드

```bash
cd firmware-esp32
pio run -e lilygo-t-display-s3
```

표 10.1 — v4.1 빌드 결과 (2026-06 기준).

| 지표 | 값 |
|---|---|
| 빌드 시간 | 약 23 ~ 95 s (incremental / clean) |
| RAM 사용 | 96,380 / 327,680 B = 29.4 % |
| Flash 사용 | 1,522,749 / 6,553,600 B = 23.2 % |
| 결과 | `Successfully created esp32s3 image` |

> LVGL `LV_USE_PERF_MONITOR` 매크로 재정의 경고 외에 오류 없음. ESP32-S3 의 16 MB Flash / 8 MB PSRAM 에 비해 여유롭다.

### 10.1.2 앱 빌드

```bash
cd app
flutter analyze       # 정적 분석
flutter test          # 단위·위젯 테스트
flutter build apk --debug
```

표 10.2 — v4.1 앱 빌드 결과.

| 항목 | 결과 |
|---|---|
| `flutter analyze` | 0 error (info / warning 만 — 기존 코드의 trailing comma 등) |
| `flutter build apk --debug` | 성공 (약 19 ~ 50 s) |
| APK 크기 | `app-debug.apk` 약 60 MB |

---

## 10.2 BLE 안정성

### 10.2.1 SeqGapDetector

앱은 Pressure Stream 의 `seq` 를 추적해 패킷 손실 / 재연결을 모니터링한다.

```dart
// core/ble/seq_gap_detector.dart
class BleHealth {
  final int total;       // 누적 수신 sample 수
  final int dropped;     // 누락 sample 수
  final int resets;      // 재연결 횟수
  double get lossRate => total == 0 ? 0 : dropped / total;
}
```

### 10.2.2 합격 기준 (`docs/dev-plan.md` T6)

표 10.3 — BLE 안정성 KPI.

| 항목 | 기준 | 측정 방법 |
|---|---|---|
| 10 분 연속 stream loss rate | < 5 % | 디바이스 ON → /training 화면 10 분 |
| SeqGap resets | 0 (10 분 동안 재연결 없음) | 〃 |
| MTU 185 협상 성공률 | ≥ 90 % (Android 2 대) | Galaxy S20 / S22 |

### 10.2.3 측정 환경

- 디바이스: Galaxy S20 + Galaxy S22 (Android 13)
- 거리: 1 m 이내, 직선 시야
- 간섭: WiFi 2.4 GHz, Bluetooth 키보드 동시 사용 환경

> 발표 시연 시에는 디바이스를 폰 옆에 두고 사용하므로 위 환경이 일반적 사용 패턴과 일치한다.

---

## 10.3 압력 측정 / 오리피스 검증

### 10.3.1 시리얼 압력 검증 (T4, `docs/dev-plan.md`)

펌웨어 첫 플래시 후 시리얼 모니터에 `sensor::currentCmH2O()` 출력. 합격 기준:

| 시나리오 | 기준값 |
|---|---|
| 입에 물기 전 5 초 (정지) | 0 ± 0.5 cmH₂O |
| 약하게 호기 | +5 ~ +10 cmH₂O 응답 |
| 강하게 호기 | +20 ~ +30 cmH₂O |
| 약하게 흡기 | −5 ~ −10 cmH₂O |
| 강하게 흡기 | −30 ~ −60 cmH₂O |

### 10.3.2 오리피스 디스크 검증 (T5)

표 10.4 — 오리피스 직경 ↔ 압력 분포 합격 기준.

| 디스크 | 직경 | 동일 호흡 강도에서의 평균 maxPressure | 단계 간 분리 |
|---|---|---|---|
| LOW | 4 mm | 10 ~ 15 cmH₂O | ✅ MEDIUM 와 명확 분리 |
| MEDIUM | 3 mm | 18 ~ 25 cmH₂O | ✅ HIGH 와 명확 분리 |
| HIGH | 2 mm | 30 ~ 40 cmH₂O | — |

각 디스크 10 회 입력 후 앱의 `Sessions.maxPressure` 분포 확인. 동일 단계 ±1 cmH₂O 이내 일관성 + 단계 간 차이 명확.

### 10.3.3 영점 보정 정확도

부팅 직후 2 초 영점 보정 → 사용자 정지 상태에서 5 초간 측정 → 평균이 0 ± 0.3 cmH₂O 이어야 함. 본 MVP 검증 시 합격.

---

## 10.4 PImax / MEP 측정 정확도

### 10.4.1 검증 절차

1. 측정 화면 진입 → 호기 측정 5 s, 흡기 측정 5 s
2. 같은 사용자가 5 회 반복 측정
3. 표준편차 계산

### 10.4.2 합격 기준

| 항목 | 기준 |
|---|---|
| 5 회 측정 표준편차 / 평균 (CV) | < 15 % |
| Black & Hyatt 1969 일반 성인 평균과의 부합 | 70 ~ 120 cmH₂O 범위 안 |

### 10.4.3 한계

▶ 본 MVP 는 임상 표준 측정 절차 (1 초 sustained, sitting position, mouth seal 표준화) 를 완전히 재현하지 않는다. 가정 자가 측정의 편의성을 우선하고 5 초 peak hold 로 근사했기에 절대값 정확도는 보장하지 않는다. 단, **개인 내 일관성** (같은 사용자의 반복 측정 일관성) 은 % 비율 계산에 충분하다.

---

## 10.5 사용자 시나리오 walkthrough

### 10.5.1 시나리오 1 — 첫 사용 (디바이스 사용자)

| 단계 | 화면 | 점검 항목 | 결과 |
|---|---|---|---|
| 1 | /role-select | 디바이스 / 동반자 선택, 변경 불가 안내 | ✅ |
| 2 | /onboarding | 4 슬라이드 swipe, "건너뛰기" 동작 | ✅ |
| 3 | /profile-setup | 이름/나이/성별 유효성 검증 | ✅ |
| 4 | /pimax-measure | 호기 측정 5 s → 흡기 측정 5 s → summary | ✅ (v4.1 시행착오 §7.5.3 해결) |
| 5 | /connect | BLE 스캔 + 페어링 + SET_TARGET 자동 전송 | ✅ |
| 6 | / (홈) | 초기 상태 (NoData 헤드라인 + Egg 캐릭터) | ✅ |

### 10.5.2 시나리오 2 — 일일 훈련

| 단계 | 화면 | 점검 항목 | 결과 |
|---|---|---|---|
| 1 | / | 헤드라인 (이번 주 추세) + 통계 카드 | ✅ |
| 2 | /training-intro | 체크리스트 + 시작 버튼 | ✅ |
| 3 | /training | 4-phase 게이지, 햅틱 cue, 압력 stream | ✅ |
| 4 | /result | hero 점수 + 4 stat | ✅ |
| 5 | /history | 신규 세션이 캘린더에 표시 | ✅ |
| 6 | BreLow 캐릭터 | happy 모션 1 회 → alive 복귀 | ✅ |

### 10.5.3 시나리오 3 — 진화

| 단계 | 점검 항목 | 결과 |
|---|---|---|
| 누적 7 일 distinct 훈련일 도달 | Egg → Baby bloom 모션 | ✅ |
| 누적 30 일 도달 | Baby → Oxygen bloom 모션 | ✅ |
| 진화 시 시각적 공백 | 없어야 함 (선로딩 적용) | ✅ |

### 10.5.4 시나리오 4 — 동반자 연결

| 단계 | 점검 항목 | 결과 |
|---|---|---|
| 디바이스 사용자가 /my-code 진입 | 6 자리 코드 발급 + Firestore codes/{CODE} 생성 | ✅ |
| 동반자가 코드 입력 | links/{companionUid} 생성, /companion 진입 | ✅ |
| 디바이스 사용자가 훈련 1 회 완료 | 동반자 /companion 화면에 새 세션 카드 등장 | ✅ |
| 동반자가 "눈치주기" 클릭 | 디바이스 사용자 폰에 시스템 알림 표시 | ✅ |

---

## 10.6 단위 테스트

### 10.6.1 앱 테스트 목록

표 10.5 — `app/test/` 의 주요 테스트.

| 파일 | 검증 |
|---|---|
| `session_repository_test.dart` | insertFromSummary 멱등, watchConsecutiveDays, watchWeekHits, watchTodayDuration, deviceSessionId 충돌 시 덮어쓰기 |
| `trend_bucketing_test.dart` | 일/주/월/년 bucket 함수의 경계 조건 |
| `milestone_engine_test.dart` | 5 마일스톤 달성 일자 계산 |
| `settings_screen_test.dart` | 강도 변경 + 저장 동작 |
| `session_detail_screen_test.dart` | 세션 상세 표시 |
| `history_screen_test.dart` | 캘린더 + 최근 세션 렌더링 |

### 10.6.2 펌웨어 호스트 테스트

`firmware-esp32/test/` (Native 환경, GoogleTest). `sensor`, `session` 의 pure 함수를 PC 에서 검증.

표 10.6 — 펌웨어 호스트 테스트.

| 파일 | 검증 |
|---|---|
| `test_sensor.cpp` | `sensor::adcToCmH2O()` 의 변환 정확도 |
| `test_session.cpp` | state 전이, turn cycle, 통계 누적 |

---

## 10.7 알려진 한계

| 항목 | 설명 |
|---|---|
| ❌ iOS 미지원 | 본 학기 작업 우선순위 조정. Flutter 코드는 iOS 호환이나 BLE 권한 / Foreground service 가 미작동. |
| ❌ 디바이스 케이스 양산 사양 미정 | 시제품 3D 프린트 단계. 사출 금형 제작은 다음 단계. |
| ⚠️ Samsung Health 의존 | `/sleep-effect` 는 Samsung Health Data SDK 가 설치된 Galaxy 기기에서만 동작. |
| ⚠️ Firebase 의존 | 동반자 모드는 인터넷 필요. 사용자가 회원가입 없이 익명 인증 사용. |
| ⚠️ PImax 자동 추적 미구현 | §6.6 참조. 사용자가 주기적으로 수동 재측정 필요. |
| ⚠️ 배터리 충전 감지 false negative | 충전 초기(VBAT < 4.15 V) 일시적 미감지 가능. §4.9.3 참조. |
| ⚠️ 측정 표준 미준수 | PImax/MEP 측정은 임상 표준과 다르며 절대값 보다는 개인 내 일관성을 보장한다. §10.4.3 참조. |

표 10.7 — 알려진 한계 일람. ❌ = 본 MVP 범위 밖, ⚠️ = 동작은 하나 제한 있음.

---

*— 제 10 장 끝 —*
