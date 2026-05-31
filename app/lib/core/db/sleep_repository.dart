import 'dart:math';

import 'package:drift/drift.dart';

import 'app_database.dart';

/// Samsung Health 수면 레코드 저장소 (밤 1건/일, upsert).
class SleepRepository {
  SleepRepository(this._db);

  final AppDatabase _db;

  /// 그 밤(night) 레코드를 upsert. 같은 night 면 갱신.
  Future<void> upsertNight({
    required DateTime night,
    DateTime? startedAt,
    DateTime? endedAt,
    int? score,
    int? durationMin,
    double? spo2Avg,
    double? spo2Min,
    double? spo2Max,
    String? apneaSign,
    String source = 'samsung_health',
  }) {
    final row = SleepRecordsCompanion.insert(
      night: night,
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      score: Value(score),
      durationMin: Value(durationMin),
      spo2Avg: Value(spo2Avg),
      spo2Min: Value(spo2Min),
      spo2Max: Value(spo2Max),
      apneaSign: Value(apneaSign),
      source: Value(source),
    );
    return _db.into(_db.sleepRecords).insert(
          row,
          onConflict: DoUpdate(
            (_) => row,
            target: [_db.sleepRecords.night],
          ),
        );
  }

  /// 최신 순 N개.
  Future<List<SleepRecord>> recent({int limit = 60}) {
    return (_db.select(_db.sleepRecords)
          ..orderBy([(t) => OrderingTerm.desc(t.night)])
          ..limit(limit))
        .get();
  }

  /// 최신 순 N개 (실시간 watch).
  Stream<List<SleepRecord>> watchRecent({int limit = 60}) {
    return (_db.select(_db.sleepRecords)
          ..orderBy([(t) => OrderingTerm.desc(t.night)])
          ..limit(limit))
        .watch();
  }

  Future<int> count() async => (await _db.select(_db.sleepRecords).get()).length;

  /// 모든 수면 레코드 삭제.
  Future<void> clear() => _db.delete(_db.sleepRecords).go();

  /// 발표/개발용 데모 데이터 주입 (실데이터 없이 시각화 검증용).
  /// 최근 30일: 앞 10일=baseline(낮은 SpO2·점수), 이후=사용 후 점진 개선.
  Future<int> seedDemo({int nights = 30, int startIdx = 10}) async {
    await clear();
    final rnd = Random(42);
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);

    for (var i = 0; i < nights; i++) {
      final night = base.subtract(Duration(days: nights - 1 - i));
      final inUse = i >= startIdx;
      // 사용 기간 진행도 0..1.
      final ramp = inUse ? (i - startIdx) / (nights - 1 - startIdx) : 0.0;

      final spo2Min = (inUse ? 87 + ramp * 7 : 86 + rnd.nextDouble() * 2) +
          (rnd.nextDouble() - 0.5);
      final score = (inUse ? 66 + ramp * 20 : 62 + rnd.nextDouble() * 6) +
          (rnd.nextDouble() - 0.5) * 3;
      final duration =
          (inUse ? 380 + ramp * 30 : 360 + rnd.nextDouble() * 20).round();

      // 무호흡 징후 데모 — baseline 초반엔 "있음", 사용 후반엔 "없음" 1건씩.
      String? apneaSign;
      if (i == 2) apneaSign = 'DETECTED';
      if (i == nights - 3) apneaSign = 'NOT_DETECTED';

      final start = night.subtract(const Duration(hours: 1)); // 전날 23시쯤
      await upsertNight(
        night: night,
        startedAt: start,
        endedAt: start.add(Duration(minutes: duration)),
        score: score.round().clamp(0, 100),
        durationMin: duration,
        spo2Min: _r1(spo2Min.clamp(80.0, 99.0)),
        spo2Avg: _r1((spo2Min + 4).clamp(80.0, 100.0)),
        spo2Max: 99,
        apneaSign: apneaSign,
        source: 'demo',
      );
    }
    return nights;
  }

  static double _r1(num v) => double.parse(v.toStringAsFixed(1));
}
