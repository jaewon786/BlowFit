import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-nav scaffold for the 4 main tabs (홈 / 기록 / 추이 / 프로필).
///
/// Phase 2 디자인 변경: 가이드/설정 탭 제거, 추이/프로필 추가. 가이드는
/// 온보딩 흐름 안에서만 노출하고, 설정은 프로필 화면 내부의 리스트로 흡수.
///
/// Connect, Training, SessionDetail, TargetSettings 는 이 shell 바깥의
/// top-level 라우트로 push 되어 하단 탭바를 가린다.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          // Tap on the already-selected tab pops to its initial location.
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: '기록',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: '추이',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '프로필',
          ),
        ],
      ),
    );
  }
}
