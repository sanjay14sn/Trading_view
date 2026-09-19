import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFFF6F8FC);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEAEAEE);
  static const Color surfaceBorder = Color(0xFFE2E8F0);

  static const Color primary = Color(0xFF2563EB); // Royal Blue
  static const Color buyGreen = Color(0xFF10B981); // Emerald Green
  static const Color sellRed = Color(0xFFEF4444); // Red
  static const Color warningOrange = Color(0xFFF59E0B); // Amber

  static const Color textPrimary = Color(0xFF1E2538); // Dark Charcoal
  static const Color textSecondary = Color(0xFF8A94A6); // Slate Grey
  static const Color textLight = Color(0xFF94A3B8);

  static const Color badgeGreenBg = Color(0xFFDCFCE7);
  static const Color badgeGreenText = Color(0xFF15803D);
  static const Color badgeRedBg = Color(0xFFFEE2E2);
  static const Color badgeRedText = Color(0xFFB91C1C);
  static const Color badgeBlueBg = Color(0xFFEFF6FF);
  static const Color badgeBlueText = Color(0xFF1D4ED8);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        surface: cardBg,
        error: sellRed,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme.apply(
              bodyColor: textPrimary,
              displayColor: textPrimary,
            ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBg,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
