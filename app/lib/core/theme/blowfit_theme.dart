import 'package:flutter/material.dart';

import 'blowfit_colors.dart';

/// BlowFit 글로벌 ThemeData. main.dart 에서 build 시 한 번 호출.
///
/// 디자인 토큰 (BlowfitColors) 을 Material 3 ThemeData 로 매핑한다. 각 화면은
/// 직접 색을 박지 말고 Theme.of(context) 또는 BlowfitColors.* 를 참조.
class BlowfitTheme {
  BlowfitTheme._();

  /// Pretendard 가 자산으로 등록되어 있으면 사용, 없으면 시스템 폰트 fallback.
  /// (pubspec.yaml 의 fonts 섹션에서 등록 — 추후 작업.)
  static const fontFamily = 'Pretendard';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: BlowfitColors.blue500,
      brightness: Brightness.light,
      primary: BlowfitColors.blue500,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: BlowfitColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      // Pretendard 자산 미등록 상태에선 system font 로 fallback 됨.
      fontFamily: fontFamily,
      scaffoldBackgroundColor: BlowfitColors.bg,
      cardTheme: CardThemeData(
        color: BlowfitColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BlowfitRadius.xl),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BlowfitColors.bg,
        foregroundColor: BlowfitColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: BlowfitColors.ink,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.34, // -0.02em @ 17px
          fontFamily: fontFamily,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        height: 64,
        indicatorColor: Colors.transparent, // 디자인은 색상 변화로만 표시
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: selected ? BlowfitColors.blue500 : BlowfitColors.gray500,
            fontFamily: fontFamily,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? BlowfitColors.blue500 : BlowfitColors.gray500,
            size: 24,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BlowfitColors.blue500,
          foregroundColor: Colors.white,
          disabledBackgroundColor: BlowfitColors.gray200,
          disabledForegroundColor: BlowfitColors.gray400,
          minimumSize: const Size(0, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.17, // -0.01em
            fontFamily: fontFamily,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BlowfitColors.blue500,
          backgroundColor: Colors.white,
          minimumSize: const Size(0, 56),
          side: const BorderSide(color: BlowfitColors.blue500, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BlowfitColors.blue500,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),
      // 카드/리스트 안에서 쓰는 텍스트 hierarchy.
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: BlowfitColors.ink,
          letterSpacing: -1.02,
          fontFamily: fontFamily,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: BlowfitColors.ink,
          letterSpacing: -0.72,
          fontFamily: fontFamily,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: BlowfitColors.ink,
          letterSpacing: -0.4,
          fontFamily: fontFamily,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: BlowfitColors.ink,
          letterSpacing: -0.34,
          fontFamily: fontFamily,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: BlowfitColors.ink,
          fontFamily: fontFamily,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: BlowfitColors.ink,
          fontFamily: fontFamily,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: BlowfitColors.ink2,
          fontFamily: fontFamily,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: BlowfitColors.ink3,
          fontFamily: fontFamily,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: BlowfitColors.ink2,
          fontFamily: fontFamily,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: BlowfitColors.ink3,
          fontFamily: fontFamily,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: BlowfitColors.gray700,
        textColor: BlowfitColors.ink,
        tileColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(
        color: BlowfitColors.gray150,
        space: 1,
        thickness: 1,
      ),
      // 토스트/스낵바도 새 토큰에 맞춤.
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: BlowfitColors.gray900,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}
