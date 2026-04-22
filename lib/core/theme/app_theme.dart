import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

@immutable
class MinimalTheme extends ThemeExtension<MinimalTheme> {
  final Color bg;
  final Color surface;
  final Color border;
  final Color text;
  final Color textSub;
  final Color accent;
  final double radius;
  final double padding;

  const MinimalTheme({
    required this.bg,
    required this.surface,
    required this.border,
    required this.text,
    required this.textSub,
    required this.accent,
    this.radius = 16,
    this.padding = 16,
  });

  const MinimalTheme.light(Color accent)
      : this(
          bg: const Color(0xFFFFFFFF),
          surface: const Color(0xFFF9F9FB),
          border: const Color(0xFFE8E8E8),
          text: const Color(0xFF0F0F10),
          textSub: const Color(0xFF4A4A55),
          accent: accent,
        );

  const MinimalTheme.dark(Color accent)
      : this(
          bg: const Color(0xFF0D0D0F),
          surface: const Color(0xFF121219),
          border: const Color(0xFF1C1C21),
          text: const Color(0xFFF7F7FA),
          textSub: const Color(0xFF8B8BA0),
          accent: accent,
        );

  @override
  MinimalTheme copyWith({
    Color? bg,
    Color? surface,
    Color? border,
    Color? text,
    Color? textSub,
    Color? accent,
    double? radius,
    double? padding,
  }) {
    return MinimalTheme(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      text: text ?? this.text,
      textSub: textSub ?? this.textSub,
      accent: accent ?? this.accent,
      radius: radius ?? this.radius,
      padding: padding ?? this.padding,
    );
  }

  @override
  MinimalTheme lerp(ThemeExtension<MinimalTheme>? other, double t) {
    if (other is! MinimalTheme) return this;
    return MinimalTheme(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSub: Color.lerp(textSub, other.textSub, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      radius: lerpDouble(radius, other.radius, t)!,
      padding: lerpDouble(padding, other.padding, t)!,
    );
  }
}

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
    final tokens = MinimalTheme.light(accent);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        surface: tokens.surface,
        primary: accent,
      ),
      scaffoldBackgroundColor: tokens.bg,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius + 2),
          side: BorderSide(color: tokens.border, width: 1),
        ),
        color: tokens.surface,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: tokens.bg,
        foregroundColor: tokens.text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w700, color: tokens.text, letterSpacing: -0.3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radius - 2),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radius - 2),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radius - 2),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: tokens.padding + 2, vertical: tokens.padding),
        hintStyle: GoogleFonts.plusJakartaSans(color: tokens.textSub, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: tokens.padding + 12, vertical: tokens.padding - 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radius - 2)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.border.withValues(alpha: 0.5), thickness: 1, space: 0),
      textTheme: _textTheme(tokens.text, tokens.textSub),
      extensions: [tokens],
    );
  }

  // ──────────────────────────────────────────────────────────────
  static ThemeData darkTheme(Color accent) {
    final tokens = MinimalTheme.dark(accent);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: tokens.surface,
        primary: accent,
        onPrimary: Colors.white,
        onSurface: tokens.text,
      ),
      scaffoldBackgroundColor: tokens.bg,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius + 2),
          side: BorderSide(color: tokens.border, width: 1),
        ),
        color: tokens.surface,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: tokens.bg,
        foregroundColor: tokens.text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w700, color: tokens.text, letterSpacing: -0.3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radius - 2),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radius - 2),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radius - 2),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: tokens.padding + 2, vertical: tokens.padding),
        hintStyle: GoogleFonts.plusJakartaSans(color: tokens.textSub, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: tokens.padding + 12, vertical: tokens.padding - 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radius - 2)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.border.withValues(alpha: 0.5), thickness: 1, space: 0),
      textTheme: _textTheme(tokens.text, tokens.textSub),
      extensions: [tokens],
    );
  }

  static Color accentFromKey(String key) {
    return AppConstants.accentColors[key] ?? AppConstants.accentColors['blue']!;
  }
}
