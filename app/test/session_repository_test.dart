import 'package:blowfit/core/db/app_database.dart';
import 'package:blowfit/core/db/session_repository.dart';
import 'package:blowfit/core/models/pressure_sample.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

SessionSummary _summary({
  required int id,
  DateTime? startedAt,
  Duration duration = const Duration(minutes: 4),
  double maxPressure = 28.0,
  double avgPressure = 22.0,
  Duration endurance = const Duration(seconds: 180),
  int orifice = 1,
  int hits = 3,
  int samples = 24000,
  int crc = 0,
}) {
  return SessionSummary(
    sessionId: id,
    startedAt: startedAt,
    duration: duration,
    maxPressure: maxPressure,
    avgPressure: avgPressure,
    endurance: endurance,
    orificeLevel: orifice,
    targetHits: hits,
    sampleCount: samples,
    crc32: crc,
  );
}

void main() {
  late AppDatabase db;
  late SessionRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('insertFromSummary persists all fields', () async {
    final start = DateTime.utc(2026, 4, 25, 10);
    await repo.insertFromSummary(_summary(
      id: 7,
      startedAt: start,
      duration: const Duration(minutes: 4, seconds: 30),
      maxPressure: 31.5,
      avgPressure: 24.7,
      endurance: const Duration(seconds: 240),
      orifice: 2,
      hits: 5,
      samples: 27000,
      crc: 0xDEADBEEF,
    ));

    final rows = await db.select(db.sessions).get();
    expect(rows, hasLength(1));
    final r = rows.single;
    expect(r.deviceSessionId, 7);
    expect(r.startedAt!.isAtSameMomentAs(start), isTrue);
    expect(r.durationSec, 270);
    expect(r.maxPressure, closeTo(31.5, 0.001));
    expect(r.avgPressure, closeTo(24.7, 0.001));
    expect(r.enduranceSec, 240);
    expect(r.orificeLevel, 2);
    expect(r.targetHits, 5);
    expect(r.sampleCount, 27000);
    expect(r.crc32, 0xDEADBEEF);
  });

  test('insertFromSummary upserts on deviceSessionId conflict', () async {
    await repo.insertFromSummary(_summary(id: 1, maxPressure: 20.0));
    await repo.insertFromSummary(_summary(id: 1, maxPressure: 33.0));

    final rows = await db.select(db.sessions).get();
    expect(rows, hasLength(1), reason: 'unique key on deviceSessionId');
    expect(rows.single.maxPressure, closeTo(33.0, 0.001));
  });

  test('watchRecent returns newest-by-receivedAt first, capped to limit', () async {
    // Drift stores receivedAt with second granularity, so space inserts so the
    // ordering by receivedAt DESC is unambiguous.
    for (var i = 1; i <= 5; i++) {
      await repo.insertFromSummary(_summary(id: i));
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    final list = await repo.watchRecent(limit: 3).first;
    expect(list, hasLength(3));
    expect(list.map((s) => s.deviceSessionId), [5, 4, 3]);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('watchSince filters by receivedAt cutoff', () async {
    await repo.insertFromSummary(_summary(id: 1));
    final cutoff = DateTime.now().add(const Duration(seconds: 1));
    // Wait past the cutoff so the next insert's receivedAt > cutoff.
    await Future<void>.delayed(const Duration(seconds: 2));
    await repo.insertFromSummary(_summary(id: 2));

    final after = await repo.watchSince(cutoff).first;
    expect(after.map((s) => s.deviceSessionId), [2]);
  });

  test('deleteAll empties the table', () async {
    await repo.insertFromSummary(_summary(id: 1));
    await repo.insertFromSummary(_summary(id: 2));
    await repo.deleteAll();
    final rows = await db.select(db.sessions).get();
    expect(rows, isEmpty);
  });

  test('null startedAt round-trips (RTC unset case)', () async {
    await repo.insertFromSummary(_summary(id: 99, startedAt: null));
    final r = (await db.select(db.sessions).get()).single;
    expect(r.startedAt, isNull);
  });

  // --------------------------------------------------------------
  // Stats helpers
  // --------------------------------------------------------------

  Future<void> seedAt(DateTime receivedAt, {required int id, int durationSec = 240}) {
    return db.into(db.sessions).insert(SessionsCompanion.insert(
      deviceSessionId: id,
      durationSec: durationSec,
      maxPressure: 28.0,
      avgPressure: 22.0,
      enduranceSec: 180,
      orificeLevel: 1,
      targetHits: 3,
      sampleCount: 24000,
      crc32: 0,
      receivedAt: Value(receivedAt),
    ));
  }

  group('consecutiveDaysFromToday (pure)', () {
    DateTime today() => DateTime(2026, 4, 25);
    Session sessionAt(DateTime t, {int id = 1}) => Session(
          id: id,
          deviceSessionId: id,
          startedAt: null,
          durationSec: 240,
          maxPressure: 28.0,
          avgPressure: 22.0,
          enduranceSec: 180,
          orificeLevel: 1,
          targetHits: 3,
          sampleCount: 24000,
          crc32: 0,
          receivedAt: t,
        );

    test('empty list returns zero', () {
      expect(consecutiveDaysFromToday([], now: today), 0);
    });

    test('only today returns one', () {
      expect(consecutiveDaysFromToday([sessionAt(today())], now: today), 1);
    });

    test('today + yesterday returns two', () {
      final list = [
        sessionAt(today(), id: 1),
        sessionAt(today().subtract(const Duration(days: 1)), id: 2),
      ];
      expect(consecutiveDaysFromToday(list, now: today), 2);
    });

    test('skip in middle breaks streak', () {
      // today + 2-days-ago, missing yesterday → streak = 1
      final list = [
        sessionAt(today(), id: 1),
        sessionAt(today().subtract(const Duration(days: 2)), id: 2),
      ];
      expect(consecutiveDaysFromToday(list, now: today), 1);
    });

    test('no session today returns zero', () {
      // yesterday only → today is missing → streak = 0
      final list = [sessionAt(today().subtract(const Duration(days: 1)))];
      expect(consecutiveDaysFromToday(list, now: today), 0);
    });

    test('multiple sessions same day count as one day', () {
      final list = [
        sessionAt(today(), id: 1),
        sessionAt(today().add(const Duration(hours: 5)), id: 2),
        sessionAt(today().subtract(const Duration(days: 1)), id: 3),
      ];
      expect(consecutiveDaysFromToday(list, now: today), 2);
    });
  });

  group('sessionsToDistinctDates (pure)', () {
    Session sessionAt(DateTime t) => Session(
          id: 0, deviceSessionId: 0, startedAt: null,
          durationSec: 240, maxPressure: 0, avgPressure: 0,
          enduranceSec: 0, orificeLevel: 0, targetHits: 0,
          sampleCount: 0, crc32: 0, receivedAt: t,
        );

    test('groups same day across times of day', () {
      final dates = sessionsToDistinctDates([
        sessionAt(DateTime(2026, 4, 25, 9)),
        sessionAt(DateTime(2026, 4, 25, 23)),
        sessionAt(DateTime(2026, 4, 26, 1)),
      ]);
      expect(dates, hasLength(2));
    });
  });

  test('watchTodayDuration sums only today rows', () async {
    // 자정 직후에 실행해도 안정적이도록 시드를 startOfDay 기준으로 작성.
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    await seedAt(today0.add(const Duration(hours: 9)),
        id: 1, durationSec: 120);
    await seedAt(today0.add(const Duration(hours: 11)),
        id: 2, durationSec: 60);
    await seedAt(today0.subtract(const Duration(hours: 1)),
        id: 3, durationSec: 999);

    final d = await repo.watchTodayDuration().first;
    expect(d, const Duration(seconds: 180));
  });

  test('watchWeekHits counts distinct days this week (Mon start)', () async {
    final now = DateTime(2026, 4, 25, 12); // Sat
    final mon = DateTime(2026, 4, 20, 12);
    final tue = DateTime(2026, 4, 21, 8);
    final tueLater = DateTime(2026, 4, 21, 20);
    await seedAt(mon, id: 1);
    await seedAt(tue, id: 2);
    await seedAt(tueLater, id: 3);

    final n = await repo.watchWeekHits(now: () => now).first;
    expect(n, 2); // Mon + Tue
  });

  test('firstSessionDate returns earliest receivedAt or null', () async {
    expect(await repo.firstSessionDate(), isNull);

    final older = DateTime(2026, 3, 1);
    final newer = DateTime(2026, 4, 1);
    await seedAt(newer, id: 1);
    await seedAt(older, id: 2);

    final earliest = await repo.firstSessionDate();
    expect(earliest!.isAtSameMomentAs(older), isTrue);
  });

  // ---------------------------------------------------------------
  // Phase A-1: weekly aggregates + week pressure pair
  // ---------------------------------------------------------------

  Session sessionWith({
    required DateTime receivedAt,
    int id = 0,
    double avgPressure = 22.0,
    double maxPressure = 28.0,
  }) =>
      Session(
        id: id,
        deviceSessionId: id,
        startedAt: null,
        durationSec: 240,
        maxPressure: maxPressure,
        avgPressure: avgPressure,
        enduranceSec: 180,
        orificeLevel: 1,
        targetHits: 3,
        sampleCount: 24000,
        crc32: 0,
        receivedAt: receivedAt,
      );

  group('weeklyAggregatesFrom (pure)', () {
    // 2026-04-25 Sat → 그 주 월요일 = 2026-04-20
    DateTime now() => DateTime(2026, 4, 25, 12);
    final thisMon = DateTime(2026, 4, 20);

    test('returns exactly N weeks (default 12), oldest first', () {
      final out = weeklyAggregatesFrom([], now: now);
      expect(out, hasLength(12));
      expect(out.first.weekStart,
          thisMon.subtract(const Duration(days: 77))); // 11 weeks ago
      expect(out.last.weekStart, thisMon);
    });

    test('all-empty when no sessions in window', () {
      final out = weeklyAggregatesFrom([], now: now);
      expect(out.every((w) => w.isEmpty), isTrue);
      expect(out.every((w) => w.avgExhale == null), isTrue);
    });

    test('buckets sessions into the correct week', () {
      // 이번 주 (Mon 4/20) 에 두 세션, 지난 주 (Mon 4/13) 에 한 세션.
      final list = [
        sessionWith(
            receivedAt: DateTime(2026, 4, 21),
            avgPressure: 20,
            maxPressure: 25,
            id: 1),
        sessionWith(
            receivedAt: DateTime(2026, 4, 23),
            avgPressure: 30,
            maxPressure: 35,
            id: 2),
        sessionWith(
            receivedAt: DateTime(2026, 4, 14),
            avgPressure: 18,
            maxPressure: 22,
            id: 3),
      ];
      final out = weeklyAggregatesFrom(list, now: now);

      // 마지막 항목 = 이번 주
      final thisWeek = out.last;
      expect(thisWeek.sessionCount, 2);
      expect(thisWeek.avgExhale, 25.0); // (20 + 30) / 2
      expect(thisWeek.maxExhale, 35.0); // max of week

      // 마지막 -2 = 지난 주 (out 길이 12, last index 11; index 10 = 지난 주)
      final lastWeek = out[out.length - 2];
      expect(lastWeek.sessionCount, 1);
      expect(lastWeek.avgExhale, 18.0);
      expect(lastWeek.maxExhale, 22.0);
    });

    test('window 밖 세션은 제외 (12주 이전)', () {
      final old = DateTime(2026, 4, 20)
          .subtract(const Duration(days: 7 * 12));
      final list = [
        sessionWith(receivedAt: old, avgPressure: 99, id: 1),
      ];
      final out = weeklyAggregatesFrom(list, now: now);
      expect(out.every((w) => w.isEmpty), isTrue);
    });

    test('주 경계 (월요일 00:00) 정확히 처리', () {
      // 4/20 00:00 = 이번 주 시작. 4/19 23:59 = 지난 주.
      final list = [
        sessionWith(
            receivedAt: DateTime(2026, 4, 20, 0, 0, 0),
            avgPressure: 10,
            id: 1),
        sessionWith(
            receivedAt: DateTime(2026, 4, 19, 23, 59),
            avgPressure: 20,
            id: 2),
      ];
      final out = weeklyAggregatesFrom(list, now: now);
      expect(out.last.avgExhale, 10.0); // 이번 주
      expect(out[out.length - 2].avgExhale, 20.0); // 지난 주
    });

    test('weeks=4 옵션으로 짧은 윈도우', () {
      final out = weeklyAggregatesFrom([], weeks: 4, now: now);
      expect(out, hasLength(4));
    });
  });

  group('weekAvgPressurePairFrom (pure)', () {
    DateTime now() => DateTime(2026, 4, 25, 12); // Sat

    test('both null when no sessions', () {
      final p = weekAvgPressurePairFrom([], now: now);
      expect(p.thisWeek, isNull);
      expect(p.lastWeek, isNull);
    });

    test('this/last 주 구분 + 평균 계산', () {
      final list = [
        // 이번 주
        sessionWith(
            receivedAt: DateTime(2026, 4, 21),
            avgPressure: 20,
            id: 1),
        sessionWith(
            receivedAt: DateTime(2026, 4, 24),
            avgPressure: 24,
            id: 2),
        // 지난 주
        sessionWith(
            receivedAt: DateTime(2026, 4, 14),
            avgPressure: 18,
            id: 3),
        sessionWith(
            receivedAt: DateTime(2026, 4, 16),
            avgPressure: 16,
            id: 4),
      ];
      final p = weekAvgPressurePairFrom(list, now: now);
      expect(p.thisWeek, 22.0); // (20+24)/2
      expect(p.lastWeek, 17.0); // (18+16)/2
    });

    test('this 만 있는 케이스 — last null', () {
      final list = [
        sessionWith(
            receivedAt: DateTime(2026, 4, 21),
            avgPressure: 20,
            id: 1),
      ];
      final p = weekAvgPressurePairFrom(list, now: now);
      expect(p.thisWeek, 20.0);
      expect(p.lastWeek, isNull);
    });

    test('지지난주 세션은 무시 (last 만 봄)', () {
      final list = [
        sessionWith(
            receivedAt: DateTime(2026, 4, 6),
            avgPressure: 99,
            id: 1),
      ];
      final p = weekAvgPressurePairFrom(list, now: now);
      expect(p.thisWeek, isNull);
      expect(p.lastWeek, isNull);
    });
  });

  test('firstSessionStats returns first by receivedAt or null', () async {
    expect(await repo.firstSessionStats(), isNull);

    final older = DateTime(2026, 3, 1);
    final newer = DateTime(2026, 4, 1);
    await db.into(db.sessions).insert(SessionsCompanion.insert(
          deviceSessionId: 100,
          durationSec: 240,
          maxPressure: 33.0,
          avgPressure: 24.5,
          enduranceSec: 180,
          orificeLevel: 1,
          targetHits: 3,
          sampleCount: 24000,
          crc32: 0,
          receivedAt: Value(newer),
        ));
    await db.into(db.sessions).insert(SessionsCompanion.insert(
          deviceSessionId: 101,
          durationSec: 240,
          maxPressure: 22.0,
          avgPressure: 16.2,
          enduranceSec: 180,
          orificeLevel: 1,
          targetHits: 3,
          sampleCount: 24000,
          crc32: 0,
          receivedAt: Value(older),
        ));

    final stats = await repo.firstSessionStats();
    expect(stats, isNotNull);
    expect(stats!.avgPressure, closeTo(16.2, 0.001));
    expect(stats.maxPressure, closeTo(22.0, 0.001));
    expect(stats.receivedAt.isAtSameMomentAs(older), isTrue);
  });
}
