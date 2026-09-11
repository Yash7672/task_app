import 'package:flutter/material.dart';

/// Theme extension marker that is present ONLY inside the Glass theme.
///
/// Widgets can check `PyloGlass.isActive(context)` to apply glass-specific
/// visuals (blur, translucent surfaces) without ever affecting Dark, Light
/// or AMOLED themes.
class PyloGlass extends ThemeExtension<PyloGlass> {
  const PyloGlass();

  static bool isActive(BuildContext context) =>
      Theme.of(context).extension<PyloGlass>() != null;

  @override
  PyloGlass copyWith() => const PyloGlass();

  @override
  PyloGlass lerp(ThemeExtension<PyloGlass>? other, double t) =>
      other is PyloGlass ? other : const PyloGlass();
}

/// Frosted-glass color palette shared by the Glass theme and its widgets.
///
/// This is a COMPLETE color system, not "transparent widgets". The palette
/// is designed so every tier of the interface reads as premium glass:
/// dark ambient background → layered translucent surfaces → readable text.
class GlassColors {
  // Background
  static const Color bg = Color(0xFF0B0B16);
  static const Color bgGradientStart = Color(0xFF101022);
  static const Color bgGradientEnd = Color(0xFF060610);

  // Opaque surfaces (fallback where translucency would hurt readability)
  static const Color surfaceOpaque = Color(0xFF141422);
  static const Color surfaceOpaqueDark = Color(0xEB141422);

  // Surface levels — each floats above the previous one
  static const Color level1 = Color(0x14FFFFFF); // 8%  white
  static const Color level2 = Color(0x1F4A4F5E); // frosted dark
  static const Color level3 = Color(0x26FFFFFF); // 15% white

  // Control surfaces
  static const Color surface = Color(0x1FFFFFFF);
  static const Color surfaceStrong = Color(0x2EFFFFFF);
  static const Color surfacePressed = Color(0x38FFFFFF);

  // Borders
  static const Color border = Color(0x14FFFFFF);
  static const Color borderMedium = Color(0x1FFFFFFF);
  static const Color borderStrong = Color(0x2EFFFFFF);

  // Text
  static const Color textPrimary = Color(0xF2F2F5FF);
  static const Color textSecondary = Color(0xB8F2F2F5);
  static const Color textMuted = Color(0x7AF2F2F5);
  static const Color textFaint = Color(0x52F2F2F5);

  // Accent — PYLO amber/orange, used sparingly to guide attention
  static const Color accent = Color(0xFFFFB74D);
  static const Color accentStrong = Color(0xFFFFA726);
  static const Color accentSubtle = Color(0x26FFB74D);
  static const Color accentGlow = Color(0x33FFB74D);

  // Legacy deep-purple accent kept for icons/selections
  static const Color deepAccent = Color(0xFF6D5BD0);
  static const Color deepAccentStrong = Color(0xFF4F42A8);
  static const Color deepAccentGlow = Color(0x555F4FA8);

  // Functional colors
  static const Color success = Color(0xFF66BB6A);
  static const Color successSubtle = Color(0x1F66BB6A);
  static const Color warning = Color(0xFFFFB74D);
  static const Color warningSubtle = Color(0x26FFB74D);
  static const Color error = Color(0xFFEF5350);
  static const Color errorSubtle = Color(0x26EF5350);

  // Ambient lighting used by the background gradient
  static const Color glow = Color(0x405F4FA8);
  static const Color glowSoft = Color(0x26FFB74D);
}

class AppTheme {
  static late final ThemeData _lightTheme;
  static late final ThemeData _darkTheme;
  static late final ThemeData _amoledTheme;
  static late final ThemeData _glassTheme;
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

    _glassTheme = _buildGlass();
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

  /// The Glass theme — a premium dark "frosted glass" design system.
  ///
  /// Translucent surfaces float on a soft ambient gradient background with
  /// three visible depth levels. Blur is applied selectively (the GlassSurface
  /// component, the floating nav), never to every widget, so the theme stays
  /// smooth on real hardware. Text colours keep strong contrast on every
  /// surface for readability.
  static ThemeData _buildGlass() {
    final baseDark = _darkTheme;

    final scheme = baseDark.colorScheme.copyWith(
      primary: GlassColors.accent,
      onPrimary: const Color(0xFF1A1300),
      primaryContainer: GlassColors.accentSubtle,
      onPrimaryContainer: GlassColors.textPrimary,
      secondary: GlassColors.deepAccent,
      onSecondary: Colors.white,
      secondaryContainer: GlassColors.accentSubtle,
      onSecondaryContainer: GlassColors.textPrimary,
      surface: GlassColors.level1,
      surfaceContainerLowest: GlassColors.level1,
      surfaceContainerLow: GlassColors.level1,
      surfaceContainer: GlassColors.level2,
      surfaceContainerHigh: GlassColors.level2,
      surfaceContainerHighest: GlassColors.level3,
      onSurface: GlassColors.textPrimary,
      onSurfaceVariant: GlassColors.textSecondary,
      outline: GlassColors.borderStrong,
      outlineVariant: GlassColors.border,
      error: GlassColors.error,
      onError: Colors.white,
      errorContainer: GlassColors.errorSubtle,
      onErrorContainer: GlassColors.error,
      shadow: Colors.black,
      surfaceTint: Colors.transparent,
    );

    final borderOutline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: GlassColors.borderMedium, width: 1),
    );
    final focusedOutline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: GlassColors.accent, width: 1.5),
    );

    return baseDark.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: scheme,
      appBarTheme: baseDark.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: GlassColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: GlassColors.borderMedium, width: 1),
        ),
        elevation: 2,
        color: GlassColors.level2,
        shadowColor: const Color(0x28000000),
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GlassColors.surfaceOpaqueDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: GlassColors.borderMedium, width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: GlassColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
        contentTextStyle: const TextStyle(
          color: GlassColors.textSecondary,
          fontSize: 15,
          height: 1.4,
          fontFamily: 'Inter',
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: GlassColors.surfaceOpaqueDark,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: GlassColors.borderMedium),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GlassColors.level1,
        labelStyle: const TextStyle(color: GlassColors.textSecondary),
        hintStyle: const TextStyle(color: GlassColors.textMuted),
        prefixIconColor: GlassColors.textSecondary,
        suffixIconColor: GlassColors.textSecondary,
        border: borderOutline,
        enabledBorder: borderOutline,
        focusedBorder: focusedOutline,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GlassColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GlassColors.error, width: 1.5),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: GlassColors.accent,
        selectionColor: GlassColors.accentSubtle,
        selectionHandleColor: GlassColors.accent,
      ),
      dividerTheme: const DividerThemeData(
        color: GlassColors.border,
        thickness: 1,
        space: 1,
      ),
      navigationRailTheme: baseDark.navigationRailTheme.copyWith(
        backgroundColor: Colors.transparent,
        indicatorColor: GlassColors.accentSubtle,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: GlassColors.accent,
        linearTrackColor: GlassColors.border,
        circularTrackColor: GlassColors.border,
      ),
      sliderTheme: baseDark.sliderTheme.copyWith(
        activeTrackColor: GlassColors.accent,
        inactiveTrackColor: GlassColors.borderStrong,
        thumbColor: GlassColors.accent,
        overlayColor: GlassColors.accentSubtle,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GlassColors.accent;
          }
          return GlassColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GlassColors.accentSubtle;
          }
          return GlassColors.border;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (states) => Colors.transparent),
        trackOutlineWidth: const WidgetStatePropertyAll(0),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GlassColors.accent;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Color(0xFF0B0B16)),
        side: BorderSide(color: GlassColors.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GlassColors.accent;
          }
          return GlassColors.textMuted;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.transparent,
        indicatorColor: GlassColors.accent.withValues(alpha: 0.20),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? GlassColors.accent
                : GlassColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? GlassColors.accent
                : GlassColors.textSecondary,
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: GlassColors.deepAccent,
        foregroundColor: Colors.white,
        elevation: 6,
        hoverElevation: 8,
        focusElevation: 8,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: GlassColors.borderStrong, width: 1),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: GlassColors.textSecondary,
        textColor: GlassColors.textPrimary,
        subtitleTextStyle: const TextStyle(
          color: GlassColors.textMuted,
          fontSize: 13,
          fontFamily: 'Inter',
        ),
        tileColor: Colors.transparent,
      ),
      chipTheme: baseDark.chipTheme.copyWith(
        backgroundColor: GlassColors.level1,
        side: BorderSide(color: GlassColors.borderMedium, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(
            color: GlassColors.textSecondary, fontFamily: 'Inter'),
        selectedColor: GlassColors.accentSubtle,
        checkmarkColor: GlassColors.accent,
        secondaryLabelStyle:
            const TextStyle(color: GlassColors.textSecondary, fontFamily: 'Inter'),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: GlassColors.surfaceOpaqueDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: GlassColors.borderMedium, width: 1),
        ),
        textStyle: const TextStyle(
          color: GlassColors.textPrimary,
          fontFamily: 'Inter',
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: GlassColors.surfaceOpaqueDark,
        contentTextStyle: const TextStyle(
            color: GlassColors.textPrimary, fontFamily: 'Inter'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: GlassColors.borderMedium, width: 1),
        ),
        actionTextColor: GlassColors.accent,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GlassColors.textPrimary,
          backgroundColor: GlassColors.level1,
          side: BorderSide(color: GlassColors.borderStrong, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GlassColors.deepAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GlassColors.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      tabBarTheme: baseDark.tabBarTheme.copyWith(
        indicatorColor: GlassColors.accent,
        labelColor: GlassColors.textPrimary,
        unselectedLabelColor: GlassColors.textMuted,
        dividerColor: GlassColors.border,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: GlassColors.surfaceOpaqueDark,
        hourMinuteColor: GlassColors.level2,
        dialHandColor: GlassColors.accent,
        dialBackgroundColor: GlassColors.level1,
        entryModeIconColor: GlassColors.accent,
        dayPeriodColor: GlassColors.borderStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: GlassColors.borderMedium),
        ),
        helpTextStyle:
            const TextStyle(color: GlassColors.textSecondary, fontFamily: 'Inter'),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: GlassColors.surfaceOpaqueDark,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: GlassColors.level2,
        headerForegroundColor: GlassColors.textPrimary,
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: GlassColors.textSecondary),
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF0B0B16);
          }
          return GlassColors.textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GlassColors.accent;
          }
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GlassColors.borderMedium),
        ),
      ),
      extensions: const [PyloGlass()],
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

  static ThemeData get glassTheme {
    _ensureInitialized();
    return _glassTheme;
  }
}