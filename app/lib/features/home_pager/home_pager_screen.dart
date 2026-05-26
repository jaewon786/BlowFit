// 홈과 추이 화면을 가로 swipe 로 전환할 수 있는 페이지 컨테이너.
//
// Figma 디자인의 페이지 indicator dots 가 1=홈, 2=추이 를 의미하므로 단순히
// PageView 로 두 화면을 묶음. 각 화면의 dot 표시는 그 화면 안에 그려져 있어서
// swipe 시 dot 색깔도 자연스럽게 전환됨.
//
// trend 라우트 ('/trend') 는 유지 — 알림/노티 같은 다른 진입점에서 직접 navigate
// 할 때 사용 가능.

import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';
import '../trend/trend_screen.dart';

class HomePagerScreen extends StatefulWidget {
  const HomePagerScreen({super.key});
  @override
  State<HomePagerScreen> createState() => _HomePagerScreenState();
}

class _HomePagerScreenState extends State<HomePagerScreen> {
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      children: const [
        DashboardScreen(),
        TrendScreen(),
      ],
    );
  }
}
