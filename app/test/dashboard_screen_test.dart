import 'package:blowfit/core/ble/ble_manager.dart';
import 'package:blowfit/core/ble/ble_providers.dart';
import 'package:blowfit/core/ble/fake_ble_manager.dart';
import 'package:blowfit/core/db/db_providers.dart';
import 'package:blowfit/core/db/session_repository.dart';
import 'package:blowfit/core/theme/blowfit_theme.dart';
import 'package:blowfit/features/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

GoRouter _stubRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/connect', builder: (_, __) => const _StubScreen('connect')),
        GoRoute(path: '/training', builder: (_, __) => const _StubScreen('training')),
        GoRoute(path: '/trend', builder: (_, __) => const _StubScreen('trend')),
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
      // 새 provider 들 — 실제 DB / SharedPreferences 안 건드리도록 빈 값으로.
      weekAvgPressureProvider.overrideWith(
        (ref) =>
            Stream<WeekPressureAvgPair>.value(
              (thisWeek: null, lastWeek: null),
            ),
      ),
    ],
    child: MaterialApp.router(
      theme: BlowfitTheme.light(),
      routerConfig: _stubRouter(),
    ),
  );
}

/// Dashboard uses a ListView; bump the test surface so all children build.
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko');
    // userProfileStoreProvider 가 SharedPreferences.getInstance() 를 호출하므로
    // 테스트에서 mock 채널 초기화. 빈 값 → 사용자 프로필 없음 (empty CTA 노출).
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Dashboard renders BlowFit header + 오늘의 훈련 CTA', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    expect(find.text('BlowFit'), findsOneWidget);
    expect(find.text('오늘의 훈련'), findsOneWidget);
    expect(find.text('5분 호흡 훈련'), findsOneWidget);
  });

  testWidgets('disconnected state shows 기기 연결 CTA', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    // CTA 버튼이 disconnected 시 '기기 연결' 라벨로 바뀜.
    expect(find.text('기기 연결'), findsWidgets);
    // Device card 도 '기기 연결 안 됨' 으로 표시.
    expect(find.text('기기 연결 안 됨'), findsOneWidget);
  });

  testWidgets('tapping 기기 연결 CTA navigates to /connect', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    // 그라데이션 CTA 안의 '기기 연결' (FilledButton) 탭.
    await tester.tap(find.text('기기 연결').first);
    await tester.pumpAndSettle();

    expect(find.text('STUB:connect'), findsOneWidget);
  });

  testWidgets('quick stats reflect injected weekHits', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(
      ble: fake,
      consecutiveDays: 5,
      weekHits: 6,
      todayDuration: const Duration(minutes: 8),
    ));
    await tester.pump();

    expect(find.text('이번 주'), findsOneWidget);
    expect(find.text('평균 호기 압력'), findsOneWidget);
    // weekHits=6 → "6 / 7회" (split across two Text widgets).
    expect(find.text('6'), findsOneWidget);
    expect(find.text(' / 7회'), findsOneWidget);
  });

  testWidgets('streak badge shows when consecutiveDays > 0', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(
      ble: fake,
      consecutiveDays: 12,
    ));
    await tester.pump();

    expect(find.text('12일 연속'), findsOneWidget);
  });

  testWidgets('coaching card shows weekly tip', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    // 신규 사용자 (weekHits=0, streak=0) → CoachingEngine 의 시작 안내 분기.
    expect(find.text('오늘 시작해보세요'), findsOneWidget);
    expect(find.text('자세히 보기'), findsOneWidget);
  });

  testWidgets('bell icon shows coming-soon snackbar', (tester) async {
    _useTallView(tester);
    final fake = FakeBleManager();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildHarness(ble: fake));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pump();

    expect(find.text('알림 기능은 곧 출시됩니다'), findsOneWidget);
  });
}
