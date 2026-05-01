import 'package:blowfit/core/db/db_providers.dart';
import 'package:blowfit/features/guide/guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _stubRouter() => GoRouter(
      initialLocation: '/guide',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
        GoRoute(path: '/guide', builder: (_, __) => const GuideScreen()),
        GoRoute(path: '/training', builder: (_, __) => const Scaffold(body: Text('STUB:training'))),
      ],
    );

Widget _buildHarness({DateTime? firstSessionDate}) {
  return ProviderScope(
    overrides: [
      firstSessionDateProvider.overrideWith((ref) async => firstSessionDate),
    ],
    child: MaterialApp.router(routerConfig: _stubRouter()),
  );
}

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('first-time user sees 저강도 (4.0mm) recommendation', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_buildHarness(firstSessionDate: null));
    await tester.pumpAndSettle();

    expect(find.text('훈련 가이드'), findsOneWidget);
    expect(find.text('저강도'), findsOneWidget);
    expect(find.textContaining('4.0mm'), findsOneWidget);
    expect(find.textContaining('처음 사용'), findsOneWidget);
  });

  testWidgets('week 5 user sees 중강도 (3.0mm) recommendation', (tester) async {
    _useTallView(tester);
    final fiveWeeksAgo = DateTime.now().subtract(const Duration(days: 35));
    await tester.pumpWidget(_buildHarness(firstSessionDate: fiveWeeksAgo));
    await tester.pumpAndSettle();

    expect(find.text('중강도'), findsOneWidget);
    expect(find.textContaining('3.0mm'), findsOneWidget);
  });

  testWidgets('week 10 user sees 고강도 (2.0mm) recommendation', (tester) async {
    _useTallView(tester);
    final tenWeeksAgo = DateTime.now().subtract(const Duration(days: 70));
    await tester.pumpWidget(_buildHarness(firstSessionDate: tenWeeksAgo));
    await tester.pumpAndSettle();

    expect(find.text('고강도'), findsOneWidget);
    expect(find.textContaining('2.0mm'), findsOneWidget);
  });

  testWidgets('renders 3 phase titles + repetition info', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_buildHarness(firstSessionDate: null));
    await tester.pumpAndSettle();

    expect(find.text('시작'), findsOneWidget);
    expect(find.text('휴식'), findsOneWidget);
    expect(find.text('반복'), findsOneWidget);
    expect(find.textContaining('총 약 13분'), findsOneWidget);
  });

  testWidgets('tapping 훈련 시작 navigates to /training', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_buildHarness(firstSessionDate: null));
    await tester.pumpAndSettle();

    // Tap by text — button hierarchy (FilledButton.icon vs nested wrappers)
    // varies across Flutter versions; tapping the label hits the same target.
    await tester.tap(find.text('훈련 시작'));
    await tester.pumpAndSettle();

    expect(find.text('STUB:training'), findsOneWidget);
  });
}
