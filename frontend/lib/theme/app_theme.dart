import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Pale Blue-Grey Light Canvas Gradient (2 stops)
  static const Color backgroundStart = Color(0xFFE8F0F2);
  static const Color backgroundEnd = Color(0xFFDDE5ED);

  // Soft Glassmorphic Surface Colors (Light Mode)
  static const Color glassSurface = Color(0x4DFFFFFF); // 30% white frosted
  static const Color glassSurfaceElevated = Color(0x99FFFFFF); // 60% white frosted
  static const Color glassBorder = Color(0x80FFFFFF); // 50% white border

  // Surface aliases for backward compatibility
  static const Color surface = Color(0x73FFFFFF); // 45% white
  static const Color surfaceElevated = Color(0x99FFFFFF); // 60% white
  static const Color surfaceBorder = glassBorder;

  // Primary Muted Teal
  static const Color tealPrimary = Color(0xFF6BA3A3);
  static const Color tealLight = Color(0xFF8FBDBD);
  static const Color tealDark = Color(0xFF4F8585);

  // Secondary Soft Lavender
  static const Color lavenderAccent = Color(0xFFB0A8B9);
  static const Color lavenderDeep = Color(0xFF9A90A6);
  static const Color lavenderLight = Color(0xFFC4B5FD);

  // Financial Accents & Aliases
  static const Color emeraldPrimary = tealPrimary;
  static const Color indigoAccent = lavenderAccent;
  static const Color purpleAgent = lavenderDeep;
  static const Color cyanTech = tealPrimary;
  static const Color amberWarning = Color(0xFFE0A458); // Muted amber
  static const Color roseDanger = Color(0xFFE57373); // Soft red (like Colors.red.shade300)

  // High-Contrast Dark Text for Light Background
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF555555);
  static const Color textMuted = Color(0xFF7A7A7A);

  static LinearGradient get backgroundGradient => const LinearGradient(
        colors: [backgroundStart, backgroundEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static ThemeData get lightSoftGlassTheme => softGlassTheme;

  static ThemeData get softGlassTheme {
    final baseTextTheme = GoogleFonts.outfitTextTheme(ThemeData.light().textTheme);
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      primaryColor: tealPrimary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: tealPrimary,
        brightness: Brightness.light,
        surface: surface,
        error: roseDanger,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.bold),
        displayMedium: baseTextTheme.displayMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.bold),
        displaySmall: baseTextTheme.displaySmall?.copyWith(color: textPrimary, fontWeight: FontWeight.bold),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 28),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 24),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
        titleLarge: baseTextTheme.titleLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        titleMedium: baseTextTheme.titleMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        titleSmall: baseTextTheme.titleSmall?.copyWith(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: textPrimary, fontSize: 15),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textSecondary, fontSize: 13.5),
        bodySmall: baseTextTheme.bodySmall?.copyWith(color: textMuted, fontSize: 12),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
          fontFamily: 'Outfit',
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tealPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'Outfit'),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x80FFFFFF), // 50% white fill
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
        labelStyle: const TextStyle(color: textSecondary),
      ),
    );
  }
}
