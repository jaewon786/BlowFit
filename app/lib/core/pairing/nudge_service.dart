import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/local_notifications.dart';

/// 동반자가 보낸 '눈치주기' 1건.
class Nudge {
  final String id;
  final String fromName;
  final DateTime createdAt;
  const Nudge({
    required this.id,
    required this.fromName,
    required this.createdAt,
  });
}

/// 눈치주기 송수신 — Firestore `users/{userId}/nudges/{autoId}`.
/// 동반자가 doc 추가 → 디바이스 사용자 앱이 구독해 로컬 알림 표시 + seen 처리.
class NudgeService {
  NudgeService(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  /// 동반자 → 사용자에게 눈치주기 전송.
  Future<void> sendNudge({
    required String userId,
    String fromName = '동반자',
  }) async {
    await _db.collection('users').doc(userId).collection('nudges').add({
      'fromName': fromName,
      'createdAt': FieldValue.serverTimestamp(),
      'seen': false,
    });
  }

  /// 나(사용자)에게 온 미확인 눈치 스트림.
  Stream<List<Nudge>> watchIncoming() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <Nudge>[]);
    return _db
        .collection('users')
        .doc(uid)
        .collection('nudges')
        .where('seen', isEqualTo: false)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            final ts = data['createdAt'];
            return Nudge(
              id: d.id,
              fromName: data['fromName'] as String? ?? '동반자',
              createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
            );
          }).toList(),
        );
  }

  Future<void> markSeen(String nudgeId) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('nudges')
        .doc(nudgeId)
        .update({'seen': true});
  }
}

final nudgeServiceProvider = Provider<NudgeService>((ref) {
  return NudgeService(FirebaseFirestore.instance, FirebaseAuth.instance);
});

/// 내게 온 눈치주기를 구독해 로컬 알림으로 표시 + seen 처리.
/// 앱 생애주기 동안 살아있어야 함(main 에서 watch). 디바이스 사용자에게만
/// 의미 있지만(동반자 uid 엔 눈치가 안 옴) 역할 무관하게 안전하게 동작.
final nudgeListenerProvider = Provider<void>((ref) {
  final service = ref.watch(nudgeServiceProvider);
  final shown = <String>{};
  final sub = service.watchIncoming().listen((nudges) async {
    for (final n in nudges) {
      if (!shown.add(n.id)) continue; // 중복 표시 방지
      await LocalNotifications.show(
        title: '훈련 응원이 도착했어요! 💪',
        body: '동반자가 훈련을 응원해요. 오늘도 호흡 훈련 어떠세요?',
      );
      await service.markSeen(n.id);
    }
  });
  ref.onDispose(sub.cancel);
});
