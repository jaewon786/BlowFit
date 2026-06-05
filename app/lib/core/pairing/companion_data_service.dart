import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'pairing_service.dart';
import 'remote_session.dart';

/// 연결된 디바이스 사용자의 훈련 세션 스트림 (Firestore).
/// 연결 안 됐으면 빈 리스트.
final companionSessionsProvider =
    StreamProvider<List<RemoteSession>>((ref) {
  final link = ref.watch(companionLinkProvider).valueOrNull;
  if (link == null) return Stream.value(const <RemoteSession>[]);
  final col = FirebaseFirestore.instance
      .collection('users')
      .doc(link.userId)
      .collection('sessions')
      .orderBy('startedAt');
  return col.snapshots().map(
        (snap) =>
            snap.docs.map((d) => RemoteSession.fromDoc(d.data())).toList(),
      );
});

/// 위 스트림을 로컬 [Session] 으로 변환 — 기존 집계 헬퍼(trend_bucketing 등)
/// 재사용용. 데이터 없으면 빈 리스트.
final companionLocalSessionsProvider = Provider<List<Session>>((ref) {
  final remote = ref.watch(companionSessionsProvider).valueOrNull ??
      const <RemoteSession>[];
  return remote.map((r) => r.toLocalSession()).toList();
});

/// 오늘 요약 (동반자 카드용).
typedef CompanionToday = ({
  int sessionCount,
  int totalMinutes,
  double avgExhale,
  double avgInhale,
});

final companionTodayProvider = Provider<CompanionToday>((ref) {
  final sessions = ref.watch(companionLocalSessionsProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var count = 0, sec = 0;
  var exSum = 0.0, inSum = 0.0;
  for (final s in sessions) {
    final t = s.receivedAt;
    if (t.isBefore(today)) continue;
    count++;
    sec += s.durationSec;
    exSum += s.avgPressure;
    inSum += s.avgInhale;
  }
  return (
    sessionCount: count,
    totalMinutes: (sec / 60).round(),
    avgExhale: count > 0 ? exSum / count : 0,
    avgInhale: count > 0 ? inSum / count : 0,
  );
});
