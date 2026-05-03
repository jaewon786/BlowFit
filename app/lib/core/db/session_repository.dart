import 'package:drift/drift.dart';
import 'package:meta/meta.dart' show visibleForTesting;

import '../models/pressure_sample.dart';
import 'app_database.dart';
import 'trend_bucketing.dart';

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

  /// 첫 세션의 호기 압력 통계 (Profile 베이스라인 카드용).
  /// 없으면 null.
  Future<FirstSessionStats?> firstSessionStats() async {
    final q = _db.select(_db.sessions)
      ..orderBy([(t) => OrderingTerm.asc(t.receivedAt)])
      ..limit(1);
    final row = await q.getSingleOrNull();
    if (row == null) return null;
    return FirstSessionStats(
      avgPressure: row.avgPressure,
      maxPressure: row.maxPressure,
      receivedAt: row.receivedAt,
    );
  }

  /// 최근 12주 (월요일 시작, rolling) 의 주별 호기 평균/최대.
  /// A안 — 오늘이 속한 주를 12번째로 잡고 11주 거슬러 올라가 총 12 항목 반환.
  /// 빈 주 (세션 0개) 도 [WeeklyAggregate.empty] 로 포함되어 차트가 자리를
  /// 비워둘 수 있게 한다.
  Stream<List<WeeklyAggregate>> watchWeeklyAggregates({
    int weeks = 12,
    DateTime Function() now = _defaultNow,
  }) {
    final currentMonday = _startOfWeek(now());
    final since = currentMonday.subtract(Duration(days: 7 * (weeks - 1)));
    return watchSince(since).map(
      (sessions) => weeklyAggregatesFrom(
        sessions,
        weeks: weeks,
        now: now,
      ),
    );
  }

  /// 이번 주 / 지난 주 호기 평균. 평균 비교 카드 (Dashboard) 에서 사용.
  /// 세션이 없는 주는 null. 양쪽 다 있으면 delta 계산 가능.
  Stream<WeekPressureAvgPair> watchWeekAvgPressurePair({
    DateTime Function() now = _defaultNow,
  }) {
    final lastWeekMonday =
        _startOfWeek(now()).subtract(const Duration(days: 7));
    return watchSince(lastWeekMonday).map(
      (sessions) => weekAvgPressurePairFrom(sessions, now: now),
    );
  }

  /// Trend 화면 — 4개 period 별 버킷 리스트.
  /// 일간 (이번 주 7일) / 주간 (이번 달 4주차) / 월간 (최근 4개월) /
  /// 년간 (올해 12개월).
  Stream<List<TrendBucket>> watchTrendBuckets(
    TrendPeriod period, {
    DateTime Function() now = _defaultNow,
  }) {
    final since = sinceForPeriod(period, now());
    return watchSince(since).map(
      (sessions) => bucketizeForPeriod(sessions, period, now: now),
    );
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

/// Pure helper exposed for unit testing.
///
/// 입력 세션 리스트 → 12개 [WeeklyAggregate] 로 버킷팅. 가장 마지막 항목이
/// 오늘이 속한 주, 첫 항목이 11주 전 주. 세션이 없는 주는 sessionCount=0
/// 으로 포함된다.
@visibleForTesting
List<WeeklyAggregate> weeklyAggregatesFrom(
  List<Session> sessions, {
  int weeks = 12,
  DateTime Function() now = _defaultNow,
}) {
  final currentMonday = _startOfWeek(now());
  // weekStart -> running totals
  final buckets = <DateTime, _WeekAccumulator>{};
  for (var i = 0; i < weeks; i++) {
    final start = currentMonday.subtract(Duration(days: 7 * (weeks - 1 - i)));
    buckets[start] = _WeekAccumulator(weekStart: start);
  }

  final windowStart = currentMonday.subtract(Duration(days: 7 * (weeks - 1)));
  final windowEnd = currentMonday.add(const Duration(days: 7));

  for (final s in sessions) {
    final t = s.receivedAt;
    if (t.isBefore(windowStart) || !t.isBefore(windowEnd)) continue;
    final monday = _startOfWeek(t);
    final acc = buckets[monday];
    if (acc == null) continue; // 윈도우 밖 — 안 들어옴
    acc.add(s);
  }

  return buckets.values
      .map((b) => b.snapshot())
      .toList(growable: false);
}

/// Pure helper exposed for unit testing.
@visibleForTesting
WeekPressureAvgPair weekAvgPressurePairFrom(
  List<Session> sessions, {
  DateTime Function() now = _defaultNow,
}) {
  final thisMonday = _startOfWeek(now());
  final lastMonday = thisMonday.subtract(const Duration(days: 7));
  double thisSum = 0, lastSum = 0;
  int thisN = 0, lastN = 0;
  for (final s in sessions) {
    final t = s.receivedAt;
    if (!t.isBefore(thisMonday)) {
      // 이번 주
      thisSum += s.avgPressure;
      thisN++;
    } else if (!t.isBefore(lastMonday)) {
      // 지난 주
      lastSum += s.avgPressure;
      lastN++;
    }
  }
  return (
    thisWeek: thisN > 0 ? thisSum / thisN : null,
    lastWeek: lastN > 0 ? lastSum / lastN : null,
  );
}

/// 한 주 단위 집계.
class WeeklyAggregate {
  final DateTime weekStart;
  final double? avgExhale;
  final double? maxExhale;
  final int sessionCount;

  const WeeklyAggregate({
    required this.weekStart,
    required this.avgExhale,
    required this.maxExhale,
    required this.sessionCount,
  });

  bool get isEmpty => sessionCount == 0;

  @override
  bool operator ==(Object other) =>
      other is WeeklyAggregate &&
      other.weekStart == weekStart &&
      other.avgExhale == avgExhale &&
      other.maxExhale == maxExhale &&
      other.sessionCount == sessionCount;

  @override
  int get hashCode =>
      Object.hash(weekStart, avgExhale, maxExhale, sessionCount);
}

class FirstSessionStats {
  final double avgPressure;
  final double maxPressure;
  final DateTime receivedAt;

  const FirstSessionStats({
    required this.avgPressure,
    required this.maxPressure,
    required this.receivedAt,
  });
}

typedef WeekPressureAvgPair = ({double? thisWeek, double? lastWeek});

class _WeekAccumulator {
  final DateTime weekStart;
  double avgSum = 0;
  double maxSum = 0;
  double maxOfWeek = -double.infinity;
  int n = 0;

  _WeekAccumulator({required this.weekStart});

  void add(Session s) {
    avgSum += s.avgPressure;
    maxSum += s.maxPressure;
    if (s.maxPressure > maxOfWeek) maxOfWeek = s.maxPressure;
    n++;
  }

  WeeklyAggregate snapshot() {
    return WeeklyAggregate(
      weekStart: weekStart,
      avgExhale: n > 0 ? avgSum / n : null,
      // 주의 max 는 평균이 아니라 그 주의 최댓값.
      maxExhale: n > 0 ? maxOfWeek : null,
      sessionCount: n,
    );
  }
}
