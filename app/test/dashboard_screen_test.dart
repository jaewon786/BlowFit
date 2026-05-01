import 'package:blowfit/core/ble/ble_manager.dart';
import 'package:blowfit/core/ble/ble_providers.dart';
import 'package:blowfit/core/ble/fake_ble_manager.dart';
import 'package:blowfit/core/db/db_providers.dart';
import 'package:blowfit/features/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _stubRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/connect', builder: (_, __) => const _StubScreen('connect')),
        GoRoute(path: '/training', builder: (_, __) => const _StubScreen('training')),
      ],
    );

class _StubScreen extends StatelessWidget {
  final String name;
  const _StubScreen(this.name);
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('STUB:$name')));
}

Widget _buildHarness({
  required BleManager ble,
  int consecutiveDays = 0,
  int weekHits = 0,
  Duration todayDuration = Duration.zero,
}) {
  return ProviderScope(
    overrides: [
      bleManagerProvider.overrideWithValue(ble),
      consecutiveDaysProvider
          .overrideWith((ref) => Stream<int>.value(consecutiveDays)),
      weekHitsProvider.overrideWith((ref) => Stream<int>.value(weekHits)),
      todayDurationProvider
          .overrideWith((ref) => Stream<Duration>.value(todayDuration)),
    ],
    child: MaterialApp.router(routerConfig: _stubRouter()),
  );
}

/// Dashboard uses a ListView; bump the test surface so all children build.
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Dashboard renders BlowFit header + 오늘 목표 card', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    expect(find.text('BlowFit'), findsOneWidget);
    expect(find.text('오늘 목표'), findsOneWidget);
    expect(find.text('훈련 시작'), findsOneWidget);
  });

  testWidgets('disconnected state shows 기기 연결 prompt', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    // Train button is disabled
    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '훈련 시작'),
    );
    expect(btn.onPressed, isNull);

    // Connect prompt visible
    expect(find.text('기기 연결'), findsOneWidget);
    expect(find.text('기기를 먼저 연결해주세요'), findsOneWidget);
  });

  testWidgets('tapping 기기 연결 navigates to /connect', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, '기기 연결'));
    await tester.pumpAndSettle();

    expect(find.text('STUB:connect'), findsOneWidget);
  });

  testWidgets('stat cards reflect injected values', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(
      ble: fake,
      consecutiveDays: 5,
      weekHits: 6, // 6/7 = 86% rounded
      todayDuration: const Duration(minutes: 8),
    ));
    await tester.pump();

    expect(find.text('연속 사용일'), findsOneWidget);
    expect(find.text('주간 달성률'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('86'), findsOneWidget); // 6/7 * 100 = 85.7 → 86
  });

  testWidgets('goal progress shows minutes ratio', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(
      ble: fake,
      todayDuration: const Duration(minutes: 12),
    ));
    await tester.pump();

    // Inside the circular progress center: "12 / 20분" (RichText)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('오늘도 화이팅!'), findsOneWidget);
  });

  testWidgets('reaching the daily target switches the goal label', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(
      ble: fake,
      todayDuration: const Duration(minutes: 22),
    ));
    await tester.pump();

    expect(find.text('목표 달성!'), findsOneWidget);
  });

  testWidgets('bell icon shows coming-soon snackbar', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pump();

    expect(find.text('알림 기능은 곧 출시됩니다'), findsOneWidget);
  });
}
