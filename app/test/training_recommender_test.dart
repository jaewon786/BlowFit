import 'package:blowfit/core/ble/blowfit_uuids.dart';
import 'package:blowfit/core/coach/training_recommender.dart';
import 'package:flutter_test/flutter_test.dart';

SessionPerf _perf({
  required double avg,
  required int orifice,
  required double hit,
  required int day,
}) =>
    SessionPerf(
      orificeLevel: orifice,
      avgExhale: avg,
      durationSec: 100,
      enduranceSec: (hit * 100).round(),
      at: DateTime(2026, 1, 1).add(Duration(days: day)),
    );

void main() {
  group('dialForWeeks', () {
    test('주차 → 다이얼 매핑', () {
      expect(dialForWeeks(0), OrificeLevel.low);
      expect(dialForWeeks(3), OrificeLevel.low);
      expect(dialForWeeks(4), OrificeLevel.medium);
      expect(dialForWeeks(7), OrificeLevel.medium);
      expect(dialForWeeks(8), OrificeLevel.high);
      expect(dialForWeeks(12), OrificeLevel.high);
    });
  });

  test('데이터 부족(<3) → 주차 폴백', () {
    final rec = recommendTraining(
      recent: [_perf(avg: 30, orifice: 1, hit: 0.8, day: 0)],
      currentDial: OrificeLevel.medium,
      currentMinutes: 5,
      weeksUsing: 5,
    );
    expect(rec.isFallback, isTrue);
    expect(rec.dial, OrificeLevel.medium); // dialForWeeks(5)
    expect(rec.minutes, 5);
  });

  test('마스터(고도달률+성장) → 다이얼↑ + 시간↑', () {
    final rec = recommendTraining(
      recent: [
        _perf(avg: 30, orifice: 1, hit: 0.8, day: 0),
        _perf(avg: 32, orifice: 1, hit: 0.8, day: 2),
        _perf(avg: 34, orifice: 1, hit: 0.8, day: 4),
        _perf(avg: 36, orifice: 1, hit: 0.8, day: 6),
      ],
      currentDial: OrificeLevel.medium,
      currentMinutes: 5,
      weeksUsing: 10,
    );
    expect(rec.isFallback, isFalse);
    expect(rec.dial, OrificeLevel.high); // 2단 → 3단
    expect(rec.minutes, 10); // 5 → 10
    expect(rec.reason, contains('올려'));
  });

  test('고전(저도달률) → 다이얼↓', () {
    final rec = recommendTraining(
      recent: [
        _perf(avg: 30, orifice: 1, hit: 0.2, day: 0),
        _perf(avg: 29, orifice: 1, hit: 0.2, day: 2),
        _perf(avg: 28, orifice: 1, hit: 0.2, day: 4),
        _perf(avg: 27, orifice: 1, hit: 0.2, day: 6),
      ],
      currentDial: OrificeLevel.medium,
      currentMinutes: 5,
      weeksUsing: 10,
    );
    expect(rec.dial, OrificeLevel.low); // 2단 → 1단
    expect(rec.reason, contains('낮춰'));
  });

  test('적정(중간 도달률·유지) → 단계 유지', () {
    final rec = recommendTraining(
      recent: [
        _perf(avg: 32, orifice: 1, hit: 0.5, day: 0),
        _perf(avg: 32, orifice: 1, hit: 0.5, day: 2),
        _perf(avg: 32, orifice: 1, hit: 0.5, day: 4),
        _perf(avg: 32, orifice: 1, hit: 0.5, day: 6),
      ],
      currentDial: OrificeLevel.medium,
      currentMinutes: 5,
      weeksUsing: 10,
    );
    expect(rec.dial, OrificeLevel.medium);
    expect(rec.minutes, 5);
  });

  test('주차 상한 가드레일 — 성과 좋아도 week<4 면 다이얼 유지(시간만↑)', () {
    final rec = recommendTraining(
      recent: [
        _perf(avg: 18, orifice: 0, hit: 0.8, day: 0),
        _perf(avg: 20, orifice: 0, hit: 0.8, day: 2),
        _perf(avg: 22, orifice: 0, hit: 0.8, day: 4),
        _perf(avg: 24, orifice: 0, hit: 0.8, day: 6),
      ],
      currentDial: OrificeLevel.low,
      currentMinutes: 5,
      weeksUsing: 1, // cap = low(1단)
    );
    expect(rec.dial, OrificeLevel.low); // stepUp→medium 이지만 cap=low 로 clamp
    expect(rec.minutes, 10);
  });

  test('경계 clamp — 이미 3단이면 마스터해도 3단 유지', () {
    final rec = recommendTraining(
      recent: [
        _perf(avg: 70, orifice: 2, hit: 0.8, day: 0),
        _perf(avg: 74, orifice: 2, hit: 0.8, day: 2),
        _perf(avg: 78, orifice: 2, hit: 0.8, day: 4),
        _perf(avg: 82, orifice: 2, hit: 0.8, day: 6),
      ],
      currentDial: OrificeLevel.high,
      currentMinutes: 10,
      weeksUsing: 12,
    );
    expect(rec.dial, OrificeLevel.high);
    expect(rec.minutes, 10); // 이미 최대
  });
}
