import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.violet,
        brightness: Brightness.dark,
        primary: AppColors.turquoise,
        secondary: AppColors.violet,
        surface: AppColors.indigo,
      ),
      scaffoldBackgroundColor: AppColors.navy,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.deepPurple,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.turquoiseDark
              : AppColors.textDim,
        ),
      ),
    );
  }
}

/// Text styles with a soft drop shadow for a "game" feel.
abstract final class AppText {
  static const _shadow = [
    Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 3),
  ];

  static const title = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w900,
    color: AppColors.text,
    letterSpacing: 0.5,
    shadows: _shadow,
  );
  static const heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: AppColors.text,
    shadows: _shadow,
  );
  static const button = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
    shadows: _shadow,
  );
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
  );
  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
  );
}

/// Shared sizes so icons and header buttons look the same on every screen.
abstract final class AppSizes {
  /// Round buttons in screen headers / top bars.
  static const headerButton = 46.0;

  /// Inline icon sizes.
  static const iconSm = 18.0;
  static const iconMd = 24.0;
  static const iconLg = 30.0;

  /// Smallest text size used anywhere (readability).
  static const minText = 12.0;
}
