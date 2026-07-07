import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color bgDark = Color(0xFF090A0F);
  static const Color bgLight = Color(0xFFF5F7FA);

  static const Color cardBgDark = Color(0xFF121420);
  static const Color cardBgLight = Color(0xFFFFFFFF);

  static const Color primary = Color(0xFFFF5722); // Orange
  static const Color secondary = Color(0xFF1A237E); // Navy Blue
  static const Color secondaryLight = Color(0xFF4C56AF);

  static const Color textMainDark = Color(0xFFF3F4F6);
  static const Color textMainLight = Color(0xFF1A1A2E);

  static const Color textMutedDark = Color(0xFF9CA3AF);
  static const Color textMutedLight = Color(0xFF6B7280);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color critical = Color(0xFFEF4444);

  static const Color borderDark = Color(0xFF27273A);
  static const Color borderLight = Color(0xFFE5E7EB);

  // ── Dark Theme ──────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: bgDark,
      cardColor: cardBgDark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: cardBgDark,
        background: bgDark,
        error: critical,
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.sora(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textMainDark,
        ),
        titleLarge: GoogleFonts.sora(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textMainDark,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textMainDark,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textMutedDark,
        ),
        labelLarge: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.05,
          color: textMainDark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgDark,
        hintStyle: GoogleFonts.dmSans(color: textMutedDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ── Light Theme ──────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: bgLight,
      cardColor: cardBgLight,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: cardBgLight,
        background: bgLight,
        error: critical,
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.sora(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textMainLight,
        ),
        titleLarge: GoogleFonts.sora(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textMainLight,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textMainLight,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textMutedLight,
        ),
        labelLarge: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.05,
          color: textMainLight,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBgLight,
        hintStyle: GoogleFonts.dmSans(color: textMutedLight),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardBgLight,
        foregroundColor: textMainLight,
        elevation: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBgLight,
        selectedItemColor: primary,
        unselectedItemColor: textMutedLight,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

extension ThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => Theme.of(this).scaffoldBackgroundColor;
  Color get cardBg => Theme.of(this).cardColor;
  Color get textMain => isDark ? AppTheme.textMainDark : AppTheme.textMainLight;
  Color get textMuted => isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight;
  Color get border => isDark ? AppTheme.borderDark : AppTheme.borderLight;
}
