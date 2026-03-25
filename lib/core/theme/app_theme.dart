import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

/// Glow / shadow helpers for the design system.
class NeonColors {
  static List<BoxShadow> glow(Color color, {double intensity = 1.0}) => [
        BoxShadow(
          color: color.withValues(alpha: 0.32 * intensity),
          blurRadius: 20,
          spreadRadius: -2,
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.12 * intensity),
          blurRadius: 44,
          spreadRadius: -6,
        ),
      ];

  static List<BoxShadow> softGlow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.22),
          blurRadius: 18,
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> crystalCard() => [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.025),
          blurRadius: 30,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> lightCard() => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 22,
          offset: const Offset(0, 5),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ];
}

class AppTheme {
  // ── Dark palette ───────────────────────────────────────────────
  static const Color _darkBg      = Color(0xFF06060F);
  static const Color _darkSurface = Color(0xFF0C0C1A);
  static const Color _darkCard    = Color(0xFF0E0E1C);
  static const Color _darkBorder  = Color(0x0FFFFFFF);
  static const Color _darkText    = Color(0xFFF0F0FF);
  static const Color _darkTextSub = Color(0xFF484862);

  // ── Light palette ──────────────────────────────────────────────
  static const Color _lightBg      = Color(0xFFF3F4FF);
  static const Color _lightCard    = Color(0xFFFFFFFF);
  static const Color _lightBorder  = Color(0x0C000000);
  static const Color _lightText    = Color(0xFF080818);
  static const Color _lightTextSub = Color(0xFF9898B8);

  // ──────────────────────────────────────────────────────────────
  static TextTheme _textTheme(Color text, Color sub) {
    return GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displaySmall:   GoogleFonts.plusJakartaSans(fontSize: 30, fontWeight: FontWeight.w800, color: text, letterSpacing: -1.0),
      headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: text, letterSpacing: -0.5),
      headlineSmall:  GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: text, letterSpacing: -0.3),
      titleLarge:     GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: text),
      titleMedium:    GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: text),
      bodyLarge:      GoogleFonts.plusJakartaSans(fontSize: 15, color: text.withValues(alpha: 0.75)),
      bodyMedium:     GoogleFonts.plusJakartaSans(fontSize: 13, color: sub),
      labelSmall:     GoogleFonts.plusJakartaSans(fontSize: 10, color: sub, letterSpacing: 0.9, fontWeight: FontWeight.w600),
    );
  }

  // ──────────────────────────────────────────────────────────────
  static ThemeData lightTheme(Color accent) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        surface: _lightCard,
        primary: accent,
      ),
      scaffoldBackgroundColor: _lightBg,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: _lightBorder, width: 1),
        ),
        color: _lightCard,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: _lightBg,
        foregroundColor: _lightText,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w700, color: _lightText, letterSpacing: -0.3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: GoogleFonts.plusJakartaSans(color: _lightTextSub, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0x09000000), thickness: 1, space: 0),
      textTheme: _textTheme(_lightText, _lightTextSub),
    );
  }

  // ──────────────────────────────────────────────────────────────
  static ThemeData darkTheme(Color accent) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: _darkSurface,
        primary: accent,
        onPrimary: Colors.white,
        onSurface: _darkText,
      ),
      scaffoldBackgroundColor: _darkBg,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: _darkBorder, width: 1),
        ),
        color: _darkCard,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: _darkBg,
        foregroundColor: _darkText,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w700, color: _darkText, letterSpacing: -0.3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: GoogleFonts.plusJakartaSans(color: _darkTextSub, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0x0AFFFFFF), thickness: 1, space: 0),
      textTheme: _textTheme(_darkText, _darkTextSub),
    );
  }

  static Color accentFromKey(String key) {
    return AppConstants.accentColors[key] ?? AppConstants.accentColors['blue']!;
  }
}
