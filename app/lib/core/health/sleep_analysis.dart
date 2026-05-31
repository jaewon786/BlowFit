// 수면 효과 분석 — baseline(초기 N박) vs recent(최근 N박) 비교.

import '../db/app_database.dart';

class SleepEffect {
  SleepEffect({
    required this.baselineSpo2Min,
    required this.recentSpo2Min,
    required this.baselineScore,
    required this.recentScore,
    required this.nights,
    this.apneaBaseline,
    this.apneaRecent,
  });

  final double? baselineSpo2Min;
  final double? recentSpo2Min;
  final double? baselineScore;
  final double? recentScore;
  final int nights;
  final String? apneaBaseline; // 가장 이른 무호흡 징후 (DETECTED/NOT_DETECTED)
  final String? apneaRecent; // 가장 최근 무호흡 징후

  /// 무호흡 징후 마커를 보여줄 데이터가 있는지.
  bool get hasApnea => apneaBaseline != null || apneaRecent != null;

  double? get spo2MinDelta =>
      (baselineSpo2Min != null && recentSpo2Min != null)
          ? recentSpo2Min! - baselineSpo2Min!
          : null;

  double? get scoreDelta => (baselineScore != null && recentScore != null)
      ? recentScore! - baselineScore!
      : null;
}

/// records 를 날짜 오름차순으로 정렬해 앞 [window] 박(baseline)과
/// 뒤 [window] 박(recent)의 평균을 비교.
SleepEffect computeSleepEffect(List<SleepRecord> records, {int window = 7}) {
  final sorted = [...records]..sort((a, b) => a.night.compareTo(b.night));
  final n = sorted.length;
  if (n == 0) {
    return SleepEffect(
      baselineSpo2Min: null,
      recentSpo2Min: null,
      baselineScore: null,
      recentScore: null,
      nights: 0,
    );
  }
  final w = window > n ? n : window;
  final baseline = sorted.take(w);
  final recent = sorted.skip(n - w);

  // 무호흡 징후 — 희소하므로 전체에서 가장 이른/최근 non-null 값을 사용.
  String? apneaBaseline;
  String? apneaRecent;
  for (final r in sorted) {
    if (r.apneaSign != null) {
      apneaBaseline ??= r.apneaSign;
      apneaRecent = r.apneaSign;
    }
  }

  return SleepEffect(
    baselineSpo2Min: _avgD(baseline.map((e) => e.spo2Min)),
    recentSpo2Min: _avgD(recent.map((e) => e.spo2Min)),
    baselineScore: _avgI(baseline.map((e) => e.score)),
    recentScore: _avgI(recent.map((e) => e.score)),
    nights: n,
    apneaBaseline: apneaBaseline,
    apneaRecent: apneaRecent,
  );
}

double? _avgD(Iterable<double?> xs) {
  final v = xs.whereType<double>().toList();
  return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
}

double? _avgI(Iterable<int?> xs) {
  final v = xs.whereType<int>().toList();
  return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
}
