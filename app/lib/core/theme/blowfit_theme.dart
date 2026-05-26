import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'blowfit_colors.dart';

/// 사용자 토글로 변경되는 ThemeMode — Home 화면의 라이트/다크 토글이 이를
/// 변경한다. SharedPreferences 에 영속화해서 재실행 시 복원.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.light) {
    _load();
  }

  static const _key = 'theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == 'dark') {
      state = ThemeMode.dark;
    } else if (stored == 'light') {
      state = ThemeMode.light;
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> toggle() async {
    await set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);

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

  /// 다크 테마 — Figma DoT 다크 모드 시안 (#060725 배경) 기반.
  ///
  /// 라이트 테마와 동일한 텍스트 hierarchy/버튼 스타일을 유지하되 색상만
  /// 다크 팔레트로 교체. 화면 구현은 Theme.of(context).brightness 로 분기.
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: DotColors.primary,
      brightness: Brightness.dark,
      primary: DotColors.primary,
      onPrimary: Colors.white,
      surface: DotColors.darkCard,
      onSurface: DotColors.darkTextPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: DotColors.darkBg,
      cardTheme: CardThemeData(
        color: DotColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BlowfitRadius.xl),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DotColors.darkBg,
        foregroundColor: DotColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: DotColors.darkTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.34,
          fontFamily: fontFamily,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DotColors.darkCard,
        surfaceTintColor: Colors.transparent,
        height: 64,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: selected ? DotColors.primary : DotColors.darkTextMuted,
            fontFamily: fontFamily,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? DotColors.primary : DotColors.darkTextMuted,
            size: 24,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DotColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: DotColors.darkCardSoft,
          disabledForegroundColor: DotColors.darkTextMuted,
          minimumSize: const Size(0, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.17,
            fontFamily: fontFamily,
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: DotColors.darkTextPrimary,
          letterSpacing: -1.02,
          fontFamily: fontFamily,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: DotColors.darkTextPrimary,
          letterSpacing: -0.72,
          fontFamily: fontFamily,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: DotColors.darkTextPrimary,
          letterSpacing: -0.4,
          fontFamily: fontFamily,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: DotColors.darkTextPrimary,
          letterSpacing: -0.34,
          fontFamily: fontFamily,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: DotColors.darkTextPrimary,
          fontFamily: fontFamily,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: DotColors.darkTextPrimary,
          fontFamily: fontFamily,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: DotColors.darkTextSecondary,
          fontFamily: fontFamily,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: DotColors.darkTextMuted,
          fontFamily: fontFamily,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: DotColors.darkTextSecondary,
          fontFamily: fontFamily,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: DotColors.darkTextMuted,
          fontFamily: fontFamily,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: DotColors.darkTextSecondary,
        textColor: DotColors.darkTextPrimary,
        tileColor: DotColors.darkCard,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2C40),
        space: 1,
        thickness: 1,
      ),
    );
  }
}
