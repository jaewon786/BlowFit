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
      avgInhale: 0,
      maxInhale: 0,
      enduranceSec: 180,
      orificeLevel: 1,
      targetHits: 3,
      sampleCount: 24000,
      crc32: 0,
      receivedAt: at,
    );

void main() {
  group('MilestoneEngine.compute', () {
    test('empty input — 6개 모두 미달성', () {
      final ms = MilestoneEngine.compute(sessions: []);
      expect(ms, hasLength(6));
      expect(ms.every((m) => !m.achieved), isTrue);
      expect(ms.map((m) => m.week).toList(), [1, 2, 3, 4, 5, 6]);
    });

    test('첫 세션 → 1주차 달성, 2~6주차 미달성', () {
      final t = DateTime(2026, 4, 1);
      final ms = MilestoneEngine.compute(sessions: [_s(at: t, id: 1)]);
      expect(ms[0].achieved, isTrue);
      expect(ms[0].achievedAt!.isAtSameMomentAs(t), isTrue);
      expect(ms[0].title, '1주차 - 첫 훈련 완료');
      expect(ms[1].title, '2주차 - 연속 훈련 완료');
      for (var i = 1; i < 6; i++) {
        expect(ms[i].achieved, isFalse, reason: '${i + 1}주차');
      }
    });

    test('3주 연속(매주 1회) → 1~3주차 달성, 4주차+ 미달성', () {
      final start = DateTime(2026, 4, 1);
      final ms = MilestoneEngine.compute(
        sessions: [
          _s(at: start, id: 1), // week 0
          _s(at: start.add(const Duration(days: 8)), id: 2), // week 1
          _s(at: start.add(const Duration(days: 16)), id: 3), // week 2
        ],
      );
      expect(ms[0].achieved, isTrue); // 1주차
      expect(ms[1].achieved, isTrue); // 2주차
      expect(ms[2].achieved, isTrue); // 3주차
      expect(ms[3].achieved, isFalse); // 4주차
      // 3주차 달성일 = week 2 의 첫 세션.
      expect(ms[2].achievedAt, start.add(const Duration(days: 16)));
    });

    test('중간 주 누락 → 연속 끊김(2주차+ 미달성)', () {
      final start = DateTime(2026, 4, 1);
      // week 0 과 week 2 만 (week 1 누락).
      final ms = MilestoneEngine.compute(
        sessions: [
          _s(at: start, id: 1),
          _s(at: start.add(const Duration(days: 16)), id: 2),
        ],
      );
      expect(ms[0].achieved, isTrue); // 1주차
      expect(ms[1].achieved, isFalse); // 2주차 — week 1 누락
      expect(ms[2].achieved, isFalse); // 3주차
    });
  });

  group('consecutiveWeeksReached (pure)', () {
    test('빈 입력 → null', () {
      expect(MilestoneEngine.consecutiveWeeksReached([], target: 2), isNull);
    });

    test('같은 주 여러 세션 → 1주차만 달성, 2주차 미달', () {
      final t = DateTime(2026, 4, 1);
      final list = [
        _s(at: t, id: 1),
        _s(at: t.add(const Duration(days: 3)), id: 2), // 여전히 week 0
      ];
      expect(
        MilestoneEngine.consecutiveWeeksReached(list, target: 1),
        isNotNull,
      );
      expect(MilestoneEngine.consecutiveWeeksReached(list, target: 2), isNull);
    });

    test('6주 연속 → 6주차 달성일 = week 5 첫 세션', () {
      final start = DateTime(2026, 4, 1);
      final list = [
        for (var w = 0; w < 6; w++)
          _s(at: start.add(Duration(days: w * 7)), id: w),
      ];
      expect(
        MilestoneEngine.consecutiveWeeksReached(list, target: 6),
        start.add(const Duration(days: 35)),
      );
    });
  });
}
