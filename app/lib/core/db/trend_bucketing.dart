import 'app_database.dart';

/// Trend 화면의 4개 탭 — 일간 / 주간 / 월간 / 년간.
enum TrendPeriod {
  /// 이번 주 (월~일) 7일.
  daily,

  /// 이번 달의 1주~4주 (1-7일=1주, 8-14일=2주, 15-21일=3주, 22-말일=4주).
  weekly,

  /// 올해 1~12월 (12개 자리, 미래 달은 빈 자리).
  monthly,

  /// 최근 3년 (예: 2024 / 2025 / 2026).
  yearly,
}

/// Trend 차트의 한 점.
///
/// `xPos` 는 차트 x 좌표 (1-based). `label` 은 x 축에 그릴 한국어 라벨.
class TrendBucket {
  final int xPos;
  final String label;
  final double? avgExhale;
  final double? maxExhale;
  final int sessionCount;

  /// 디버깅용 — 어느 날짜/주/월에 해당하는지.
  final DateTime bucketStart;

  const TrendBucket({
    required this.xPos,
    required this.label,
    required this.avgExhale,
    required this.maxExhale,
    required this.sessionCount,
    required this.bucketStart,
  });

  bool get isEmpty => sessionCount == 0;
}

// ---------------------------------------------------------------------------
// since() — 각 period 별로 watchSince 에 넘길 cutoff 계산.
// ---------------------------------------------------------------------------

DateTime sinceForPeriod(TrendPeriod p, DateTime now) {
  switch (p) {
    case TrendPeriod.daily:
      return _startOfWeek(now); // 이번 주 월요일
    case TrendPeriod.weekly:
      return DateTime(now.year, now.month, 1);
    case TrendPeriod.monthly:
      // 올해 1월 1일.
      return DateTime(now.year, 1, 1);
    case TrendPeriod.yearly:
      // 2년 전 1월 1일 — 올해 포함 3년.
      return DateTime(now.year - 2, 1, 1);
  }
}

// ---------------------------------------------------------------------------
// bucketize — period 별로 세션 리스트를 TrendBucket 들로 변환.
// 모두 pure 함수 — 단위 테스트로 케이스 고정.
// ---------------------------------------------------------------------------

/// 입력 세션들을 period 별 버킷 리스트로 변환. pure 함수.
List<TrendBucket> bucketizeForPeriod(
  List<Session> sessions,
  TrendPeriod period, {
  DateTime Function() now = _defaultNow,
}) {
  switch (period) {
    case TrendPeriod.daily:
      return _bucketizeDaily(sessions, now());
    case TrendPeriod.weekly:
      return _bucketizeWeekly(sessions, now());
    case TrendPeriod.monthly:
      return _bucketizeMonthly(sessions, now());
    case TrendPeriod.yearly:
      return _bucketizeYearly(sessions, now());
  }
}

/// 일간 — 이번 주 월~일 7일.
/// 라벨: 월/화/수/목/금/토/일. xPos: 1=월, 7=일.
List<TrendBucket> _bucketizeDaily(List<Session> sessions, DateTime now) {
  const labels = ['월', '화', '수', '목', '금', '토', '일'];
  final monday = _startOfWeek(now);
  final accs = List<_Acc>.generate(
    7,
    (i) => _Acc(start: monday.add(Duration(days: i))),
  );
  for (final s in sessions) {
    final t = s.receivedAt;
    final diff = _startOfDay(t).difference(monday).inDays;
    if (diff < 0 || diff >= 7) continue;
    accs[diff].add(s);
  }
  return [
    for (var i = 0; i < 7; i++)
      accs[i].snapshot(xPos: i + 1, label: labels[i]),
  ];
}

/// 주간 — 이번 달 1주차 ~ 4주차.
/// 1주 = 1~7일, 2주 = 8~14일, 3주 = 15~21일, 4주 = 22~말일.
/// 22일 이후 모두 4주차에 포함 (28~31일 케이스).
List<TrendBucket> _bucketizeWeekly(List<Session> sessions, DateTime now) {
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 1);
  final accs = List<_Acc>.generate(
    4,
    (i) => _Acc(start: DateTime(now.year, now.month, 1 + i * 7)),
  );
  for (final s in sessions) {
    final t = s.receivedAt;
    if (t.isBefore(monthStart) || !t.isBefore(monthEnd)) continue;
    final day = t.day;
    final idx = ((day - 1) ~/ 7).clamp(0, 3); // 22-31 모두 idx=3
    accs[idx].add(s);
  }
  return [
    for (var i = 0; i < 4; i++)
      accs[i].snapshot(xPos: i + 1, label: '${i + 1}주'),
  ];
}

/// 월간 — 올해 1~12월 (12개 자리). 미래 달은 빈 자리.
List<TrendBucket> _bucketizeMonthly(List<Session> sessions, DateTime now) {
  final accs = List<_Acc>.generate(
    12,
    (i) => _Acc(start: DateTime(now.year, i + 1, 1)),
  );
  for (final s in sessions) {
    final t = s.receivedAt;
    if (t.year != now.year) continue;
    accs[t.month - 1].add(s);
  }
  return [
    for (var i = 0; i < 12; i++)
      accs[i].snapshot(xPos: i + 1, label: '${i + 1}월'),
  ];
}

/// 년간 — 최근 3년 (이번 해 포함). 2026 이면 2024 / 2025 / 2026.
List<TrendBucket> _bucketizeYearly(List<Session> sessions, DateTime now) {
  // 가장 오래된 해부터 (2년 전) 올해까지 3개.
  final years = <int>[
    for (var i = 2; i >= 0; i--) now.year - i,
  ];
  final accs = years.map((y) => _Acc(start: DateTime(y, 1, 1))).toList();

  for (final s in sessions) {
    final idx = years.indexOf(s.receivedAt.year);
    if (idx == -1) continue;
    accs[idx].add(s);
  }
  return [
    for (var i = 0; i < 3; i++)
      accs[i].snapshot(xPos: i + 1, label: '${years[i]}'),
  ];
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

DateTime _defaultNow() => DateTime.now();

DateTime _startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime _startOfWeek(DateTime t) {
  final fromMon = t.weekday - DateTime.monday;
  return _startOfDay(t).subtract(Duration(days: fromMon));
}

class _Acc {
  final DateTime start;
  double avgSum = 0;
  double maxOfBucket = -double.infinity;
  int n = 0;

  _Acc({required this.start});

  void add(Session s) {
    avgSum += s.avgPressure;
    if (s.maxPressure > maxOfBucket) maxOfBucket = s.maxPressure;
    n++;
  }

  TrendBucket snapshot({required int xPos, required String label}) {
    return TrendBucket(
      xPos: xPos,
      label: label,
      avgExhale: n > 0 ? avgSum / n : null,
      maxExhale: n > 0 ? maxOfBucket : null,
      sessionCount: n,
      bucketStart: start,
    );
  }
}
