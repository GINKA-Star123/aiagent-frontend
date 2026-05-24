import 'package:flutter/material.dart';

class AppTheme {
  static const Color seedColor = Color(0xFFC74444);
  static const Color pageBackground = Color(0xFFFFFBF8);

  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: pageBackground,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(44, 42)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(44, 42)),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
