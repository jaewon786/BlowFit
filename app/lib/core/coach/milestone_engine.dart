import '../db/app_database.dart';

/// 추이 화면 "업적" 카드 — 피그마 디자인의 6개 주차 업적.
///
///   1주차 - 첫 훈련 완료      : 첫 훈련 세션이 있으면 달성.
///   2~6주차 - 연속 훈련 완료  : 첫 훈련 주(week 0)부터 N주 연속으로 매주
///                              1회 이상 훈련하면 N주차 달성.
///
/// "주(week)" 는 첫 훈련일을 기준으로 한 rolling 7일 버킷
/// (week 0 = [첫날, 첫날+7일), week 1 = [첫날+7일, +14일), ...).
///
/// 모두 pure 함수 — 단위 테스트 가능.
class MilestoneEngine {
  MilestoneEngine._();

  /// `sessions` 는 입력 순서 무관 — 내부에서 receivedAt asc 로 재정렬.
  static List<Milestone> compute({
    required List<Session> sessions,
  }) {
    final sorted = [...sessions]
      ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));

    Milestone week(int n, String title) => Milestone(
          week: n,
          title: title,
          achievedAt: _consecutiveWeeksReached(sorted, target: n),
        );

    return [
      week(1, '1주차 - 첫 훈련 완료'),
      week(2, '2주차 - 연속 훈련 완료'),
      week(3, '3주차 - 연속 훈련 완료'),
      week(4, '4주차 - 연속 훈련 완료'),
      week(5, '5주차 - 연속 훈련 완료'),
      week(6, '6주차 - 연속 훈련 완료'),
    ];
  }

  /// 첫 훈련일 기준 rolling 7일 버킷에서, 주 0..target-1 이 모두 1회 이상
  /// 훈련됐으면 (target-1) 주의 첫 세션 날짜를 반환. 미달성이면 null.
  /// (테스트 노출용 public wrapper.)
  static DateTime? consecutiveWeeksReached(
    List<Session> sortedAsc, {
    required int target,
  }) =>
      _consecutiveWeeksReached(sortedAsc, target: target);

  static DateTime? _consecutiveWeeksReached(
    List<Session> sortedAsc, {
    required int target,
  }) {
    if (target <= 0 || sortedAsc.isEmpty) return null;
    final first = sortedAsc.first.receivedAt;
    final firstDate = DateTime(first.year, first.month, first.day);
    // 각 주 버킷(0-based)의 첫 세션 날짜.
    final weekFirst = <int, DateTime>{};
    for (final s in sortedAsc) {
      final d = DateTime(
        s.receivedAt.year,
        s.receivedAt.month,
        s.receivedAt.day,
      );
      final w = d.difference(firstDate).inDays ~/ 7;
      weekFirst.putIfAbsent(w, () => s.receivedAt);
    }
    // 주 0..target-1 이 모두 채워져야 target 주차 달성.
    for (var w = 0; w < target; w++) {
      if (!weekFirst.containsKey(w)) return null;
    }
    return weekFirst[target - 1];
  }
}

class Milestone {
  final int week; // 1~6
  final String title;

  /// null 이면 미달성 (UI 에서 회색 표시).
  final DateTime? achievedAt;

  const Milestone({
    required this.week,
    required this.title,
    required this.achievedAt,
  });

  bool get achieved => achievedAt != null;
}
