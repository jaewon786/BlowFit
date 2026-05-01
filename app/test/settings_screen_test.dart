import 'package:blowfit/core/ble/ble_manager.dart';
import 'package:blowfit/core/ble/ble_providers.dart';
import 'package:blowfit/core/ble/fake_ble_manager.dart';
import 'package:blowfit/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

GoRouter _stubRouter() => GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(
          path: '/connect',
          builder: (_, __) => const Scaffold(body: Text('STUB:connect')),
        ),
        GoRoute(
          path: '/settings/target',
          builder: (_, __) => const Scaffold(body: Text('STUB:target')),
        ),
      ],
    );

Widget _buildHarness({required BleManager ble}) {
  return ProviderScope(
    overrides: [bleManagerProvider.overrideWithValue(ble)],
    child: MaterialApp.router(routerConfig: _stubRouter()),
  );
}

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders all 7 settings entries', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pumpAndSettle();

    expect(find.text('설정'), findsOneWidget);
    expect(find.text('내 기기'), findsOneWidget);
    expect(find.text('목표 압력 설정'), findsOneWidget);
    expect(find.text('훈련 알림'), findsOneWidget);
    expect(find.text('오리피스 단계 관리'), findsOneWidget);
    expect(find.text('펌웨어 업데이트'), findsOneWidget);
    expect(find.text('도움말'), findsOneWidget);
    expect(find.text('앱 정보'), findsOneWidget);
  });

  testWidgets('내 기기 tile navigates to /connect', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('내 기기'));
    await tester.pumpAndSettle();

    expect(find.text('STUB:connect'), findsOneWidget);
  });

  testWidgets('목표 압력 설정 tile navigates to /settings/target', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('목표 압력 설정'));
    await tester.pumpAndSettle();

    expect(find.text('STUB:target'), findsOneWidget);
  });

  testWidgets('coming-soon entries trigger SnackBar', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('훈련 알림'));
    await tester.pump();

    expect(find.textContaining('곧 출시'), findsOneWidget);
  });

  testWidgets('앱 정보 opens about dialog', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('앱 정보'));
    await tester.pumpAndSettle();

    expect(find.text('BlowFit'), findsAtLeastNWidgets(1));
    // showAboutDialog renders AboutDialog
    expect(find.byType(AboutDialog), findsOneWidget);
  });

  testWidgets('disconnected state shows 연결 안 됨 in 내 기기 card', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pumpAndSettle();

    expect(find.textContaining('연결된 기기 없음').or(find.textContaining('기기 연결을 시작')),
        findsAtLeastNWidgets(1));
  });
}

extension on Finder {
  Finder or(Finder other) =>
      find.byWidgetPredicate(
        (w) =>
            evaluate().any((e) => e.widget == w) ||
            other.evaluate().any((e) => e.widget == w),
      );
}
