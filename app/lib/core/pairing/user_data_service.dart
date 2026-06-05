import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../db/app_database.dart';
import '../models/pressure_sample.dart';

/// 디바이스 사용자의 훈련 세션을 Firestore 에 업로드 → 동반자가 조회(Phase D).
///
///   users/{uid}/sessions/{deviceSessionId}
///     { startedAt, dayKey, durationSec, exhaleAvg/Max, inhaleAvg/Max,
///       targetHits, orificeLevel, updatedAt }
class UserDataService {
  UserDataService(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static final _dayFmt = DateFormat('yyyy-MM-dd');

  String? get _uid => _auth.currentUser?.uid;

  /// 세션 완료 시 1건 업로드 (BLE summary).
  Future<void> uploadSummary(SessionSummary s) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .doc(s.sessionId.toString())
        .set(
          _doc(
            deviceSessionId: s.sessionId,
            when: s.startedAt ?? DateTime.now(),
            durationSec: s.duration.inSeconds,
            exhaleAvg: s.avgPressure,
            exhaleMax: s.maxPressure,
            inhaleAvg: s.avgInhale,
            inhaleMax: s.maxInhale,
            targetHits: s.targetHits,
            orificeLevel: s.orificeLevel,
          ),
          SetOptions(merge: true),
        );
  }

  /// 기존 로컬 세션 일괄 업로드(백필) — 동반자가 과거 기록도 보도록.
  /// 연결 코드 화면 진입 시 호출.
  Future<void> uploadSessions(List<Session> rows) async {
    final uid = _uid;
    if (uid == null || rows.isEmpty) return;
    final col = _db.collection('users').doc(uid).collection('sessions');
    // Firestore batch 최대 500 — 450 단위로 청크.
    for (var i = 0; i < rows.length; i += 450) {
      final batch = _db.batch();
      for (final r in rows.skip(i).take(450)) {
        batch.set(
          col.doc(r.deviceSessionId.toString()),
          _doc(
            deviceSessionId: r.deviceSessionId,
            when: r.startedAt ?? r.receivedAt,
            durationSec: r.durationSec,
            exhaleAvg: r.avgPressure,
            exhaleMax: r.maxPressure,
            inhaleAvg: r.avgInhale,
            inhaleMax: r.maxInhale,
            targetHits: r.targetHits,
            orificeLevel: r.orificeLevel,
          ),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  Map<String, dynamic> _doc({
    required int deviceSessionId,
    required DateTime when,
    required int durationSec,
    required double exhaleAvg,
    required double exhaleMax,
    required double inhaleAvg,
    required double inhaleMax,
    required int targetHits,
    required int orificeLevel,
  }) {
    return {
      'deviceSessionId': deviceSessionId,
      'startedAt': Timestamp.fromDate(when),
      'dayKey': _dayFmt.format(when),
      'durationSec': durationSec,
      'exhaleAvg': exhaleAvg,
      'exhaleMax': exhaleMax,
      'inhaleAvg': inhaleAvg,
      'inhaleMax': inhaleMax,
      'targetHits': targetHits,
      'orificeLevel': orificeLevel,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

final userDataServiceProvider = Provider<UserDataService>((ref) {
  return UserDataService(FirebaseFirestore.instance, FirebaseAuth.instance);
});
