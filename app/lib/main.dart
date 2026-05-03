import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/db/db_providers.dart';
import 'core/models/pressure_sample.dart';
import 'core/theme/blowfit_theme.dart';
import 'features/connect/connect_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/guide/guide_screen.dart';
import 'features/history/history_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile_setup/profile_setup_screen.dart';
import 'features/result/result_screen.dart';
import 'features/session_detail/session_detail_screen.dart';
import 'features/settings/target_settings_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/training/training_intro_screen.dart';
import 'features/training/training_screen.dart';
import 'features/trend/trend_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');
  // BLE permissions are requested by ConnectScreen with proper UX context;
  // asking on cold start surprises the user before they see why.
  runApp(const ProviderScope(child: BlowfitApp()));
}

final _rootNavKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
            // 훈련 시작 전 페이지 (체크리스트 + 팁) — 홈 탭 안에서 push.
            GoRoute(
              path: '/training-intro',
              builder: (_, __) => const TrainingIntroScreen(),
            ),
            // 실시간 훈련 — intro 의 시작 버튼에서 push.
            GoRoute(path: '/training', builder: (_, __) => const TrainingScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/trend', builder: (_, __) => const TrendScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ],
        ),
      ],
    ),
    // Top-level routes that cover the bottom nav (full-screen experiences).
    GoRoute(
      parentNavigatorKey: _rootNavKey,
      path: '/connect',
      builder: (_, __) => const ConnectScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavKey,
      path: '/session/:id',
      builder: (_, state) => SessionDetailScreen(
        sessionId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavKey,
      path: '/settings/target',
      builder: (_, __) => const TargetSettingsScreen(),
    ),
    // 훈련 종료 직후 push — extra 로 SessionSummary 전달.
    GoRoute(
      parentNavigatorKey: _rootNavKey,
      path: '/result',
      builder: (_, state) {
        final summary = state.extra as SessionSummary;
        return ResultScreen(summary: summary);
      },
    ),
    // 가이드는 더 이상 탭이 아니지만 widget test 호환을 위해 라우트 유지.
    GoRoute(
      parentNavigatorKey: _rootNavKey,
      path: '/guide',
      builder: (_, __) => const GuideScreen(),
    ),
    // 첫 사용 가이드 — 온보딩 슬라이드. 프로필 → '훈련 가이드 다시 보기'.
    GoRoute(
      parentNavigatorKey: _rootNavKey,
      path: '/onboarding',
      builder: (_, __) => const OnboardingScreen(),
    ),
    // 디자인 v2 — 온보딩 끝 → 프로필 설정 → 페어링.
    GoRoute(
      parentNavigatorKey: _rootNavKey,
      path: '/profile-setup',
      builder: (_, __) => const ProfileSetupScreen(),
    ),
  ],
);

class BlowfitApp extends ConsumerWidget {
  const BlowfitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Wire BLE session summaries into the local DB for the lifetime of the app.
    ref.watch(sessionPersistenceProvider);
    // 연결될 때마다 캐시된 목표 압력대를 펌웨어로 재전송 (펌웨어 reboot 시 default
    // 로 리셋되는 문제 해결).
    ref.watch(targetSyncProvider);
    // 앱 시작 시 마지막 연결한 device 자동 재연결 시도 (silent fallback).
    ref.watch(autoReconnectProvider);
    return MaterialApp.router(
      title: 'BlowFit',
      theme: BlowfitTheme.light(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

// 테마 정의는 core/theme/blowfit_theme.dart 로 이전됨.
