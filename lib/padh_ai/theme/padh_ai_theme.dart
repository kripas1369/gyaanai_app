import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// PadhAI design tokens (Material 3 + Mukta for Devanagari).
class PadhAiColors {
  static const primary = Color(0xFF1B5E20);
  static const secondary = Color(0xFF388E3C);
  static const accent = Color(0xFFF9A825);
  static const background = Color(0xFFFAFAFA);
  static const bubbleUser = Color(0xFFE3F2FD);
  static const bubbleAi = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
}

ThemeData padhAiLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: PadhAiColors.primary,
      primary: PadhAiColors.primary,
      secondary: PadhAiColors.secondary,
      tertiary: PadhAiColors.accent,
      surface: PadhAiColors.background,
    ),
    scaffoldBackgroundColor: PadhAiColors.background,
  );
  return base.copyWith(
    textTheme: GoogleFonts.muktaTextTheme(base.textTheme).apply(
      bodyColor: PadhAiColors.textPrimary,
      displayColor: PadhAiColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: PadhAiColors.background,
      foregroundColor: PadhAiColors.textPrimary,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

ThemeData padhAiDarkTheme() {
  final dark = ThemeData.dark(useMaterial3: true);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: PadhAiColors.secondary,
      brightness: Brightness.dark,
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.muktaTextTheme(dark.textTheme),
    scaffoldBackgroundColor: base.colorScheme.surface,
  );
}
