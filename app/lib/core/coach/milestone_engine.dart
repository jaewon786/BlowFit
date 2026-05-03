import 'package:meta/meta.dart' show visibleForTesting;

import '../db/app_database.dart';

/// 디자인 v2 의 마일스톤 카드 (`trend-profile.jsx`).
///
/// 정해진 5개 마일스톤 — 첫 훈련 / 7일 연속 / 호기 20 돌파 / 30일 연속 /
/// 호기 25 돌파 — 의 달성 여부와 날짜를 세션 리스트로부터 계산.
///
/// 모두 pure 함수 — 단위 테스트 가능.
class MilestoneEngine {
  MilestoneEngine._();

  /// `sessions` 는 입력 순서 무관 — 내부에서 receivedAt asc 로 재정렬.
  /// `currentStreak` 은 SessionRepository.watchConsecutiveDays 결과.
  static List<Milestone> compute({
    required List<Session> sessions,
    required int currentStreak,
    DateTime Function() now = _defaultNow,
  }) {
    final sorted = [...sessions]..sort(
        (a, b) => a.receivedAt.compareTo(b.receivedAt),
      );

    final firstAt = sorted.isNotEmpty ? sorted.first.receivedAt : null;

    // 호기 압력 돌파: maxPressure 가 처음 임계치 이상이 된 세션의 날짜.
    final exhale20At = _firstSessionWith(sorted, (s) => s.maxPressure >= 20);
    final exhale25At = _firstSessionWith(sorted, (s) => s.maxPressure >= 25);

    // 연속 훈련 마일스톤 — 사용자 history 상 한 번이라도 N일 연속 달성한 적
    // 있는지. 현재 streak 이 끊겼어도 과거 달성 여부는 유지.
    final streak7At = _firstStreakReached(sorted, target: 7);
    final streak30At = _firstStreakReached(sorted, target: 30);

    return [
      Milestone(
        kind: MilestoneKind.firstTraining,
        title: '1주차 — 첫 훈련 완료',
        achievedAt: firstAt,
      ),
      Milestone(
        kind: MilestoneKind.sevenDayStreak,
        title: '7일 연속 훈련',
        achievedAt: streak7At,
      ),
      Milestone(
        kind: MilestoneKind.exhale20,
        title: '호기 20 cmH₂O 돌파',
        achievedAt: exhale20At,
      ),
      Milestone(
        kind: MilestoneKind.thirtyDayStreak,
        // 미달성 시 진행도 표시. 달성 시 일반 라벨.
        title: streak30At != null
            ? '30일 연속 훈련'
            : '30일 연속 훈련 ($currentStreak / 30)',
        achievedAt: streak30At,
      ),
      Milestone(
        kind: MilestoneKind.exhale25,
        title: '호기 25 cmH₂O 돌파',
        achievedAt: exhale25At,
      ),
    ];
  }

  /// 첫 번째 매치되는 세션 날짜.
  static DateTime? _firstSessionWith(
      List<Session> sortedAsc, bool Function(Session) match) {
    for (final s in sortedAsc) {
      if (match(s)) return s.receivedAt;
    }
    return null;
  }

  /// 입력 (asc) 의 distinct date 들을 훑으며 처음으로 N일 연속에 도달한
  /// 날짜를 반환. 미도달이면 null.
  @visibleForTesting
  static DateTime? firstStreakReached(
    List<Session> sortedAsc, {
    required int target,
  }) =>
      _firstStreakReached(sortedAsc, target: target);

  static DateTime? _firstStreakReached(
    List<Session> sortedAsc, {
    required int target,
  }) {
    if (target <= 0 || sortedAsc.isEmpty) return null;
    final dates = sortedAsc
        .map((s) => DateTime(
              s.receivedAt.year,
              s.receivedAt.month,
              s.receivedAt.day,
            ))
        .toSet()
        .toList()
      ..sort();
    var streak = 1;
    for (var i = 0; i < dates.length; i++) {
      if (i > 0) {
        final diff = dates[i].difference(dates[i - 1]).inDays;
        streak = diff == 1 ? streak + 1 : 1;
      }
      if (streak >= target) return dates[i];
    }
    return null;
  }
}

DateTime _defaultNow() => DateTime.now();

class Milestone {
  final MilestoneKind kind;
  final String title;

  /// null 이면 미달성 (UI 에서 회색 표시).
  final DateTime? achievedAt;

  const Milestone({
    required this.kind,
    required this.title,
    required this.achievedAt,
  });

  bool get achieved => achievedAt != null;
}

enum MilestoneKind {
  firstTraining,
  sevenDayStreak,
  exhale20,
  thirtyDayStreak,
  exhale25,
}
