// Samsung Health 수면 + SpO2 → 밤별로 합쳐 DB(SleepRecords) 에 동기화.

import '../db/sleep_repository.dart';
import 'samsung_health_service.dart';

class SleepSync {
  SleepSync(this._svc, this._repo);

  final SamsungHealthService _svc;
  final SleepRepository _repo;

  /// 최근 [days]일 수면 + SpO2 를 읽어 밤별로 합쳐 upsert. 저장한 밤 수 반환.
  Future<int> sync({int days = 30}) async {
    final to = DateTime.now();
    final from = to.subtract(Duration(days: days));

    final sleeps = await _svc.readSleep(from, to);
    final spo2s = await _svc.readSpo2(from, to);
    final apneas = await _svc.readApneaSigns(from, to);

    // 무호흡 징후 — 밤(종료일)별 매핑 (희소 데이터).
    final apneaByNight = <DateTime, String>{};
    for (final a in apneas) {
      if (a.sign == null) continue;
      apneaByNight[DateTime(a.end.year, a.end.month, a.end.day)] = a.sign!;
    }

    var saved = 0;
    for (final s in sleeps) {
      // 그 밤(수면 구간) 안의 SpO2 집계.
      final inWindow = spo2s.where(
        (o) => !o.start.isBefore(s.start) && !o.start.isAfter(s.end),
      );
      final mins = inWindow.map((o) => o.min).whereType<double>().toList();
      final avgs = inWindow.map((o) => o.avg).whereType<double>().toList();
      final maxs = inWindow.map((o) => o.max).whereType<double>().toList();

      final night = DateTime(s.end.year, s.end.month, s.end.day);
      await _repo.upsertNight(
        night: night,
        startedAt: s.start,
        endedAt: s.end,
        score: s.score,
        durationMin: s.durationMin,
        spo2Min: mins.isEmpty ? null : mins.reduce((a, b) => a < b ? a : b),
        spo2Avg:
            avgs.isEmpty ? null : avgs.reduce((a, b) => a + b) / avgs.length,
        spo2Max: maxs.isEmpty ? null : maxs.reduce((a, b) => a > b ? a : b),
        apneaSign: apneaByNight[night],
      );
      saved++;
    }
    return saved;
  }
}
