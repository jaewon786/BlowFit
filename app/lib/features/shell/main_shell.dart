import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Figma DoT 디자인 v2 — 하단 NavigationBar 없음. 단순 pass-through.
/// 시스템 뒤로가기는 네이티브(onBackPressed) → MethodChannel → HomePagerScreen
/// 에서 처리한다.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return navigationShell;
  }
}
