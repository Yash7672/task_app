import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
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
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
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
  }

  // AMOLED Black Theme
  static ThemeData get amoledTheme {
    final dark = darkTheme;
    return dark.copyWith(
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: dark.appBarTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      colorScheme: dark.colorScheme.copyWith(
        surface: Colors.black,
        surfaceContainerHighest: const Color(0xFF1E1E1E), // For cards and surfaces
      ),
      cardTheme: dark.cardTheme.copyWith(
        color: const Color(0xFF1E1E1E),
      ),
    );
  }
}
