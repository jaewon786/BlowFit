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
