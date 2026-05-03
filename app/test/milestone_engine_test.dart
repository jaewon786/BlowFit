import 'package:blowfit/core/coach/milestone_engine.dart';
import 'package:blowfit/core/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

Session _s({
  required DateTime at,
  int id = 0,
  double maxPressure = 28.0,
}) =>
    Session(
      id: id,
      deviceSessionId: id,
      startedAt: null,
      durationSec: 240,
      maxPressure: maxPressure,
      avgPressure: 22,
      enduranceSec: 180,
      orificeLevel: 1,
      targetHits: 3,
      sampleCount: 24000,
      crc32: 0,
      receivedAt: at,
    );

void main() {
  group('MilestoneEngine.compute', () {
    test('empty input — 모두 미달성', () {
      final ms = MilestoneEngine.compute(sessions: [], currentStreak: 0);
      expect(ms, hasLength(5));
      expect(ms.every((m) => !m.achieved), isTrue);
    });

    test('첫 세션 → firstTraining 달성, 나머지는 임계치에 따라', () {
      final t = DateTime(2026, 4, 1);
      final ms = MilestoneEngine.compute(
        sessions: [_s(at: t, maxPressure: 18, id: 1)],
        currentStreak: 1,
      );
      final byKind = {for (final m in ms) m.kind: m};

      expect(byKind[MilestoneKind.firstTraining]!.achieved, isTrue);
      expect(
          byKind[MilestoneKind.firstTraining]!.achievedAt!
              .isAtSameMomentAs(t),
          isTrue);
      expect(byKind[MilestoneKind.exhale20]!.achieved, isFalse);
      expect(byKind[MilestoneKind.exhale25]!.achieved, isFalse);
      expect(byKind[MilestoneKind.sevenDayStreak]!.achieved, isFalse);
    });

    test('호기 20 / 25 임계치 — 첫 도달 세션의 날짜', () {
      final ms = MilestoneEngine.compute(
        sessions: [
          _s(at: DateTime(2026, 4, 1), maxPressure: 19, id: 1),
          _s(at: DateTime(2026, 4, 5), maxPressure: 22, id: 2),
          _s(at: DateTime(2026, 4, 10), maxPressure: 27, id: 3),
        ],
        currentStreak: 0,
      );
      final byKind = {for (final m in ms) m.kind: m};

      expect(byKind[MilestoneKind.exhale20]!.achievedAt,
          DateTime(2026, 4, 5));
      expect(byKind[MilestoneKind.exhale25]!.achievedAt,
          DateTime(2026, 4, 10));
    });

    test('7일 연속 — 정확히 7번째 날짜에 달성', () {
      final start = DateTime(2026, 4, 1);
      final list = [
        for (var i = 0; i < 7; i++)
          _s(at: start.add(Duration(days: i)), id: i),
      ];
      final ms = MilestoneEngine.compute(
        sessions: list,
        currentStreak: 7,
      );
      final m7 = ms.firstWhere((m) => m.kind == MilestoneKind.sevenDayStreak);
      expect(m7.achieved, isTrue);
      expect(m7.achievedAt, DateTime(2026, 4, 7));
    });

    test('streak 끊겼다가 다시 7일 — 처음 도달 시점 반환', () {
      final list = [
        // 첫 번째 7일 streak (3월 1일 ~ 3월 7일)
        for (var i = 0; i < 7; i++)
          _s(at: DateTime(2026, 3, 1).add(Duration(days: i)), id: i),
        // 한 달 갭 후 다시 7일 streak
        for (var i = 0; i < 7; i++)
          _s(at: DateTime(2026, 4, 1).add(Duration(days: i)), id: i + 100),
      ];
      final m7 = MilestoneEngine.compute(sessions: list, currentStreak: 7)
          .firstWhere((m) => m.kind == MilestoneKind.sevenDayStreak);
      expect(m7.achievedAt, DateTime(2026, 3, 7),
          reason: '처음 7일 도달 시점');
    });

    test('30일 미달 — title 에 진행도 (12 / 30)', () {
      final ms = MilestoneEngine.compute(
        sessions: [_s(at: DateTime(2026, 4, 1), id: 1)],
        currentStreak: 12,
      );
      final m30 =
          ms.firstWhere((m) => m.kind == MilestoneKind.thirtyDayStreak);
      expect(m30.achieved, isFalse);
      expect(m30.title.contains('(12 / 30)'), isTrue);
    });

    test('30일 달성 — title 에 진행도 없음', () {
      final start = DateTime(2026, 3, 1);
      final list = [
        for (var i = 0; i < 30; i++)
          _s(at: start.add(Duration(days: i)), id: i),
      ];
      final m30 = MilestoneEngine.compute(sessions: list, currentStreak: 30)
          .firstWhere((m) => m.kind == MilestoneKind.thirtyDayStreak);
      expect(m30.achieved, isTrue);
      expect(m30.title.contains('/ 30'), isFalse);
    });
  });

  group('firstStreakReached (pure)', () {
    test('빈 입력 → null', () {
      expect(
        MilestoneEngine.firstStreakReached([], target: 7),
        isNull,
      );
    });

    test('연속 5일만 있으면 7 미도달', () {
      final list = [
        for (var i = 0; i < 5; i++)
          _s(at: DateTime(2026, 4, 1).add(Duration(days: i)), id: i),
      ];
      expect(
        MilestoneEngine.firstStreakReached(list, target: 7),
        isNull,
      );
    });

    test('같은 날 여러 세션은 1일로 카운트', () {
      final t = DateTime(2026, 4, 1);
      final list = [
        _s(at: t, id: 1),
        _s(at: t.add(const Duration(hours: 5)), id: 2),
        _s(at: t.add(const Duration(days: 1)), id: 3),
      ];
      // 2일 연속, 3일째는 없음 → target=2 만 도달
      expect(MilestoneEngine.firstStreakReached(list, target: 2),
          DateTime(2026, 4, 2));
      expect(MilestoneEngine.firstStreakReached(list, target: 3), isNull);
    });
  });
}
