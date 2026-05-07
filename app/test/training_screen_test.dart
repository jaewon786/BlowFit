import 'package:blowfit/core/ble/ble_manager.dart';
import 'package:blowfit/core/ble/ble_providers.dart';
import 'package:blowfit/core/ble/fake_ble_manager.dart';
import 'package:blowfit/core/character/otter_character.dart';
import 'package:blowfit/core/db/db_providers.dart';
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
    overrides: [
      bleManagerProvider.overrideWithValue(ble),
      // firstSessionDateProvider 우회 — 실 Drift DB 가 test 환경에서 Timer
      // leak 을 일으키므로 null 로 stub. 캐릭터 성장 단계는 baby (기본).
      firstSessionDateProvider.overrideWith((_) async => null),
      // characterAssetPathProvider 빈 문자열로 override — Rive .riv 파싱 시
      // test 환경에서 비동기 에러 전파 방지. OtterCharacter 가 fallback
      // (BreathOrb) 로 안전 분기.
      characterAssetPathProvider.overrideWithValue(''),
    ],
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

  testWidgets('BreathOrb fallback renders when seal.riv override empty',
      (tester) async {
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    // characterAssetPathProvider 가 '' 로 override → Rive 우회 →
    // OtterCharacter 가 BreathOrb fallback 렌더링. "대기" 는 phase chip +
    // BreathOrb 안 라벨 두 군데, "초" 는 BreathOrb 의 카운트업.
    expect(find.text('대기'), findsAtLeastNWidgets(1));
    expect(find.text('초'), findsOneWidget);
  });
}
