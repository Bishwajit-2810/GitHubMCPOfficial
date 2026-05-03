import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// GitHub-inspired dark theme with gradient palette and Inter typography.
class AppTheme {
  AppTheme._();

  // ── Core palette ────────────────────────────────────────────────────────────
  static const Color bg = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceHigh = Color(0xFF1C2128);
  static const Color border = Color(0xFF30363D);
  static const Color accent = Color(0xFF238636);
  static const Color accentLight = Color(0xFF2EA043);
  static const Color error = Color(0xFFF85149);
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF484F58);

  // ── Category gradients ──────────────────────────────────────────────────────
  static const repoGradient = [Color(0xFF1565C0), Color(0xFF1976D2)];
  static const projectGradient = [Color(0xFF6A1B9A), Color(0xFF8E24AA)];
  static const aiGradient = [Color(0xFFBF360C), Color(0xFFE64A19)];
  static const greenGradient = [Color(0xFF1B5E20), Color(0xFF2E7D32)];

  static ThemeData get dark {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: accent,
        secondary: accentLight,
        error: error,
        onSurface: textPrimary,
        onPrimary: Colors.white,
        outline: border,
        surfaceContainerHighest: surfaceHigh,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        titleLarge: GoogleFonts.plusJakartaSans(
            color: textPrimary, fontWeight: FontWeight.w700, fontSize: 20),
        titleMedium: GoogleFonts.plusJakartaSans(
            color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        titleSmall: GoogleFonts.plusJakartaSans(
            color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
        bodyLarge: GoogleFonts.inter(color: textPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: textPrimary, fontSize: 14),
        bodySmall: GoogleFonts.inter(color: textSecondary, fontSize: 12),
        labelLarge: GoogleFonts.inter(
            color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
        labelMedium: GoogleFonts.inter(color: textSecondary, fontSize: 12),
        labelSmall: GoogleFonts.inter(color: textMuted, fontSize: 11),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg,
        hintStyle: GoogleFonts.inter(color: textMuted),
        labelStyle: GoogleFonts.inter(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          minimumSize: const Size(double.infinity, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentLight,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      listTileTheme: ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
        titleTextStyle: GoogleFonts.inter(
            color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        subtitleTextStyle:
            GoogleFonts.inter(color: textSecondary, fontSize: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        labelStyle: GoogleFonts.inter(color: textPrimary, fontSize: 12),
        side: const BorderSide(color: border),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.4)
              : surfaceHigh,
        ),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: accent),
    );
  }
}
