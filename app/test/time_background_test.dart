import 'package:blowfit/core/character/time_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('zoneForHour', () {
    test('0~4 → night (자정 ~ 새벽 5시 직전)', () {
      for (final h in [0, 2, 4]) {
        expect(zoneForHour(h), TimeZone.night, reason: 'hour $h');
      }
    });

    test('5~6 → dawn', () {
      for (final h in [5, 6]) {
        expect(zoneForHour(h), TimeZone.dawn, reason: 'hour $h');
      }
    });

    test('7~10 → morning', () {
      for (final h in [7, 9, 10]) {
        expect(zoneForHour(h), TimeZone.morning, reason: 'hour $h');
      }
    });

    test('11~13 → noon', () {
      for (final h in [11, 12, 13]) {
        expect(zoneForHour(h), TimeZone.noon, reason: 'hour $h');
      }
    });

    test('14~16 → afternoon', () {
      for (final h in [14, 15, 16]) {
        expect(zoneForHour(h), TimeZone.afternoon, reason: 'hour $h');
      }
    });

    test('17~19 → evening', () {
      for (final h in [17, 18, 19]) {
        expect(zoneForHour(h), TimeZone.evening, reason: 'hour $h');
      }
    });

    test('20~23 → night', () {
      for (final h in [20, 22, 23]) {
        expect(zoneForHour(h), TimeZone.night, reason: 'hour $h');
      }
    });

    test('경계값 — 5시 정각 = dawn 시작', () {
      expect(zoneForHour(5), TimeZone.dawn);
    });

    test('경계값 — 7시 정각 = morning 시작', () {
      expect(zoneForHour(7), TimeZone.morning);
    });

    test('경계값 — 20시 정각 = night 시작', () {
      expect(zoneForHour(20), TimeZone.night);
    });
  });

  group('TimeBackground widget', () {
    testWidgets('child 가 그대로 렌더링됨 (배경은 LinearGradient)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TimeBackground(
            clock: () => DateTime(2026, 5, 7, 12, 0), // noon
            child: const Text('hello otter'),
          ),
        ),
      );
      expect(find.text('hello otter'), findsOneWidget);
    });

    testWidgets('clock 다른 시각 → 다른 zone (build 시 매번 재계산)', (tester) async {
      Widget make(DateTime t) => MaterialApp(
            home: TimeBackground(
              clock: () => t,
              transitionDuration: const Duration(milliseconds: 50),
              child: const Text('zone-test'),
            ),
          );
      // 16:59 (afternoon)
      await tester.pumpWidget(make(DateTime(2026, 5, 7, 16, 59)));
      expect(find.text('zone-test'), findsOneWidget);
      // 17:00 (evening) — 새 widget 으로 rebuild → key 변경 → 페이드
      await tester.pumpWidget(make(DateTime(2026, 5, 7, 17, 0)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('zone-test'), findsOneWidget);
    });
  });
}
