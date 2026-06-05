import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/ble/ble_foreground_task.dart';
import 'core/ble/ble_providers.dart';
import 'core/db/db_providers.dart';
import 'core/models/pressure_sample.dart';
import 'core/storage/user_role_store.dart';
import 'core/theme/blowfit_theme.dart';
import 'features/companion/companion_screen.dart';
import 'features/companion/connection_code_screen.dart';
import 'features/connect/connect_screen.dart';
import 'features/guide/guide_screen.dart';
import 'features/home_pager/home_pager_screen.dart';
import 'features/history/history_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/pairing/my_code_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/role/role_select_screen.dart';
import 'features/profile_setup/profile_setup_screen.dart';
import 'features/result/result_screen.dart';
import 'features/session_detail/session_detail_screen.dart';
import 'features/settings/samsung_health_test_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/sleep/sleep_effect_screen.dart';
import 'features/sleep/sleep_trend_screen.dart';
import 'features/settings/target_settings_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/training/training_intro_screen.dart';
import 'features/training/training_screen.dart';
import 'features/trend/trend_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');

  // Firebase 초기화 + 익명 로그인 — 동반자 모드(훈련 데이터 공유 + 연결 코드
  // 페어링)용. 각 설치마다 고유 UID. 오프라인/실패해도 앱은 정상 구동되도록 try.
  try {
    await Firebase.initializeApp();
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    debugPrint('[firebase] init/auth failed: $e');
  }

  // 사용 역할(디바이스 사용자/동반자) 로드 — 라우터 redirect 가 동기적으로
  // 참조하도록 메모리(appRoleNotifier)에 올린다. 미선택이면 null → 역할 선택 화면.
  final roleStore = await UserRoleStore.open();
  appRoleNotifier.value = roleStore.load();
  // BLE permissions are requested by ConnectScreen with proper UX context;
  // asking on cold start surprises the user before they see why.

  // Foreground service 의 notification channel + task option 초기화.
  await BleForegroundService.initialize();
  // 이전 빌드에서 startService 가 호출되어 service 가 background 에 살아있을
  // 수 있음. Split-brain (main app vs service process 가 각각 BLE 잡으려고
  // 경합) 방지하려고 명시적으로 정지. autoRunOnBoot/autoRunOnMyPackageReplaced
  // 도 stopService 호출 시 비활성화됨.
  try {
    await BleForegroundService.stopService();
  } catch (_) {
    // service 가 안 돌고 있었으면 throw — 무시.
  }

  runApp(const ProviderScope(child: BlowfitApp()));
}

final _rootNavKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavKey,
  // 앱 시작 화면 = Home (dashboard). v2 디자인 결정 — 앱 실행 시 무조건
  // 홈 화면. 자동 재연결은 background 의 autoReconnectProvider 가 처리하고,
  // 디바이스 연결 UI 는 사용자가 명시적으로 '/connect' 로 이동했을 때만 노출.
  initialLocation: '/',
  // 역할에 따라 진입 화면 분기. appRoleNotifier 값이 바뀌면(역할 선택 시)
  // refreshListenable 로 redirect 재평가.
  refreshListenable: appRoleNotifier,
  redirect: (context, state) {
    final role = appRoleNotifier.value;
    final loc = state.matchedLocation;
    // 1) 역할 미선택 → 역할 선택 화면 강제.
    if (role == null) {
      return loc == '/role-select' ? null : '/role-select';
    }
    // 2) 동반자 → 동반자 화면(/companion*)만 허용.
    if (role == AppRole.companion) {
      return loc.startsWith('/companion') ? null : '/companion';
    }
    // 3) 디바이스 사용자 → 역할 선택/동반자 화면 차단.
    if (loc == '/role-select' || loc.startsWith('/companion')) return '/';
    return null;
  },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            // 홈 = 홈/추이 PageView (좌우 swipe 로 전환)
            GoRoute(path: '/', builder: (_, __) => const HomePagerScreen()),
            // 훈련 시작 전 페이지 (체크리스트 + 팁) — 홈 탭 안에서 push.
            GoRoute(
              path: '/training-intro',
              builder: (_, __) => const TrainingIntroScreen(),
            ),
            // 실시간 훈련 — intro 의 시작 버튼에서 push.
            GoRoute(path: '/training', builder: (_, __) => const TrainingScreen()),
            // 설정 — 홈의 톱니바퀴 아이콘에서 push. /training 과 같은 branch
            // 라우트로 두어야 shell branch context 에서 push 가 안정적으로
            // 동작 (root-level parentNavigatorKey 라우트는 일부 케이스에서
            // silent fail).
            GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
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
    // 개발용 — Samsung Health Data SDK 연동 검증 화면.
    GoRoute(
      parentNavigatorKey: _rootNavKey,
      path: '/shealth-test',
      builder: (_, __) => const SamsungHealthTestScreen(),
    ),
    // 수면 효과 시각화 (before/after + SpO2 추이).
    GoRoute(
      parentNavigatorKey: _rootNavKey,
      path: '/sleep-effect',
      builder: (_, __) => const SleepEffectScreen(),
    ),
    // 수면 추이 (추이 화면 스타일).
    GoRoute(
      parentNavigatorKey: _rootNavKey,
      path: '/sleep-trend',
      builder: (_, __) => const SleepTrendScreen(),
    ),
    // 첫 실행 — 역할 선택 (디바이스 사용자 / 동반자). 선택 후 변경 불가.
    GoRoute(
      parentNavigatorKey: _rootNavKey,
      path: '/role-select',
      builder: (_, __) => const RoleSelectScreen(),
    ),
    // 동반자(배우자·애인) 전용 홈.
    GoRoute(
      parentNavigatorKey: _rootNavKey,
      path: '/companion',
      builder: (_, __) => const CompanionScreen(),
    ),
    // 동반자 — 연결 코드 입력 (반드시 /companion 하위라야 동반자 redirect 통과).
    GoRoute(
      parentNavigatorKey: _rootNavKey,
      path: '/companion/link',
      builder: (_, __) => const ConnectionCodeScreen(),
    ),
    // 디바이스 사용자 — 동반자에게 줄 연결 코드 표시.
    GoRoute(
      parentNavigatorKey: _rootNavKey,
      path: '/my-code',
      builder: (_, __) => const MyCodeScreen(),
    ),
  ],
);

class BlowfitApp extends ConsumerStatefulWidget {
  const BlowfitApp({super.key});

  @override
  ConsumerState<BlowfitApp> createState() => _BlowfitAppState();
}

class _BlowfitAppState extends ConsumerState<BlowfitApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 알림 권한 (Android 13+) — 다음 frame 에서 요청 (context 안정화 후).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final permResult = await FlutterForegroundTask.checkNotificationPermission();
      if (permResult != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 background → foreground 복귀할 때 BLE link 정리.
    //
    // 백그라운드 동안 OS 가 GATT 를 끊었거나 일시 중단하면, _control
    // characteristic 이 stale (이전 세션 dead instance) 인 채로 남고
    // write 가 silently no-op 됨. 사용자는 "훈련하기" 를 눌러도 디바이스가
    // 반응 안 하는 증상으로 경험. 따라서 resume 시:
    //
    //   1) bleManager.ensureConnected() — 실제 연결 상태 검증, stale 한
    //      경우 reconnect + service rediscover + characteristic 재바인딩.
    //   2) autoReconnectProvider invalidate — manager 가 device 정보를
    //      잃었거나 scan 이 필요한 경우 (e.g. 디바이스 cold reboot) 의
    //      fallback 경로.
    if (state == AppLifecycleState.paused) {
      // ─────────────────────────────────────────────────────────────────
      // CRITICAL — App 이 background 로 갈 때 명시적 disconnect.
      //
      // Android 가 background 진입 시 BLE GATT 연결을 silently drop 하는 경우
      // 가 있음. 그러면 펌웨어는 L2CAP_DISCONNECT 패킷을 못 받아서 자신을
      // "여전히 연결 중" 으로 인식 → advertising 재시작 안 함 → 앱이 resume
      // 후 reconnect 시도해도 scan 결과 0 → 사용자 stuck.
      //
      // 명시적 disconnect 호출 = 정상적인 L2CAP_DISCONNECT 전송 → 펌웨어의
      // onDisconnect callback 발동 → advertising 재시작 → resume 시 정상
      // 재연결 가능.
      // ─────────────────────────────────────────────────────────────────
      debugPrint('[ble] app paused — graceful disconnect');
      () async {
        try {
          await ref.read(bleManagerProvider).disconnect();
        } catch (e) {
          debugPrint('[ble] paused disconnect threw: $e');
        }
      }();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('[ble] app resumed — re-running autoReconnect');
      // paused 시 disconnect 했으므로 resume 시엔 cold start 와 동일한
      // 흐름으로 재연결. autoReconnect 가 adopt 시도 후 scan + connect 수행.
      ref.invalidate(autoReconnectProvider);
      ref.read(autoReconnectProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wire BLE session summaries into the local DB for the lifetime of the app.
    ref.watch(sessionPersistenceProvider);
    // 연결될 때마다 캐시된 목표 압력대를 펌웨어로 재전송 (펌웨어 reboot 시 default
    // 로 리셋되는 문제 해결).
    ref.watch(targetSyncProvider);
    // 앱 시작 시 마지막 연결한 device 자동 재연결 시도 (silent fallback).
    ref.watch(autoReconnectProvider);
    // 사용자 토글로 변경되는 light/dark 모드.
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'BRELOW',
      theme: BlowfitTheme.light(),
      darkTheme: BlowfitTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

// 테마 정의는 core/theme/blowfit_theme.dart 로 이전됨.
