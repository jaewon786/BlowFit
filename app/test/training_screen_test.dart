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
  testWidgets('Training renders phase guide + set chip + 종료 버튼', (tester) async {
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    // Phase 가이드 (초기 standby).
    expect(find.text('훈련을 시작하세요'), findsOneWidget);
    // 세트 chip.
    expect(find.text('세트 '), findsOneWidget);
    // 차트 헤더.
    expect(find.text('실시간 압력'), findsOneWidget);
    expect(find.text('목표 구간'), findsOneWidget);
    // 종료 버튼.
    expect(find.text('훈련 종료'), findsOneWidget);
  });

  testWidgets('종료 button is disabled before any session starts', (tester) async {
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    // FilledButton.icon 이 아닌 일반 FilledButton 으로 만들었으므로 byType 으로
    // 찾아도 OK. 하지만 안전하게 텍스트 ancestor 로 접근.
    final btn = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('훈련 종료'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('BreathOrb renders phase label initially',
      (tester) async {
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    // 디자인 v2: BottomStats 제거되고 BreathOrb 가 그 자리. 초기 standby.
    // "대기" 는 phase chip + orb 안 라벨 두 군데에 등장. "초" 단위는 orb 만.
    expect(find.text('대기'), findsAtLeastNWidgets(1));
    expect(find.text('초'), findsOneWidget);
  });
}
