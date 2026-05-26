import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Figma DoT 디자인 v2 — 하단 NavigationBar 없음.
///
/// 시안 (1:2060 홈 / 1:2261 홈 다크 / 1:2128 추이 / 1:2236 훈련) 어느 화면에도
/// 하단 탭바가 없어 MainShell 은 단순 pass-through 로만 동작. 화면 사이의
/// 이동은 page indicator + swipe (추후) 또는 상단 액션 버튼으로만 처리.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return navigationShell;
  }
}
