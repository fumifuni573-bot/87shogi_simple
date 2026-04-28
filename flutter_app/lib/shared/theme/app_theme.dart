import 'package:flutter/material.dart';

import 'app_palette.dart';

class AppTheme {
  static ThemeData light() {
    const ink = Color(0xFF1F1A17);
    const paper = AppPalette.bgBottom;
    const accent = AppPalette.info;
    const secondary = AppPalette.warning;

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      primary: accent,
      secondary: secondary,
      surface: paper,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.bgTop,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppPalette.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x1FD12E78)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.info,
          foregroundColor: Colors.white,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.45,
          color: ink,
        ),
      ),
    );
  }
}