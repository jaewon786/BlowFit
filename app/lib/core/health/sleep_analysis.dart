// 수면 효과 분석 — baseline(초기 N박) vs recent(최근 N박) 비교.

import '../db/app_database.dart';
import '../db/trend_bucketing.dart';

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

  double? get spo2MinDelta => (baselineSpo2Min != null && recentSpo2Min != null)
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

// ───────────────────────── SpO₂ 버킷 (추이 차트용) ─────────────────────────

/// SpO₂ 추이 차트의 한 점. `bucketizeSpo2` 결과.
///
/// 압력 추이(`TrendBucket`)의 daily/weekly/monthly/yearly 버킷 의미를 그대로
/// 미러링하되, `record.night` 으로 묶고 `record.spo2Min` 평균을 집계한다.
class Spo2Bucket {
  final int xPos; // 1-based 차트 x
  final String label; // x축 라벨 (월/화…, 1주…, 1월…, 2024…)
  final double? avgSpo2Min; // 그 버킷 평균 최저 SpO₂ (없으면 null)
  final int nights; // 그 버킷에 속한 수면 레코드 수

  const Spo2Bucket({
    required this.xPos,
    required this.label,
    required this.avgSpo2Min,
    required this.nights,
  });

  bool get isEmpty => nights == 0;
}

/// 수면 레코드를 period 별 SpO₂ 버킷 리스트로 변환. pure 함수 (테스트 가능).
///
/// trend_bucketing 의 일간(7)/주간(4)/월간(12)/년간(3) 슬롯·라벨을 동일하게
/// 사용. spo2Min 이 null 인 레코드는 평균에서 제외하되 nights 에는 포함한다
/// (= 슬롯에 들어온 밤 수). 슬롯에 spo2Min 값이 하나도 없으면 avgSpo2Min=null.
List<Spo2Bucket> bucketizeSpo2(
  List<SleepRecord> records,
  TrendPeriod period, {
  DateTime Function() now = _nowDefault,
}) {
  switch (period) {
    case TrendPeriod.daily:
      return _spo2Daily(records, now());
    case TrendPeriod.weekly:
      return _spo2Weekly(records, now());
    case TrendPeriod.monthly:
      return _spo2Monthly(records, now());
    case TrendPeriod.yearly:
      return _spo2Yearly(records, now());
  }
}

/// 일간 — 이번 주 월~일 7일. 라벨 월/화/…/일. xPos 1=월, 7=일.
List<Spo2Bucket> _spo2Daily(List<SleepRecord> records, DateTime now) {
  const labels = ['월', '화', '수', '목', '금', '토', '일'];
  final monday = _startOfWeekSleep(now);
  final accs = List<_Spo2Acc>.generate(7, (_) => _Spo2Acc());
  for (final r in records) {
    final diff = _startOfDaySleep(r.night).difference(monday).inDays;
    if (diff < 0 || diff >= 7) continue;
    accs[diff].add(r.spo2Min);
  }
  return [
    for (var i = 0; i < 7; i++) accs[i].snapshot(xPos: i + 1, label: labels[i]),
  ];
}

/// 주간 — 이번 달 1주차~4주차. 1주=1~7일, …, 4주=22~말일.
List<Spo2Bucket> _spo2Weekly(List<SleepRecord> records, DateTime now) {
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 1);
  final accs = List<_Spo2Acc>.generate(4, (_) => _Spo2Acc());
  for (final r in records) {
    final t = r.night;
    if (t.isBefore(monthStart) || !t.isBefore(monthEnd)) continue;
    final idx = ((t.day - 1) ~/ 7).clamp(0, 3); // 22-31 모두 idx=3
    accs[idx].add(r.spo2Min);
  }
  return [
    for (var i = 0; i < 4; i++)
      accs[i].snapshot(xPos: i + 1, label: '${i + 1}주'),
  ];
}

/// 월간 — 올해 1~12월 (12개 자리). 미래 달은 빈 자리.
List<Spo2Bucket> _spo2Monthly(List<SleepRecord> records, DateTime now) {
  final accs = List<_Spo2Acc>.generate(12, (_) => _Spo2Acc());
  for (final r in records) {
    if (r.night.year != now.year) continue;
    accs[r.night.month - 1].add(r.spo2Min);
  }
  return [
    for (var i = 0; i < 12; i++)
      accs[i].snapshot(xPos: i + 1, label: '${i + 1}월'),
  ];
}

/// 년간 — 최근 3년 (올해 포함). 2026 이면 2024/2025/2026.
List<Spo2Bucket> _spo2Yearly(List<SleepRecord> records, DateTime now) {
  final years = <int>[
    for (var i = 2; i >= 0; i--) now.year - i,
  ];
  final accs = years.map((_) => _Spo2Acc()).toList();
  for (final r in records) {
    final idx = years.indexOf(r.night.year);
    if (idx == -1) continue;
    accs[idx].add(r.spo2Min);
  }
  return [
    for (var i = 0; i < 3; i++)
      accs[i].snapshot(xPos: i + 1, label: '${years[i]}'),
  ];
}

DateTime _nowDefault() => DateTime.now();

DateTime _startOfDaySleep(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime _startOfWeekSleep(DateTime t) {
  final fromMon = t.weekday - DateTime.monday;
  return _startOfDaySleep(t).subtract(Duration(days: fromMon));
}

class _Spo2Acc {
  double sum = 0;
  int valued = 0; // spo2Min non-null 개수
  int nights = 0; // 슬롯에 들어온 레코드 수

  void add(double? spo2Min) {
    nights++;
    if (spo2Min != null) {
      sum += spo2Min;
      valued++;
    }
  }

  Spo2Bucket snapshot({required int xPos, required String label}) {
    return Spo2Bucket(
      xPos: xPos,
      label: label,
      avgSpo2Min: valued > 0 ? sum / valued : null,
      nights: nights,
    );
  }
}

// ─────────────────── 훈련-수면 연관성 (평균 비교) ───────────────────

/// 훈련한 날 밤 vs 안 한 날 밤의 평균 최저 SpO₂ 비교 결과.
class TrainingSpo2Compare {
  final double? trainedAvg; // 훈련한 날 밤 평균 (없으면 null)
  final double? untrainedAvg; // 안 한 날 밤 평균 (없으면 null)
  final int trainedNights;
  final int untrainedNights;

  const TrainingSpo2Compare({
    required this.trainedAvg,
    required this.untrainedAvg,
    required this.trainedNights,
    required this.untrainedNights,
  });
}

/// spo2Min 이 있는 레코드를, 그 밤 자정 기준 날짜가 [trainedDates] 에 속하는지로
/// 두 그룹으로 나눠 평균 최저 SpO₂ 를 계산. pure 함수 (테스트 가능).
TrainingSpo2Compare compareTrainingSpo2(
  List<SleepRecord> records,
  Set<DateTime> trainedDates,
) {
  double trainedSum = 0, untrainedSum = 0;
  var trainedN = 0, untrainedN = 0;
  for (final r in records) {
    final v = r.spo2Min;
    if (v == null) continue;
    final day = DateTime(r.night.year, r.night.month, r.night.day);
    if (trainedDates.contains(day)) {
      trainedSum += v;
      trainedN++;
    } else {
      untrainedSum += v;
      untrainedN++;
    }
  }
  return TrainingSpo2Compare(
    trainedAvg: trainedN > 0 ? trainedSum / trainedN : null,
    untrainedAvg: untrainedN > 0 ? untrainedSum / untrainedN : null,
    trainedNights: trainedN,
    untrainedNights: untrainedN,
  );
}
