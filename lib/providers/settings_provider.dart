import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, amoled }

class SettingsController extends StateNotifier<AppThemeMode> {
  SettingsController() : super(AppThemeMode.light) {
    _load();
  }

  Completer<void>? _loading;

  Future<void> ensureLoaded() async {
    if (_loading != null) return _loading!.future;
    _load();
  }

  Future<void> _load() async {
    final completer = Completer<void>();
    _loading = completer;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('theme_mode');
      if (stored == 'dark') {
        state = AppThemeMode.dark;
      } else if (stored == 'amoled') {
        state = AppThemeMode.amoled;
      } else {
        state = AppThemeMode.light;
      }
      completer.complete();
    } catch (e) {
      completer.completeError(e);
    } finally {
      _loading = null;
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    state = mode;
    await prefs.setString('theme_mode', mode.name);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppThemeMode>((ref) {
  return SettingsController();
});
