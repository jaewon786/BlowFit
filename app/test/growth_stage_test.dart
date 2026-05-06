import 'package:blowfit/core/character/growth_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stageFromWeeks', () {
    test('0~3주 → baby', () {
      for (final w in [-1, 0, 1, 3]) {
        expect(stageFromWeeks(w), GrowthStage.baby, reason: 'week $w');
      }
    });

    test('4~7주 → young', () {
      for (final w in [4, 5, 7]) {
        expect(stageFromWeeks(w), GrowthStage.young, reason: 'week $w');
      }
    });

    test('8~11주 → adult', () {
      for (final w in [8, 10, 11]) {
        expect(stageFromWeeks(w), GrowthStage.adult, reason: 'week $w');
      }
    });

    test('12주+ → master', () {
      for (final w in [12, 20, 100]) {
        expect(stageFromWeeks(w), GrowthStage.master, reason: 'week $w');
      }
    });
  });

  group('weeksSince', () {
    test('null startedAt → 0', () {
      expect(weeksSince(null), 0);
    });

    test('미래 startedAt → 0', () {
      final now = DateTime(2026, 5, 7);
      final future = DateTime(2026, 5, 14);
      expect(weeksSince(future, now: now), 0);
    });

    test('정확히 7일 → 1주', () {
      final start = DateTime(2026, 5, 1);
      final now = DateTime(2026, 5, 8);
      expect(weeksSince(start, now: now), 1);
    });

    test('6일 → 0주 (정수 절삭)', () {
      final start = DateTime(2026, 5, 1);
      final now = DateTime(2026, 5, 7);
      expect(weeksSince(start, now: now), 0);
    });

    test('30일 → 4주', () {
      final start = DateTime(2026, 4, 1);
      final now = DateTime(2026, 5, 1);
      expect(weeksSince(start, now: now), 4);
    });
  });

  group('stageFromStartedAt', () {
    test('null → baby', () {
      expect(stageFromStartedAt(null), GrowthStage.baby);
    });

    test('12주 후 → master', () {
      final start = DateTime(2026, 1, 1);
      final now = DateTime(2026, 4, 1); // ~90일 = 12주 후반
      expect(stageFromStartedAt(start, now: now), GrowthStage.master);
    });

    test('5주 후 → young', () {
      final start = DateTime(2026, 4, 1);
      final now = DateTime(2026, 5, 7); // 36일 = 5주 1일
      expect(stageFromStartedAt(start, now: now), GrowthStage.young);
    });
  });
}
