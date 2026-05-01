import 'package:blowfit/core/ble/ble_manager.dart';
import 'package:blowfit/core/ble/ble_providers.dart';
import 'package:blowfit/core/ble/fake_ble_manager.dart';
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
    child: MaterialApp.router(routerConfig: _stubRouter()),
  );
}

void main() {
  testWidgets('Training renders title + 현재 압력 + 종료 버튼', (tester) async {
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    expect(find.text('실시간 훈련'), findsOneWidget);
    expect(find.text('현재 압력'), findsOneWidget);
    expect(find.text('훈련 종료'), findsOneWidget);
    expect(find.textContaining('목표 구간'), findsOneWidget);
  });

  testWidgets('connection chip shows 끊김 when not connected', (tester) async {
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    expect(find.text('끊김'), findsOneWidget);
  });

  testWidgets('phase chip is hidden in standby/training (matches wireframe)',
      (tester) async {
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    // 와이어프레임 ③ 매칭: 대기/훈련 중일 때 phase chip 미노출.
    expect(find.textContaining('현재:'), findsNothing);
  });

  testWidgets('종료 button is disabled before any session starts', (tester) async {
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '훈련 종료'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('endurance + elapsed counters render at 00:00 initially', (tester) async {
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    expect(find.text('지구력 시간'), findsOneWidget);
    expect(find.text('훈련 시간'), findsOneWidget);
    expect(find.text('00:00'), findsAtLeastNWidgets(2));
  });
}
