import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── DARK THEME COLORS ───────────────────────
  static const Color bgPrimary = Color(0xFF0A0E21);
  static const Color bgSurface = Color(0xFF151929);
  static const Color bgElevated = Color(0xFF1E2440);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8B92A8);

  // ─── LIGHT THEME COLORS ──────────────────────
  static const Color lightBgPrimary = Color(0xFFF5F5F7);
  static const Color lightBgSurface = Colors.white;
  static const Color lightBgElevated = Color(0xFFE8E8ED);
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  // 6 selectable accent colors
  static const List<Color> accentColors = [
    Color(0xFFA78BFA), // Purple (default)
    Color(0xFF60A5FA), // Ocean Blue
    Color(0xFF34D399), // Mint Green
    Color(0xFFF472B6), // Rose Pink
    Color(0xFFFBBF24), // Warm Amber
    Color(0xFFF87171), // Coral Red
  ];

  static const List<String> accentLabels = [
    'Purple', 'Ocean', 'Mint', 'Rose', 'Amber', 'Coral',
  ];

  // ─── TYPOGRAPHY ──────────────────────────────
  static TextStyle heroText({Color color = textPrimary}) =>
      GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w800, color: color);

  static TextStyle screenTitle({Color color = textPrimary}) =>
      GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: color);

  static TextStyle songTitle({Color color = textPrimary}) =>
      GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: color);

  static TextStyle artistName({Color color = textSecondary}) =>
      GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w400, color: color);

  static TextStyle labelText({Color color = textPrimary}) =>
      GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: color);

  static TextStyle smallText({Color color = textSecondary}) =>
      GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w400, color: color);

  static TextStyle bodyText({Color color = textPrimary, double size = 15}) =>
      GoogleFonts.nunito(fontSize: size, fontWeight: FontWeight.w400, color: color);

  static TextStyle sectionLabel(Color accentColor) =>
      GoogleFonts.nunito(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: accentColor, letterSpacing: 1.5,
      );

  // ─── DARK THEME ──────────────────────────────
  static ThemeData buildDarkTheme(Color accentColor) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPrimary,
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        surface: bgSurface,
      ),
      fontFamily: GoogleFonts.nunito().fontFamily,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(backgroundColor: bgPrimary, elevation: 0),
    );
  }

  // ─── LIGHT THEME ─────────────────────────────
  static ThemeData buildLightTheme(Color accentColor) {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBgPrimary,
      colorScheme: ColorScheme.light(
        primary: accentColor,
        surface: lightBgSurface,
      ),
      fontFamily: GoogleFonts.nunito().fontFamily,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(backgroundColor: lightBgPrimary, elevation: 0),
    );
  }

  // Keep backward compat
  static ThemeData buildTheme(Color accentColor) => buildDarkTheme(accentColor);
}
