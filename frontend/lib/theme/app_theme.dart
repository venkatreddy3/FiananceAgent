import 'package:flutter/material.dart';

class AppTheme {
  // Pale Blue-Grey & Dark Glass Canvas
  static const Color backgroundStart = Color(0xFF0B1120);
  static const Color backgroundMid = Color(0xFF0F172A);
  static const Color backgroundEnd = Color(0xFF192238);

  // Soft Glassmorphic Surface Colors
  static const Color glassSurface = Color(0x1AFFFFFF); // 10% white frosted
  static const Color glassSurfaceElevated = Color(0x28FFFFFF); // 16% white frosted
  static const Color glassBorder = Color(0x2EFFFFFF); // 18% white border

  // Surface aliases for backward compatibility
  static const Color surface = Color(0xFF131B2E);
  static const Color surfaceElevated = Color(0xFF1B243B);
  static const Color surfaceBorder = glassBorder;

  // Core Muted Teal & Soft Lavender Palette
  static const Color tealPrimary = Color(0xFF14B8A6); // Muted Teal
  static const Color tealLight = Color(0xFF2DD4BF);
  static const Color tealDark = Color(0xFF0D9488);

  static const Color lavenderAccent = Color(0xFFA78BFA); // Soft Lavender
  static const Color lavenderDeep = Color(0xFF8B5CF6);
  static const Color lavenderLight = Color(0xFFC4B5FD);

  // Financial Accents & Aliases
  static const Color emeraldPrimary = tealPrimary;
  static const Color indigoAccent = lavenderAccent;
  static const Color purpleAgent = lavenderDeep;
  static const Color cyanTech = tealLight;
  static const Color amberWarning = Color(0xFFFBBF24);
  static const Color roseDanger = Color(0xFFF43F5E);

  // Typography Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);

  static LinearGradient get backgroundGradient => const LinearGradient(
        colors: [backgroundStart, backgroundMid, backgroundEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static ThemeData get softGlassTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      primaryColor: tealPrimary,
      colorScheme: const ColorScheme.dark(
        primary: tealPrimary,
        secondary: lavenderAccent,
        surface: surface,
        error: roseDanger,
      ),
      fontFamily: 'Outfit',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tealPrimary,
          foregroundColor: const Color(0xFF042F2E),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: tealPrimary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      ),
    );
  }
}
