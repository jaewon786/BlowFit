import 'package:cloud_firestore/cloud_firestore.dart';

import '../db/app_database.dart';

/// Firestore `users/{uid}/sessions/{id}` 1건. 동반자가 읽어 표시.
class RemoteSession {
  final int deviceSessionId;
  final DateTime startedAt;
  final int durationSec;
  final double exhaleAvg;
  final double exhaleMax;
  final double inhaleAvg;
  final double inhaleMax;
  final int targetHits;
  final int orificeLevel;

  const RemoteSession({
    required this.deviceSessionId,
    required this.startedAt,
    required this.durationSec,
    required this.exhaleAvg,
    required this.exhaleMax,
    required this.inhaleAvg,
    required this.inhaleMax,
    required this.targetHits,
    required this.orificeLevel,
  });

  factory RemoteSession.fromDoc(Map<String, dynamic> d) {
    final ts = d['startedAt'];
    final when = ts is Timestamp ? ts.toDate() : DateTime.now();
    double dbl(String k) => (d[k] as num?)?.toDouble() ?? 0;
    int intg(String k) => (d[k] as num?)?.toInt() ?? 0;
    return RemoteSession(
      deviceSessionId: intg('deviceSessionId'),
      startedAt: when,
      durationSec: intg('durationSec'),
      exhaleAvg: dbl('exhaleAvg'),
      exhaleMax: dbl('exhaleMax'),
      inhaleAvg: dbl('inhaleAvg'),
      inhaleMax: dbl('inhaleMax'),
      targetHits: intg('targetHits'),
      orificeLevel: intg('orificeLevel'),
    );
  }

  /// 기존 집계 로직(trend_bucketing / session_repository helpers)을 재사용하기
  /// 위해 로컬 Drift [Session] 형태로 변환. receivedAt = startedAt.
  Session toLocalSession() => Session(
        id: 0,
        deviceSessionId: deviceSessionId,
        startedAt: startedAt,
        durationSec: durationSec,
        maxPressure: exhaleMax,
        avgPressure: exhaleAvg,
        avgInhale: inhaleAvg,
        maxInhale: inhaleMax,
        enduranceSec: 0,
        orificeLevel: orificeLevel,
        targetHits: targetHits,
        sampleCount: 0,
        crc32: 0,
        receivedAt: startedAt,
      );
}
