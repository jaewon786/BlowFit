import 'package:blowfit/core/db/app_database.dart';
import 'package:blowfit/core/db/db_providers.dart';
import 'package:blowfit/features/session_detail/session_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Session _session({
  required int id,
  DateTime? startedAt,
  double maxPressure = 32.5,
  double avgPressure = 18.7,
  int durationSec = 1200,
  int enduranceSec = 18,
  int orificeLevel = 1,
  int targetHits = 4,
}) {
  return Session(
    id: id,
    deviceSessionId: id,
    startedAt: startedAt,
    durationSec: durationSec,
    maxPressure: maxPressure,
    avgPressure: avgPressure,
    enduranceSec: enduranceSec,
    orificeLevel: orificeLevel,
    targetHits: targetHits,
    sampleCount: 24000,
    crc32: 0,
    receivedAt: startedAt ?? DateTime.now(),
  );
}

Widget _buildHarness({Session? session, int sessionId = 1}) {
  return ProviderScope(
    overrides: [
      sessionByIdProvider(sessionId).overrideWith((ref) async => session),
    ],
    child: MaterialApp(home: SessionDetailScreen(sessionId: sessionId)),
  );
}

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko');
  });

  testWidgets('renders 5 stat rows from session data', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_buildHarness(
      session: _session(
        id: 1,
        startedAt: DateTime(2026, 5, 20, 10),
        maxPressure: 32.5,
        avgPressure: 18.7,
        durationSec: 1200,
        enduranceSec: 18,
        targetHits: 4,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('세션 기록'), findsOneWidget);
    expect(find.text('최대 압력'), findsOneWidget);
    expect(find.text('평균 압력'), findsOneWidget);
    expect(find.text('지구력 시간'), findsOneWidget);
    expect(find.text('훈련 시간'), findsOneWidget);
    expect(find.text('성공 횟수'), findsOneWidget);
    expect(find.textContaining('32.5'), findsOneWidget);
    expect(find.textContaining('18.7'), findsOneWidget);
    expect(find.text('00:18'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget); // 1200초
    expect(find.text('4회'), findsOneWidget);
  });

  testWidgets('shows orifice badge', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_buildHarness(
      session: _session(id: 1, orificeLevel: 1),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('중강도'), findsOneWidget);
  });

  testWidgets('analysis comment for high targetHits → 잘 달성', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_buildHarness(
      sessionId: 100,
      session: _session(id: 100, targetHits: 5),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('잘 달성'), findsOneWidget);
  });

  testWidgets('analysis comment for zero targetHits → 어려웠어요', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_buildHarness(
      sessionId: 200,
      session: _session(id: 200, targetHits: 0),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('어려웠어요'), findsOneWidget);
  });

  testWidgets('null session shows not-found message', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_buildHarness(sessionId: 999, session: null));
    await tester.pumpAndSettle();

    expect(find.textContaining('찾을 수 없습니다'), findsOneWidget);
  });
}
