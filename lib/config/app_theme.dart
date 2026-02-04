import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette {
  static const Color blue = Color(0xFF1F4ED8);
  static const Color blueDeep = Color(0xFF14379B);
  static const Color teal = Color(0xFF1EC9A4);
  static const Color amber = Color(0xFFFFB454);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color ink = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF4F6FB);
  static const Color stroke = Color(0xFFE2E8F0);

  static const Color night = Color(0xFF0B0F1A);
  static const Color nightSurface = Color(0xFF121A2A);
  static const Color nightSurfaceAlt = Color(0xFF1A2335);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppPalette.blue,
      onPrimary: Colors.white,
      secondary: AppPalette.teal,
      onSecondary: Colors.white,
      tertiary: AppPalette.amber,
      onTertiary: AppPalette.ink,
      error: AppPalette.coral,
      onError: Colors.white,
      background: AppPalette.surfaceAlt,
      onBackground: AppPalette.ink,
      surface: AppPalette.surface,
      onSurface: AppPalette.ink,
      surfaceVariant: AppPalette.surfaceAlt,
      onSurfaceVariant: AppPalette.ink.withOpacity(0.72),
      outline: AppPalette.stroke,
    );
    return _baseTheme(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF7BA6FF),
      onPrimary: const Color(0xFF0B0F1A),
      secondary: const Color(0xFF45E6C5),
      onSecondary: const Color(0xFF0B0F1A),
      tertiary: const Color(0xFFFFC274),
      onTertiary: const Color(0xFF1B1F2A),
      error: const Color(0xFFFF7A7A),
      onError: const Color(0xFF0B0F1A),
      background: AppPalette.night,
      onBackground: Colors.white,
      surface: AppPalette.nightSurface,
      onSurface: Colors.white,
      surfaceVariant: AppPalette.nightSurfaceAlt,
      onSurfaceVariant: Colors.white70,
      outline: const Color(0xFF2A3650),
    );
    return _baseTheme(scheme);
  }

  static ThemeData _baseTheme(ColorScheme scheme) {
    final base = ThemeData(
      colorScheme: scheme,
      brightness: scheme.brightness,
      useMaterial3: true,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.6),
      displayMedium: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleLarge: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
      bodySmall: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500),
    );

    return base.copyWith(
      textTheme: textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      scaffoldBackgroundColor: scheme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.background,
        foregroundColor: scheme.onBackground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onBackground),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant.withOpacity(0.8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: textTheme.titleMedium?.copyWith(color: scheme.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: textTheme.titleMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.titleMedium,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceVariant,
        selectedColor: scheme.primary.withOpacity(0.12),
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withOpacity(0.6),
        thickness: 1,
        space: 24,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.primary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withOpacity(0.14),
        elevation: 0,
        labelTextStyle: MaterialStatePropertyAll(
          textTheme.bodySmall?.copyWith(color: scheme.onSurface),
        ),
        iconTheme: MaterialStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(MaterialState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
