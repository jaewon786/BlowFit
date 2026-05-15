import 'package:blowfit/core/ble/ble_manager.dart';
import 'package:blowfit/core/ble/ble_providers.dart';
import 'package:blowfit/core/ble/fake_ble_manager.dart';
import 'package:blowfit/core/theme/blowfit_theme.dart';
import 'package:blowfit/features/training/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _stubRouter() => GoRouter(
      initialLocation: '/training',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
        GoRoute(path: '/training', builder: (_, __) => const TrainingScreen()),
      ],
    );

Widget _buildHarness({required BleManager ble}) {
  return ProviderScope(
    overrides: [bleManagerProvider.overrideWithValue(ble)],
    child: MaterialApp.router(
      theme: BlowfitTheme.light(),
      routerConfig: _stubRouter(),
    ),
  );
}

void main() {
  testWidgets('Kirby v3 — progress bar + phase chip + pressure bar + 종료 버튼',
      (tester) async {
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    // 상단 진행 거리.
    expect(find.text('진행 거리'), findsOneWidget);
    // 1500m 목표 — '/ 1500 m'.
    expect(find.text(' / 1500 m'), findsOneWidget);
    // Phase chip — 세션 시작 전 '대기 중'.
    expect(find.text('대기 중'), findsOneWidget);
    // 압력 바 헤더.
    expect(find.text('실시간 압력'), findsOneWidget);
    // 압력 바 zone 범위 라벨 (default 20-30).
    expect(find.text('-30  ~  -20'), findsOneWidget);
    expect(find.text('+20  ~  +30'), findsOneWidget);
    // 종료 버튼.
    expect(find.text('훈련 종료'), findsOneWidget);
  });

  testWidgets('종료 button is disabled before any session starts',
      (tester) async {
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    final btn = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('훈련 종료'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(btn.onPressed, isNull);
  });
}
