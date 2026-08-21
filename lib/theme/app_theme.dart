import 'package:flutter/material.dart';

class AppTheme {
  static late final ThemeData _lightTheme;
  static late final ThemeData _darkTheme;
  static late final ThemeData _amoledTheme;
  static bool _initialized = false;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    _lightTheme = _base(Brightness.light);
    _darkTheme = _base(Brightness.dark);

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

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8F7FC),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F7FC),
        foregroundColor: isDark ? Colors.white : const Color(0xFF1D1B20),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        color: isDark ? const Color(0xFF1E1E20) : Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
