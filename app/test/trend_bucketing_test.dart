import 'package:blowfit/core/db/app_database.dart';
import 'package:blowfit/core/db/trend_bucketing.dart';
import 'package:flutter_test/flutter_test.dart';

Session _s({
  required DateTime at,
  int id = 0,
  double avgPressure = 22.0,
  double maxPressure = 28.0,
}) =>
    Session(
      id: id,
      deviceSessionId: id,
      startedAt: null,
      durationSec: 240,
      maxPressure: maxPressure,
      avgPressure: avgPressure,
      enduranceSec: 180,
      orificeLevel: 1,
      targetHits: 3,
      sampleCount: 24000,
      crc32: 0,
      receivedAt: at,
    );

void main() {
  group('TrendPeriod.daily', () {
    // 2026-04-22 수요일 → 그 주 월요일 = 2026-04-20
    DateTime now() => DateTime(2026, 4, 22, 12);

    test('항상 7개 자리 (월~일)', () {
      final out =
          bucketizeForPeriod([], TrendPeriod.daily, now: now);
      expect(out, hasLength(7));
      expect(out.map((b) => b.label).toList(),
          ['월', '화', '수', '목', '금', '토', '일']);
      expect(out.first.xPos, 1);
      expect(out.last.xPos, 7);
      expect(out.every((b) => b.isEmpty), isTrue);
    });

    test('월요일 / 수요일 세션 → 해당 자리에 들어감', () {
      final list = [
        _s(
            at: DateTime(2026, 4, 20, 9),
            avgPressure: 18,
            maxPressure: 22,
            id: 1),
        _s(
            at: DateTime(2026, 4, 22, 14),
            avgPressure: 24,
            maxPressure: 30,
            id: 2),
      ];
      final out = bucketizeForPeriod(list, TrendPeriod.daily, now: now);
      expect(out[0].avgExhale, 18.0); // 월
      expect(out[0].sessionCount, 1);
      expect(out[2].avgExhale, 24.0); // 수
      expect(out[1].isEmpty, isTrue); // 화
      expect(out[6].isEmpty, isTrue); // 일
    });

    test('지난 주 / 다음 주 세션은 제외', () {
      final list = [
        _s(at: DateTime(2026, 4, 19), avgPressure: 99, id: 1), // 지난 일요일
        _s(at: DateTime(2026, 4, 27), avgPressure: 99, id: 2), // 다음 월
      ];
      final out = bucketizeForPeriod(list, TrendPeriod.daily, now: now);
      expect(out.every((b) => b.isEmpty), isTrue);
    });

    test('같은 날 두 세션은 평균', () {
      final list = [
        _s(
            at: DateTime(2026, 4, 22, 9),
            avgPressure: 20,
            id: 1),
        _s(
            at: DateTime(2026, 4, 22, 18),
            avgPressure: 30,
            id: 2),
      ];
      final out = bucketizeForPeriod(list, TrendPeriod.daily, now: now);
      expect(out[2].avgExhale, 25.0);
      expect(out[2].sessionCount, 2);
    });
  });

  group('TrendPeriod.weekly', () {
    // 6월 셋째 주 — 2026-06-17
    DateTime now() => DateTime(2026, 6, 17, 12);

    test('항상 4개 자리 (1주~4주)', () {
      final out = bucketizeForPeriod([], TrendPeriod.weekly, now: now);
      expect(out, hasLength(4));
      expect(out.map((b) => b.label).toList(), ['1주', '2주', '3주', '4주']);
    });

    test('1~7일 → 1주차, 8~14일 → 2주차, 15~21일 → 3주차, 22~말일 → 4주차', () {
      final list = [
        _s(at: DateTime(2026, 6, 3), avgPressure: 10, id: 1), // 1주
        _s(at: DateTime(2026, 6, 10), avgPressure: 20, id: 2), // 2주
        _s(at: DateTime(2026, 6, 18), avgPressure: 30, id: 3), // 3주
        _s(at: DateTime(2026, 6, 28), avgPressure: 40, id: 4), // 4주
      ];
      final out = bucketizeForPeriod(list, TrendPeriod.weekly, now: now);
      expect(out[0].avgExhale, 10.0);
      expect(out[1].avgExhale, 20.0);
      expect(out[2].avgExhale, 30.0);
      expect(out[3].avgExhale, 40.0);
    });

    test('22일 이후 모두 4주차에 포함', () {
      final list = [
        _s(at: DateTime(2026, 6, 22), avgPressure: 10, id: 1),
        _s(at: DateTime(2026, 6, 28), avgPressure: 20, id: 2),
        _s(at: DateTime(2026, 6, 30), avgPressure: 30, id: 3),
      ];
      final out = bucketizeForPeriod(list, TrendPeriod.weekly, now: now);
      expect(out[3].sessionCount, 3);
      expect(out[3].avgExhale, 20.0); // (10+20+30)/3
    });

    test('5월 / 7월 세션 제외', () {
      final list = [
        _s(at: DateTime(2026, 5, 31), avgPressure: 99, id: 1),
        _s(at: DateTime(2026, 7, 1), avgPressure: 99, id: 2),
      ];
      final out = bucketizeForPeriod(list, TrendPeriod.weekly, now: now);
      expect(out.every((b) => b.isEmpty), isTrue);
    });
  });

  group('TrendPeriod.monthly (올해 1~12월 12개 자리)', () {
    DateTime now() => DateTime(2026, 6, 15, 12);

    test('항상 12개 자리 (1월~12월)', () {
      final out = bucketizeForPeriod([], TrendPeriod.monthly, now: now);
      expect(out, hasLength(12));
      expect(out.first.label, '1월');
      expect(out.last.label, '12월');
    });

    test('올해 세션만 포함, 작년/내년 제외', () {
      final list = [
        _s(at: DateTime(2026, 3, 10), avgPressure: 20, id: 1),
        _s(at: DateTime(2026, 6, 15), avgPressure: 30, id: 2),
        _s(at: DateTime(2025, 12, 31), avgPressure: 99, id: 3),
        _s(at: DateTime(2027, 1, 1), avgPressure: 99, id: 4),
      ];
      final out = bucketizeForPeriod(list, TrendPeriod.monthly, now: now);
      expect(out[2].avgExhale, 20.0); // 3월
      expect(out[5].avgExhale, 30.0); // 6월
      expect(out[11].isEmpty, isTrue); // 12월
      expect(out[0].isEmpty, isTrue); // 1월 (작년 12/31 제외 확인)
    });

    test('미래 달 (오늘 이후) 자리 잡지만 비어있음', () {
      final out = bucketizeForPeriod([], TrendPeriod.monthly, now: now);
      for (var i = 0; i < 12; i++) {
        expect(out[i].xPos, i + 1);
        expect(out[i].isEmpty, isTrue);
      }
    });

    test('같은 달 여러 세션은 평균', () {
      final list = [
        _s(at: DateTime(2026, 6, 5), avgPressure: 20, id: 1),
        _s(at: DateTime(2026, 6, 20), avgPressure: 30, id: 2),
      ];
      final out = bucketizeForPeriod(list, TrendPeriod.monthly, now: now);
      expect(out[5].avgExhale, 25.0);
      expect(out[5].sessionCount, 2);
    });
  });

  group('TrendPeriod.yearly (최근 3년)', () {
    DateTime now() => DateTime(2026, 6, 15, 12);

    test('항상 3개 자리, 라벨은 연도 (2024 / 2025 / 2026)', () {
      final out = bucketizeForPeriod([], TrendPeriod.yearly, now: now);
      expect(out, hasLength(3));
      expect(out.map((b) => b.label).toList(), ['2024', '2025', '2026']);
    });

    test('각 연도의 세션이 해당 자리에', () {
      final list = [
        _s(at: DateTime(2024, 5, 10), avgPressure: 10, id: 1),
        _s(at: DateTime(2025, 8, 20), avgPressure: 20, id: 2),
        _s(at: DateTime(2026, 6, 5), avgPressure: 30, id: 3),
      ];
      final out = bucketizeForPeriod(list, TrendPeriod.yearly, now: now);
      expect(out[0].avgExhale, 10.0);
      expect(out[1].avgExhale, 20.0);
      expect(out[2].avgExhale, 30.0);
    });

    test('3년 윈도우 밖 (2023 이전) 세션 제외', () {
      final list = [
        _s(at: DateTime(2023, 12, 31), avgPressure: 99, id: 1),
      ];
      final out = bucketizeForPeriod(list, TrendPeriod.yearly, now: now);
      expect(out.every((b) => b.isEmpty), isTrue);
    });

    test('한 해 여러 세션은 평균', () {
      final list = [
        _s(at: DateTime(2026, 1, 5), avgPressure: 10, id: 1),
        _s(at: DateTime(2026, 6, 20), avgPressure: 20, id: 2),
        _s(at: DateTime(2026, 12, 1), avgPressure: 30, id: 3),
      ];
      final out = bucketizeForPeriod(list, TrendPeriod.yearly, now: now);
      expect(out[2].avgExhale, 20.0); // 모든 2026 세션 평균
      expect(out[2].sessionCount, 3);
    });
  });

  group('sinceForPeriod', () {
    test('daily — 이번 주 월요일', () {
      // 2026-04-22 수요일 → 2026-04-20 월
      expect(
        sinceForPeriod(TrendPeriod.daily, DateTime(2026, 4, 22, 12)),
        DateTime(2026, 4, 20),
      );
    });

    test('weekly — 이번 달 1일', () {
      expect(
        sinceForPeriod(TrendPeriod.weekly, DateTime(2026, 6, 17)),
        DateTime(2026, 6, 1),
      );
    });

    test('monthly — 올해 1월 1일', () {
      expect(
        sinceForPeriod(TrendPeriod.monthly, DateTime(2026, 6, 15)),
        DateTime(2026, 1, 1),
      );
    });

    test('yearly — 2년 전 1월 1일 (3년 윈도우)', () {
      expect(
        sinceForPeriod(TrendPeriod.yearly, DateTime(2026, 6, 15)),
        DateTime(2024, 1, 1),
      );
    });
  });
}
