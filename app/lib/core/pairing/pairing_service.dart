import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'companion_link_store.dart';

/// Firestore 기반 연결 코드 페어링.
///
/// 데이터 모델:
///   users/{uid}            { displayName, connectionCode, updatedAt }
///   codes/{CODE}           { uid }                       — 코드→사용자 조회용
///   links/{companionUid}   { userId, userName, linkedAt } — 동반자→사용자 연결
class PairingService {
  PairingService(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  /// 디바이스 사용자: 내 연결 코드 가져오기(없으면 생성) + displayName 저장.
  /// 동반자에게 이 코드를 알려주면 연결된다.
  Future<String> ensureMyCode(String displayName) async {
    final uid = _uid;
    if (uid == null) throw StateError('Firebase 미인증 상태');
    final userRef = _db.collection('users').doc(uid);
    final snap = await userRef.get();
    var code = snap.data()?['connectionCode'] as String?;
    if (code == null || code.isEmpty) {
      code = await _allocateCode(uid);
    }
    await userRef.set({
      'displayName': displayName,
      'connectionCode': code,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true),);
    return code;
  }

  /// 동반자: 코드로 사용자 조회 → 연결 저장. 코드가 없으면 null 반환.
  Future<CompanionLink?> linkWithCode(String rawCode) async {
    final uid = _uid;
    if (uid == null) throw StateError('Firebase 미인증 상태');
    final code = rawCode.trim().toUpperCase();
    final codeSnap = await _db.collection('codes').doc(code).get();
    final userId = codeSnap.data()?['uid'] as String?;
    if (userId == null) return null;
    final userSnap = await _db.collection('users').doc(userId).get();
    final name = userSnap.data()?['displayName'] as String? ?? '사용자';
    await _db.collection('links').doc(uid).set({
      'userId': userId,
      'userName': name,
      'linkedAt': FieldValue.serverTimestamp(),
    });
    return CompanionLink(userId: userId, userName: name);
  }

  /// 고유 코드 할당 — 충돌 시 몇 번 재시도. codes/{code} 에 uid 기록.
  Future<String> _allocateCode(String uid) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _genCode();
      final ref = _db.collection('codes').doc(code);
      final existing = await ref.get();
      if (!existing.exists) {
        await ref.set({
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return code;
      }
    }
    // 극히 드문 연속 충돌 — 마지막 시도값 사용.
    final code = _genCode();
    await _db.collection('codes').doc(code).set({
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  // 혼동되는 글자(0/O, 1/I) 제외한 6자리 코드.
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  String _genCode() {
    final rnd = Random.secure();
    return List.generate(6, (_) => _chars[rnd.nextInt(_chars.length)]).join();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final pairingServiceProvider = Provider<PairingService>((ref) {
  return PairingService(FirebaseFirestore.instance, FirebaseAuth.instance);
});

final companionLinkStoreProvider = FutureProvider<CompanionLinkStore>((ref) {
  return CompanionLinkStore.open();
});

/// 동반자가 연결한 사용자 (로컬 캐시). 연결 성공 시 invalidate 로 갱신.
final companionLinkProvider = FutureProvider<CompanionLink?>((ref) async {
  final store = await ref.watch(companionLinkStoreProvider.future);
  return store.load();
});
