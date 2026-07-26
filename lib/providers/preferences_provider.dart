import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPreferences {
  final bool notificationsEnabled;
  final bool appLockEnabled;
  final String appLockPin;
  final int reminderMinutesBefore;

  SettingsPreferences({
    this.notificationsEnabled = true,
    this.appLockEnabled = false,
    this.appLockPin = '1234',
    this.reminderMinutesBefore = 15,
  });

  SettingsPreferences copyWith({
    bool? notificationsEnabled,
    bool? appLockEnabled,
    String? appLockPin,
    int? reminderMinutesBefore,
  }) {
    return SettingsPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockPin: appLockPin ?? this.appLockPin,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
    );
  }
}

class SettingsPreferencesNotifier extends StateNotifier<SettingsPreferences> {
  SettingsPreferencesNotifier() : super(SettingsPreferences()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsPreferences(
      notificationsEnabled: prefs.getBool('notifications_enabled') ?? true,
      appLockEnabled: prefs.getBool('app_lock_enabled') ?? false,
      appLockPin: prefs.getString('app_lock_pin') ?? '1234',
      reminderMinutesBefore: prefs.getInt('reminder_minutes_before') ?? 15,
    );
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(notificationsEnabled: enabled);
    await prefs.setBool('notifications_enabled', enabled);
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(appLockEnabled: enabled);
    await prefs.setBool('app_lock_enabled', enabled);
  }

  Future<void> setAppLockPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(appLockPin: pin);
    await prefs.setString('app_lock_pin', pin);
  }

  Future<void> setReminderMinutesBefore(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(reminderMinutesBefore: minutes);
    await prefs.setInt('reminder_minutes_before', minutes);
  }
}

final settingsPreferencesProvider =
    StateNotifierProvider<SettingsPreferencesNotifier, SettingsPreferences>(
        (ref) {
  return SettingsPreferencesNotifier();
});
