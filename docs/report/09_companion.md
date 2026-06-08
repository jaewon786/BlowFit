# 제 9 장  동반자 모드 및 알림

> 호흡근 훈련은 매일 5 분 정도의 짧은 활동이지만, **꾸준한 동기 부여** 가 가장 큰 challenge 이다. BRELOW 는 이 문제를 사용자 본인의 게이미피케이션(BreLow 캐릭터, 마일스톤) 외에 **가족 / 배우자의 응원** 을 통한 사회적 동기 부여로 보완한다. 본 장은 동반자 모드의 설계와 구현을 기술한다.

---

## 9.1 역할 분리 — Device vs Companion

### 9.1.1 역할 결정

앱 첫 실행 시 `/role-select` 화면에서 사용자가 한 번만 선택한다. 변경 불가 (선택 후 앱 reinstall 필요).

```dart
// core/storage/user_role_store.dart
enum AppRole { device, companion }
```

### 9.1.2 Redirect 규칙

`main.dart::GoRouter.redirect` 가 역할별 접근 제어를 수행한다.

| 현재 역할 | 접근 시도 | 결과 |
|---|---|---|
| companion | `/companion` 이외 | → `/companion` 으로 redirect |
| device | `/companion` 또는 `/role-select` | → `/` 로 redirect |
| 미지정 | 모든 라우트 | → `/role-select` 로 redirect |

### 9.1.3 화면 차이

표 9.1 — 역할별 노출 화면.

| 화면 | Device | Companion |
|---|---|---|
| / (홈) | ✅ | ❌ (companion 으로 redirect) |
| /training | ✅ | ❌ |
| /history /trend /profile | ✅ | ❌ |
| /my-code | ✅ (코드 발급) | ❌ |
| /companion | ❌ | ✅ (연결된 사용자의 카드) |
| /companion-code-input | ❌ | ✅ (코드 입력 화면) |
| /onboarding /profile-setup /pimax-measure | ✅ | ❌ |

---

## 9.2 6 자리 연결 코드

### 9.2.1 알고리즘

```dart
// core/pairing/pairing_service.dart
String _generateCode() {
  // 6자리 영숫자, 헷갈리기 쉬운 0/O/1/I/L 제외
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  return List.generate(6, (_) => chars[_rng.nextInt(chars.length)]).join();
}
```

코드 9.1 — 가독성을 위해 0/O/1/I/L 등 혼동 문자를 제외한 32 문자 알파벳에서 6 자리 선택. 총 32⁶ ≈ 10 억 가지 조합.

### 9.2.2 코드 충돌 방지

새 코드 발급 시 Firestore `codes/{code}` 가 이미 존재하면 다시 생성한다 (transactional check).

```dart
Future<String> _allocateCode(String uid) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    final code = _generateCode();
    final ref = _db.collection('codes').doc(code);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({'uid': uid});
      return code;
    }
  }
  throw StateError('코드 발급 실패');
}
```

---

## 9.3 페어링 흐름

그림 9.1 — 동반자 페어링 시퀀스.

```
디바이스 사용자                            동반자
  │                                          │
  │ /my-code 진입                            │
  │   ▼                                      │
  │ ensureMyCode(name)                       │
  │   ├─► users/{uid}.set({connectionCode})  │
  │   └─► codes/{CODE}.set({uid})            │
  │   ▲                                      │
  │ 코드 "AB3X9P" 표시                       │
  │                                          │
  │ ─── (코드 전달) ──►                      │
  │                                          │
  │                          /companion 진입│
  │                          + 코드 입력 화면│
  │                                          │
  │                          linkWithCode("AB3X9P")
  │                            ├─► codes/{CODE}.get() → uid
  │                            ├─► users/{uid}.get() → name
  │                            └─► links/{companionUid}.set({userId, userName})
  │                                          ▼
  │                          /companion 메인 화면 진입
  │                          (연결된 사용자의 데이터 listen)
```

---

## 9.4 데이터 공유 (Firestore)

### 9.4.1 백필 — `UserDataService.uploadSession()`

디바이스 사용자가 새 세션을 끝낼 때마다:

```dart
// core/pairing/user_data_service.dart
Future<void> uploadSession(SessionSummary s) async {
  await _db.collection('users').doc(_uid)
    .collection('sessions').doc(s.sessionId.toString())
    .set({
      'startedAt': Timestamp.fromDate(s.startedAt),
      'durationSec': s.duration.inSeconds,
      'maxPressure': s.maxPressure,
      'avgPressure': s.avgPressure,
      'maxInhale': s.maxInhale,
      'avgInhale': s.avgInhale,
      'orificeLevel': s.orificeLevel,
    });
}
```

### 9.4.2 listen — `CompanionDataService.watchSessions()`

동반자의 `/companion` 화면이 listen 한다.

```dart
Stream<List<RemoteSession>> watchSessions() {
  final link = ref.watch(companionLinkStoreProvider).valueOrNull;
  if (link == null) return Stream.value([]);
  return _db.collection('users').doc(link.userId)
    .collection('sessions')
    .orderBy('startedAt', descending: true).limit(30)
    .snapshots().map((s) => s.docs.map(RemoteSession.fromDoc).toList());
}
```

### 9.4.3 Firestore Security Rules

`firestore.rules`:

```
match /users/{uid} {
  allow read: if request.auth != null;
  allow write: if request.auth.uid == uid;

  match /sessions/{sid} {
    allow read: if request.auth.uid == uid
              || request.auth.uid in get(/links/$(uid)/companions).data.uids;
    allow write: if request.auth.uid == uid;
  }
}
```

→ 디바이스 사용자만 자신의 세션을 쓸 수 있고, 본인 + 연결된 동반자만 읽을 수 있다.

---

## 9.5 눈치주기 → 로컬 시스템 알림

### 9.5.1 시나리오

동반자가 사용자의 오늘 훈련 미달성을 보고 응원 메시지를 보내고 싶을 때.

```
1. 동반자가 /companion 에서 "눈치주기" 버튼 → 메시지 입력 모달
2. NudgeService.send("오늘도 호흡 훈련 하자!")
3. Firestore users/{userId}/nudges/{nid}.add(...)
4. 디바이스 사용자 폰의 Firestore listener 가 감지
5. flutter_local_notifications 가 시스템 알림 표시 — "💪 {이름} 님이 응원해요"
6. 알림 탭 → 앱이 /training-intro 로 열림
```

### 9.5.2 알림 채널

`core/notifications/local_notifications.dart`:

```dart
const _channelNudge = AndroidNotificationChannel(
  'brelow_nudge',
  '응원 알림',
  description: '동반자가 보낸 응원 메시지',
  importance: Importance.high,
);
```

### 9.5.3 알림 디바운스

동반자가 짧은 시간에 여러 번 누르는 것을 방지하기 위해 30 분 throttle 적용 (`NudgeService::_lastSentAt`).

---

## 9.6 BLE Foreground Service 의 영구 알림

동반자 모드와 별도로, 디바이스 모드 앱은 BLE 자동 재연결을 위해 Android Foreground Service 를 실행한다. 이 service 는 영구 알림을 표시해야 한다 (Android 정책).

표 9.2 — Foreground Service 알림.

| 항목 | 값 |
|---|---|
| 채널 | `brelow_ble_bg` (priority `Importance.low`) |
| 제목 | "BRELOW 연결 유지 중" |
| 본문 | 현재 연결 상태 (예: "기기 연결됨", "주변 스캔 중...") |
| 아이콘 | 앱 아이콘 monochrome |

사용자에게 시각적 부담을 최소화하기 위해 silent (priority low, sound/vibration off) 로 설정. 알림 탭 시 앱 메인 화면 열림.

---

## 9.7 보안 및 프라이버시

| 항목 | 처리 |
|---|---|
| 인증 | Firebase Anonymous Auth (별도 회원가입 X) |
| 사용자 식별 | UID (서버 측 자동 발급, 영속) |
| 개인 정보 | 이름만 저장. 나이/성별/PImax 등은 Firestore 전송 X (로컬만) |
| 데이터 삭제 | 연결 해제 시 `links/{uid}` 삭제 → 동반자 접근 차단 |
| 세션 데이터 | Firestore 30 일 retention (auto-delete TTL) |

표 9.3 — 동반자 모드의 프라이버시 정책.

> 본 MVP 는 의료기기가 아닌 라이프스타일 보조 기기이며 임상 시험에 사용되지 않는다. 정식 임상 단계 진입 시 KISA 개인정보 영향평가 + 의료기기법 준수 검토가 필요하다.

---

## 9.8 향후 개선

| 항목 | 설명 |
|---|---|
| ▶ 동반자 다중 연결 | 현재 1:1. 가족 여러 명을 동시에 연결 |
| ▶ 응원 템플릿 | 자주 쓰는 응원 문구 5 종을 1-tap 으로 전송 |
| ▶ 응원 이력 화면 | 디바이스 사용자가 받은 응원을 모아보는 화면 |
| ▶ 챌린지 | 디바이스 사용자 + 동반자가 함께하는 챌린지 (예: 30 일 연속) |

---

*— 제 9 장 끝 —*
