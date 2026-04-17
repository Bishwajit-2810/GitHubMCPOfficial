import 'package:flutter/material.dart';

/// GitHub-inspired dark theme.
class AppTheme {
  AppTheme._();

  static const Color _bg = Color(0xFF0D1117);
  static const Color _surface = Color(0xFF161B22);
  static const Color _border = Color(0xFF30363D);
  static const Color _accent = Color(0xFF238636);
  static const Color _accentLight = Color(0xFF2EA043);
  static const Color _error = Color(0xFFF85149);
  static const Color _textPrimary = Color(0xFFC9D1D9);
  static const Color _textSecondary = Color(0xFF8B949E);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          surface: _surface,
          primary: _accent,
          secondary: _accentLight,
          error: _error,
          onSurface: _textPrimary,
          onPrimary: Colors.white,
          outline: _border,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _surface,
          foregroundColor: _textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: _textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          color: _surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: _border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _bg,
          hintStyle: const TextStyle(color: _textSecondary),
          labelStyle: const TextStyle(color: _textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _accent, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _error),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _textPrimary,
            side: const BorderSide(color: _border),
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _accentLight),
        ),
        dividerTheme: const DividerThemeData(color: _border, thickness: 1),
        listTileTheme: const ListTileThemeData(
          textColor: _textPrimary,
          iconColor: _textSecondary,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _surface,
          labelStyle: const TextStyle(color: _textPrimary, fontSize: 12),
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: _textPrimary),
          bodyMedium: TextStyle(color: _textPrimary),
          bodySmall: TextStyle(color: _textSecondary),
          titleLarge: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
          labelSmall: TextStyle(color: _textSecondary),
        ),
      );
}
