import 'package:drift/drift.dart';

import '../models/pressure_sample.dart';
import 'app_database.dart';

class SessionRepository {
  SessionRepository(this._db);

  final AppDatabase _db;

  Future<int> insertFromSummary(SessionSummary s) {
    return _db.into(_db.sessions).insertOnConflictUpdate(
          SessionsCompanion.insert(
            deviceSessionId: s.sessionId,
            startedAt: Value(s.startedAt),
            durationSec: s.duration.inSeconds,
            maxPressure: s.maxPressure,
            avgPressure: s.avgPressure,
            enduranceSec: s.endurance.inSeconds,
            orificeLevel: s.orificeLevel,
            targetHits: s.targetHits,
            sampleCount: s.sampleCount,
            crc32: s.crc32,
          ),
        );
  }

  Stream<List<Session>> watchRecent({int limit = 30}) {
    final q = _db.select(_db.sessions)
      ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)])
      ..limit(limit);
    return q.watch();
  }

  /// Sessions within [since, now]. Used by the history screen trend chart.
  Stream<List<Session>> watchSince(DateTime since) {
    final q = _db.select(_db.sessions)
      ..where((t) => t.receivedAt.isBiggerOrEqualValue(since))
      ..orderBy([(t) => OrderingTerm.asc(t.receivedAt)]);
    return q.watch();
  }

  Future<void> deleteAll() => _db.delete(_db.sessions).go();
}
