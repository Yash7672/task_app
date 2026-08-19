import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static late final ThemeData _lightTheme;
  static late final ThemeData _darkTheme;
  static late final ThemeData _amoledTheme;
  static bool _initialized = false;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    _lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
      ),
    );

    _darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
      ),
    );

    _amoledTheme = _darkTheme.copyWith(
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: _darkTheme.appBarTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      colorScheme: _darkTheme.colorScheme.copyWith(
        surface: Colors.black,
        surfaceContainerHighest: const Color(0xFF1E1E1E),
      ),
      cardTheme: _darkTheme.cardTheme.copyWith(
        color: const Color(0xFF1E1E1E),
      ),
    );
  }

  static ThemeData get lightTheme {
    _ensureInitialized();
    return _lightTheme;
  }

  static ThemeData get darkTheme {
    _ensureInitialized();
    return _darkTheme;
  }

  static ThemeData get amoledTheme {
    _ensureInitialized();
    return _amoledTheme;
  }
}
