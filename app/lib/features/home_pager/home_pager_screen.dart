// 홈 · 추이 · 수면 추이 화면을 가로 swipe 로 전환하는 페이지 컨테이너.
//
// Figma 디자인의 페이지 indicator dots(1=홈, 2=추이, 3=수면 추이)는 각 화면 안에
// 그려져 있어 swipe 시 dot 색깔도 자연스럽게 전환됨.
//
// 시스템(갤럭시) 뒤로가기: 네이티브 MainActivity.onBackPressed → MethodChannel
// 'blowfit/system_back' 의 'onBack' → 여기서 결정.
//   1) 루트/브랜치에 push 된 라우트 있으면 pop, 2) 추이/수면 sub-page 면 홈 복귀,
//   3) 홈 루트면 "앱 종료?" 다이얼로그 → 종료 시 네이티브 finishAffinity.
// (go_router StatefulShellRoute + 예측형 뒤로가기에서 Dart PopScope/observer 가
//  루트 백을 못 잡는 문제를 네이티브 위임으로 우회.)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../dashboard/dashboard_screen.dart';
import '../sleep/sleep_trend_screen.dart';
import '../trend/trend_screen.dart';

class HomePagerScreen extends StatefulWidget {
  const HomePagerScreen({super.key});
  @override
  State<HomePagerScreen> createState() => _HomePagerScreenState();
}

class _HomePagerScreenState extends State<HomePagerScreen> {
  static const _backChannel = MethodChannel('blowfit/system_back');
  final PageController _controller = PageController();

  @override
  void initState() {
    super.initState();
    _backChannel.setMethodCallHandler(_onNativeCall);
  }

  @override
  void dispose() {
    _backChannel.setMethodCallHandler(null);
    _controller.dispose();
    super.dispose();
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'onBack') {
      await _handleBack();
    }
    return null;
  }

  Future<void> _handleBack() async {
    if (!mounted) return;
    // 1) 루트 네비게이터에 push 된 라우트(설정/다이얼로그 등) → pop.
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) {
      rootNav.maybePop();
      return;
    }
    // 2) go_router(브랜치) 가 pop 가능 → pop.
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    // 3) 추이/수면 sub-page → 홈으로 복귀.
    final page = _controller.hasClients ? (_controller.page ?? 0).round() : 0;
    if (page != 0) {
      _controller.animateToPage(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
      return;
    }
    // 4) 홈 루트 → 종료 확인.
    await _confirmExit();
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('앱 종료'),
        content: const Text('앱을 종료하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('종료'),
          ),
        ],
      ),
    );
    if (shouldExit ?? false) {
      await _backChannel.invokeMethod('exitApp');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      // 각 페이지를 keepAlive — 화면 밖으로 나가도 dispose 되지 않게.
      // (홈을 떠났다 돌아올 때 캐릭터 패널이 재생성되며 진화를 재평가/재실행하던
      //  버그 방지 + 스크롤/달력 등 페이지 상태 보존.)
      children: const [
        _KeepAlivePage(child: DashboardScreen()),
        _KeepAlivePage(child: TrendScreen()),
        _KeepAlivePage(child: SleepTrendScreen()),
      ],
    );
  }
}

/// PageView 자식을 화면 밖에서도 살아있게 유지하는 래퍼.
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});
  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수 호출.
    return widget.child;
  }
}
