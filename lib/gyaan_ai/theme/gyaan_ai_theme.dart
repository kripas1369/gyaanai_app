import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// GyaanAi design tokens — Material 3 + Mukta for Devanagari.
class GyaanAiColors {
  // Brand
  static const primary = Color(0xFF1B5E20);
  static const primaryLight = Color(0xFF2E7D32);
  static const secondary = Color(0xFF388E3C);
  static const accent = Color(0xFFF9A825);
  static const accentDark = Color(0xFFE65100);

  // Surfaces
  static const background = Color(0xFFF5F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF0F4F0);

  // Chat bubbles
  static const bubbleUser = Color(0xFFDCF8C6);
  static const bubbleUserBorder = Color(0xFFB2DFDB);
  static const bubbleAi = Color(0xFFFFFFFF);

  // Text
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFF9CA3AF);

  // Status
  static const online = Color(0xFF22C55E);
  static const offline = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  // Gradients
  static const gradientPrimary = LinearGradient(
    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientHero = LinearGradient(
    colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const gradientGeneral = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Reusable shadow presets.
class GyaanAiShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> coloredShadow(Color color, {double alpha = 0.25}) => [
        BoxShadow(
          color: color.withValues(alpha: alpha),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ];
}

/// Spacing constants.
class GyaanAiSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const radius = 16.0;
  static const radiusSm = 10.0;
  static const radiusLg = 24.0;
  static const radiusFull = 999.0;
}

ThemeData gyaanAiLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: GyaanAiColors.primary,
      primary: GyaanAiColors.primary,
      secondary: GyaanAiColors.secondary,
      tertiary: GyaanAiColors.accent,
      surface: GyaanAiColors.surface,
      surfaceContainerHighest: GyaanAiColors.surfaceVariant,
    ),
    scaffoldBackgroundColor: GyaanAiColors.background,
  );

  return base.copyWith(
    textTheme: GoogleFonts.muktaTextTheme(base.textTheme).apply(
      bodyColor: GyaanAiColors.textPrimary,
      displayColor: GyaanAiColors.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: GyaanAiColors.surface,
      foregroundColor: GyaanAiColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.mukta(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: GyaanAiColors.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: GyaanAiColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GyaanAiSpacing.radius),
        side: BorderSide(
          color: Colors.black.withValues(alpha: 0.06),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: GyaanAiColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GyaanAiSpacing.radius),
        ),
        textStyle: GoogleFonts.mukta(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: GyaanAiColors.primary,
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: GyaanAiColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GyaanAiSpacing.radius),
        ),
        textStyle: GoogleFonts.mukta(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GyaanAiColors.surfaceVariant,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GyaanAiSpacing.radius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GyaanAiSpacing.radius),
        borderSide:
            BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GyaanAiSpacing.radius),
        borderSide: const BorderSide(
            color: GyaanAiColors.secondary, width: 1.5),
      ),
      hintStyle: GoogleFonts.mukta(
        color: GyaanAiColors.textHint,
        fontSize: 15,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.black.withValues(alpha: 0.06),
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: GyaanAiColors.textPrimary,
      contentTextStyle: GoogleFonts.mukta(
        color: Colors.white,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GyaanAiSpacing.radiusSm),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

ThemeData gyaanAiDarkTheme() {
  final dark = ThemeData.dark(useMaterial3: true);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: GyaanAiColors.secondary,
      brightness: Brightness.dark,
      surface: const Color(0xFF121212),
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.muktaTextTheme(dark.textTheme),
    scaffoldBackgroundColor: const Color(0xFF0F0F0F),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1A1A),
      elevation: 0,
      centerTitle: false,
    ),
  );
}
