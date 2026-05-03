import 'package:blowfit/core/coach/coaching_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoachingEngine.dashboardWeekly', () {
    test('신규 사용자 — 시작 안내', () {
      final tip = CoachingEngine.dashboardWeekly(
        weekHits: 0,
        currentStreak: 0,
        thisWeekAvg: null,
        lastWeekAvg: null,
      );
      expect(tip.tone, CoachingTone.info);
      expect(tip.eyebrow, '오늘 시작해보세요');
    });

    test('지난주 대비 향상 ≥ 1.5 → positive + delta 표시', () {
      final tip = CoachingEngine.dashboardWeekly(
        weekHits: 4,
        currentStreak: 3,
        thisWeekAvg: 23.0,
        lastWeekAvg: 20.0,
      );
      expect(tip.tone, CoachingTone.positive);
      expect(tip.body.contains('+3.0'), isTrue);
    });

    test('지난주 대비 후퇴 ≤ -1.5 → warning', () {
      final tip = CoachingEngine.dashboardWeekly(
        weekHits: 3,
        currentStreak: 3,
        thisWeekAvg: 18.0,
        lastWeekAvg: 22.0,
      );
      expect(tip.tone, CoachingTone.warning);
    });

    test('streak 7일 이상 → eyebrow 에 일수 표시', () {
      final tip = CoachingEngine.dashboardWeekly(
        weekHits: 5,
        currentStreak: 12,
        thisWeekAvg: 22.0,
        lastWeekAvg: 22.0, // delta 0 → streak 분기로
      );
      expect(tip.eyebrow.contains('12일째'), isTrue);
      expect(tip.tone, CoachingTone.positive);
    });

    test('이번 주 5회 이상 — positive', () {
      final tip = CoachingEngine.dashboardWeekly(
        weekHits: 6,
        currentStreak: 2, // streak 7 미만
        thisWeekAvg: 22.0,
        lastWeekAvg: 22.0,
      );
      expect(tip.tone, CoachingTone.positive);
    });

    test('1~4회 기본 격려 — info', () {
      final tip = CoachingEngine.dashboardWeekly(
        weekHits: 2,
        currentStreak: 2,
        thisWeekAvg: 22.0,
        lastWeekAvg: 22.0,
      );
      expect(tip.tone, CoachingTone.info);
    });
  });

  group('CoachingEngine.resultScoreMessage', () {
    test('90+ 5/5 hits → 훌륭한', () {
      expect(
        CoachingEngine.resultScoreMessage(score: 95, targetHits: 5),
        '훌륭한 훈련이었어요!',
      );
    });

    test('75~89 → 잘하셨어요', () {
      expect(
        CoachingEngine.resultScoreMessage(score: 80, targetHits: 3),
        '잘하셨어요!',
      );
    });

    test('50~74 → 꾸준히 발전', () {
      expect(
        CoachingEngine.resultScoreMessage(score: 60, targetHits: 2),
        '꾸준히 발전하고 있어요',
      );
    });

    test('<50 → 다시 도전', () {
      expect(
        CoachingEngine.resultScoreMessage(score: 30, targetHits: 1),
        '내일 다시 도전해봐요',
      );
    });
  });

  group('CoachingEngine.resultNote', () {
    test('점수 < 50 → 가벼운 오리피스 안내', () {
      final tip = CoachingEngine.resultNote(
        score: 40,
        targetHits: 1,
        endurancePct: 0.3,
        deltaVsLastWeek: null,
      );
      expect(tip.body.contains('가벼운'), isTrue);
      expect(tip.tone, CoachingTone.info);
    });

    test('지난주 대비 향상 ≥ 1 → positive + delta', () {
      final tip = CoachingEngine.resultNote(
        score: 70,
        targetHits: 3,
        endurancePct: 0.5,
        deltaVsLastWeek: 2.5,
      );
      expect(tip.tone, CoachingTone.positive);
      expect(tip.body.contains('+2.5'), isTrue);
    });

    test('endurance ≥ 0.7 → 다음 단계 권유', () {
      final tip = CoachingEngine.resultNote(
        score: 80,
        targetHits: 4,
        endurancePct: 0.85,
        deltaVsLastWeek: null,
      );
      expect(tip.tone, CoachingTone.positive);
      expect(tip.body.contains('다음'), isTrue);
    });

    test('targetHits ≥ 4 — 일반 칭찬', () {
      final tip = CoachingEngine.resultNote(
        score: 70,
        targetHits: 4,
        endurancePct: 0.4,
        deltaVsLastWeek: 0.0, // delta 1 미만
      );
      expect(tip.tone, CoachingTone.positive);
    });

    test('default — 격려 info', () {
      final tip = CoachingEngine.resultNote(
        score: 55,
        targetHits: 2,
        endurancePct: 0.3,
        deltaVsLastWeek: 0.0,
      );
      expect(tip.tone, CoachingTone.info);
    });
  });
}
