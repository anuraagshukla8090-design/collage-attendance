import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const canvas = Color(0xFFF6F0E7);
  static const surface = Color(0xFFFFFBF5);
  static const ink = Color(0xFF261C1E);
  static const muted = Color(0xFF756A66);
  static const plum = Color(0xFF4A2932);
  static const plumDark = Color(0xFF351C23);
  static const coral = Color(0xFFE5A987);
  static const coralSoft = Color(0xFFF2D4BE);
  static const peach = Color(0xFFF7DFC7);
  static const border = Color(0xFFDDD2C7);
  static const success = Color(0xFF356A51);
  static const error = Color(0xFF9E3D3D);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppPalette.plum,
    brightness: Brightness.light,
    primary: AppPalette.plum,
    secondary: AppPalette.coral,
    surface: AppPalette.surface,
    error: AppPalette.error,
  );
  const radius = BorderRadius.all(Radius.circular(22));
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: scheme,
    scaffoldBackgroundColor: AppPalette.canvas,
    dividerColor: AppPalette.border,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.canvas,
      foregroundColor: AppPalette.ink,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: AppPalette.ink,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppPalette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppPalette.border),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppPalette.surface,
      labelStyle: TextStyle(color: AppPalette.muted),
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppPalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppPalette.plum, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: AppPalette.plum,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppPalette.border,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: .2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: AppPalette.plum,
        side: const BorderSide(color: AppPalette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppPalette.plum,
        textStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700),
      ),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(color: AppPalette.ink, fontWeight: FontWeight.w900),
      headlineLarge: TextStyle(color: AppPalette.ink, fontWeight: FontWeight.w900, letterSpacing: -1),
      headlineMedium: TextStyle(color: AppPalette.ink, fontWeight: FontWeight.w900, letterSpacing: -.7),
      headlineSmall: TextStyle(color: AppPalette.ink, fontWeight: FontWeight.w900, letterSpacing: -.4),
      titleLarge: TextStyle(color: AppPalette.ink, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(color: AppPalette.ink, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(color: AppPalette.ink, height: 1.45),
      bodyMedium: TextStyle(color: AppPalette.ink, height: 1.4),
      bodySmall: TextStyle(color: AppPalette.muted, height: 1.35),
      labelLarge: TextStyle(color: AppPalette.ink, fontWeight: FontWeight.w800),
      labelMedium: TextStyle(color: AppPalette.muted, fontWeight: FontWeight.w700),
    ),
  );
}
