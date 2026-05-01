import 'package:drift/drift.dart';
import 'package:meta/meta.dart' show visibleForTesting;

import '../models/pressure_sample.dart';
import 'app_database.dart';

class SessionRepository {
  SessionRepository(this._db);

  final AppDatabase _db;

  Future<int> insertFromSummary(SessionSummary s) {
    final companion = SessionsCompanion.insert(
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
    );
    // Idempotent on retransmission: same deviceSessionId overwrites.
    return _db.into(_db.sessions).insert(
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [_db.sessions.deviceSessionId],
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

  /// Distinct-day streak ending today: 오늘부터 거꾸로 빈 날 처음 나올 때까지.
  /// 새 세션이 들어오면 자동 갱신.
  Stream<int> watchConsecutiveDays({DateTime Function() now = _defaultNow}) {
    // Cap lookback to 60 days so we don't load every session for the streak.
    final since = _startOfDay(now()).subtract(const Duration(days: 60));
    return watchSince(since).map((sessions) =>
        consecutiveDaysFromToday(sessions, now: now));
  }

  /// 이번 주(월요일 시작)의 1+ 세션 일자 수.
  Stream<int> watchWeekHits({DateTime Function() now = _defaultNow}) {
    final monday = _startOfWeek(now());
    return watchSince(monday).map((sessions) =>
        sessionsToDistinctDates(sessions).length);
  }

  /// 오늘 누적 훈련 시간.
  Stream<Duration> watchTodayDuration({DateTime Function() now = _defaultNow}) {
    final today = _startOfDay(now());
    return watchSince(today).map((sessions) => Duration(
          seconds: sessions.fold<int>(0, (acc, s) => acc + s.durationSec),
        ));
  }

  /// 가장 오래된 세션 날짜 — 오리피스 단계 추천에 사용.
  Future<DateTime?> firstSessionDate() async {
    final q = _db.select(_db.sessions)
      ..orderBy([(t) => OrderingTerm.asc(t.receivedAt)])
      ..limit(1);
    final row = await q.getSingleOrNull();
    return row?.receivedAt;
  }

  /// 세션 상세 화면용 단건 조회.
  Future<Session?> findById(int id) {
    return (_db.select(_db.sessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }
}

DateTime _defaultNow() => DateTime.now();

DateTime _startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime _startOfWeek(DateTime t) {
  // Dart weekday: Mon=1..Sun=7. Walk back to last Monday at 00:00.
  final daysFromMonday = t.weekday - DateTime.monday;
  return _startOfDay(t).subtract(Duration(days: daysFromMonday));
}

/// Pure helper exposed for unit testing.
@visibleForTesting
Set<DateTime> sessionsToDistinctDates(List<Session> sessions) {
  return sessions.map((s) => _startOfDay(s.receivedAt)).toSet();
}

/// Pure helper exposed for unit testing.
@visibleForTesting
int consecutiveDaysFromToday(
  List<Session> sessions, {
  DateTime Function() now = _defaultNow,
}) {
  final dates = sessionsToDistinctDates(sessions);
  if (dates.isEmpty) return 0;
  var count = 0;
  var day = _startOfDay(now());
  while (dates.contains(day)) {
    count++;
    day = day.subtract(const Duration(days: 1));
  }
  return count;
}
