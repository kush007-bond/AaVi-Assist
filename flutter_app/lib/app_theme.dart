import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design system color tokens from VisionAid DESIGN.md
class AppColors {
  static const background = Color(0xFFF9F9FF);
  static const surface = Color(0xFFF9F9FF);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF2F3FB);
  static const surfaceContainer = Color(0xFFECEDF6);
  static const surfaceContainerHigh = Color(0xFFE7E8F0);
  static const surfaceContainerHighest = Color(0xFFE1E2EA);
  static const surfaceDim = Color(0xFFD8DAE2);
  static const surfaceVariant = Color(0xFFE1E2EA);

  static const onSurface = Color(0xFF191C21);
  static const onSurfaceVariant = Color(0xFF424752);

  static const primary = Color(0xFF004D99);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF1565C0);
  static const onPrimaryContainer = Color(0xFFDAE5FF);
  static const primaryFixed = Color(0xFFD6E3FF);
  static const primaryFixedDim = Color(0xFFA9C7FF);
  static const onPrimaryFixed = Color(0xFF001B3D);

  static const secondary = Color(0xFF00629D);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFF4FAFFF);

  static const tertiary = Color(0xFF134AA4);
  static const tertiaryContainer = Color(0xFF3563BE);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);

  static const outline = Color(0xFF727783);
  static const outlineVariant = Color(0xFFC2C6D4);

  static const inverseSurface = Color(0xFF2E3037);
  static const inverseOnSurface = Color(0xFFEFF0F9);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryContainer,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryFixed,
      onPrimaryContainer: AppColors.onPrimaryFixed,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      error: AppColors.error,
      onError: AppColors.onError,
      outline: AppColors.outline,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surfaceContainerLowest,
      foregroundColor: AppColors.primaryContainer,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.publicSans(
        fontWeight: FontWeight.w900,
        fontSize: 20,
        letterSpacing: -0.2,
        color: AppColors.primaryContainer,
      ),
    ),
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.publicSans(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: AppColors.onSurface,
      ),
      headlineMedium: GoogleFonts.publicSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.32,
        color: AppColors.onSurface,
      ),
      headlineSmall: GoogleFonts.publicSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      bodyLarge: GoogleFonts.lexend(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: AppColors.onSurface,
      ),
      bodyMedium: GoogleFonts.lexend(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.18,
        color: AppColors.onSurface,
      ),
      labelLarge: GoogleFonts.lexend(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppColors.onSurface,
      ),
      labelSmall: GoogleFonts.lexend(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.28,
        color: AppColors.onSurfaceVariant,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryContainer, width: 3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size(44, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.lexend(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryContainer,
        side: const BorderSide(color: AppColors.primaryContainer, width: 2),
        minimumSize: const Size(44, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.lexend(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    ),
  );
}
