import 'package:flutter/material.dart';

/// BlowFit design token — Wanted DS 기반.
///
/// HTML 디자인 시안의 `--bf-*` CSS 변수를 1:1 로 옮긴 색상 팔레트. 모든 화면은
/// 이 클래스의 상수만 참조해서 색을 일관되게 적용한다.
class BlowfitColors {
  BlowfitColors._();

  // ---- Brand ----
  static const blue50 = Color(0xFFEBF2FF);
  static const blue100 = Color(0xFFD6E4FF);
  static const blue200 = Color(0xFFADC8FF);
  static const blue300 = Color(0xFF84A9FF);
  static const blue400 = Color(0xFF5C8CFF);
  static const blue500 = Color(0xFF0066FF); // primary
  static const blue600 = Color(0xFF0052CC);
  static const blue700 = Color(0xFF003D99);

  // ---- Semantic ----
  static const green500 = Color(0xFF00BF40);
  static const green100 = Color(0xFFE0F7E6);
  static const greenInk = Color(0xFF006B25); // chip-green text
  static const amber500 = Color(0xFFFFA800);
  static const amberBg = Color(0xFFFFF3DA); // chip-amber bg
  static const amberInk = Color(0xFF8A5A00);
  static const red500 = Color(0xFFFF3B30);
  static const red100 = Color(0xFFFFE5E3);
  static const redInk = Color(0xFFB42318);

  // ---- Neutral ----
  static const gray900 = Color(0xFF111111);
  static const gray800 = Color(0xFF1F1F1F);
  static const gray700 = Color(0xFF333333);
  static const gray600 = Color(0xFF555555);
  static const gray500 = Color(0xFF767676);
  static const gray400 = Color(0xFFA1A1A1);
  static const gray300 = Color(0xFFC4C4C4);
  static const gray200 = Color(0xFFE5E5E5);
  static const gray150 = Color(0xFFEEEEEE);
  static const gray100 = Color(0xFFF5F5F5);
  static const gray50 = Color(0xFFFAFAFA);

  // ---- Surfaces ----
  static const bg = Color(0xFFF5F6F8); // scaffold background
  static const card = Colors.white;
  static const ink = Color(0xFF111111); // primary text
  static const ink2 = Color(0xFF4B5563); // secondary text
  static const ink3 = Color(0xFF6B7280); // tertiary text / hint

  // ---- Shadows ----
  // sh-1: 카드 기본
  static const shadowLevel1 = [
    BoxShadow(
      color: Color.fromRGBO(17, 24, 39, 0.06),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color.fromRGBO(17, 24, 39, 0.04),
      blurRadius: 1,
      offset: Offset(0, 1),
    ),
  ];

  // sh-2: 강조 카드 / 모달
  static const shadowLevel2 = [
    BoxShadow(
      color: Color.fromRGBO(17, 24, 39, 0.08),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  // sh-3: floating CTA / dialog
  static const shadowLevel3 = [
    BoxShadow(
      color: Color.fromRGBO(17, 24, 39, 0.12),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];
}

/// 카드/버튼/슬라이더 등의 표준 radius.
class BlowfitRadius {
  BlowfitRadius._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

/// Figma DoT 디자인 시안 색상 토큰 — Home/추이/훈련 화면에서 직접 참조.
///
/// 라이트/다크 mode 모두 같은 primary/green 을 쓰지만 배경/표면/텍스트만 다름.
/// 화면 위젯은 `Theme.of(context).brightness` 로 분기하거나, ConsumerWidget 에서
/// themeMode provider 를 watch 해서 분기.
class DotColors {
  DotColors._();

  // ---- Brand (라이트/다크 공용) ----
  static const primary = Color(0xFF0A89FC);   // progress bar, dot, exhale chart
  static const primaryAlt = Color(0xFF0086FF); // 0% 텍스트 (다크)
  static const inhale = Color(0xFF32B65E);     // 흡기 차트 dot
  static const sunday = Color(0xFFFF0000);    // 캘린더 일요일 (red)
  static const saturday = Color(0xFF0088FF);  // 캘린더 토요일 (blue)

  // ---- Light mode ----
  // 홈 화면 배경 그라데이션 (156.78°): #99EBFC → #DBF9FF
  static const lightBgTop = Color(0xFF99EBFC);
  static const lightBgBottom = Color(0xFFDBF9FF);
  // 훈련 화면 배경 그라데이션 (조금 더 다단계): #DFF9FF → #C6F5FF → #8DE9FD
  static const lightTrainBg1 = Color(0xFFDFF9FF);
  static const lightTrainBg2 = Color(0xFFC6F5FF);
  static const lightTrainBg3 = Color(0xFF8DE9FD);
  // 표면 (라이트)
  static const lightCard = Color(0xFFFFFFFF);
  static const lightCardSoft = Color(0xFFF1F6FA);   // 카드 안의 sub 카드
  static const lightTrack = Color(0xFFE7EBF6);      // 진행 트랙
  // 텍스트 (라이트)
  static const lightTextPrimary = Color(0xFF101010);
  static const lightTextSecondary = Color(0xFF252525);
  static const lightTextMuted = Color(0xFF898989);
  static const lightCalendarGray = Color(0xFF808080);
  // CTA pill (훈련하기 버튼)
  static const lightCtaBg = Color(0xFF000000);
  static const lightCtaFg = Color(0xFFFFFFFF);

  // ---- Dark mode ----
  static const darkBg = Color(0xFF060725);         // scaffold 배경
  static const darkCard = Color(0xFF04040D);       // 메인 카드 (오늘 총 몇 번)
  static const darkCardSoft = Color(0xFF1C1C1E);   // 카드 안의 sub 카드
  static const darkTrack = Color(0xB3424242);      // 진행 트랙 (70% opacity)
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFFE0E0E0);
  static const darkTextMuted = Color(0xFF8E8E93);

  // ---- 캐릭터 (mascot) — 추후 SVG/PNG 자산 등록 후 교체 ----
  // 잠시 그라데이션 원형 placeholder 로 표시. assets/character/dot_mascot.png
  // 추가되면 Image.asset 으로 교체.
  static const mascotBlue = Color(0xFF5B7CFA);
  static const mascotBlueDark = Color(0xFF3D5BCC);
  static const mascotCheek = Color(0xFFFF6B9D);

  // ---- Light mode 의 하단 잔디 영역 (홈 화면) ----
  static const lightGrass1 = Color(0xFFAFE89B);
  static const lightGrass2 = Color(0xFF8FD97A);
  // ---- Dark mode 의 하단 물결 (홈 화면) ----
  static const darkWave1 = Color(0xFF1B1D4A);
  static const darkWave2 = Color(0xFF14163A);
}
