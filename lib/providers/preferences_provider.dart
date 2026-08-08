import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPreferences {
  final bool notificationsEnabled;
  final bool appLockEnabled;
  final String appLockPin;
  final int reminderMinutesBefore;
  final bool dailyReminderEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;

  SettingsPreferences({
    this.notificationsEnabled = true,
    this.appLockEnabled = false,
    this.appLockPin = '',
    this.reminderMinutesBefore = 15,
    this.dailyReminderEnabled = false,
    this.dailyReminderHour = 20,
    this.dailyReminderMinute = 0,
  });

  SettingsPreferences copyWith({
    bool? notificationsEnabled,
    bool? appLockEnabled,
    String? appLockPin,
    int? reminderMinutesBefore,
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
  }) {
    return SettingsPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockPin: appLockPin ?? this.appLockPin,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      dailyReminderEnabled:
          dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
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
      appLockPin: prefs.getString('app_lock_pin') ?? '',
      reminderMinutesBefore: prefs.getInt('reminder_minutes_before') ?? 15,
      dailyReminderEnabled:
          prefs.getBool('daily_reminder_enabled') ?? false,
      dailyReminderHour: prefs.getInt('daily_reminder_hour') ?? 20,
      dailyReminderMinute: prefs.getInt('daily_reminder_minute') ?? 0,
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

  Future<void> setDailyReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(dailyReminderEnabled: enabled);
    await prefs.setBool('daily_reminder_enabled', enabled);
  }

  Future<void> setDailyReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      dailyReminderHour: hour,
      dailyReminderMinute: minute,
    );
    await prefs.setInt('daily_reminder_hour', hour);
    await prefs.setInt('daily_reminder_minute', minute);
  }
}

final settingsPreferencesProvider =
    StateNotifierProvider<SettingsPreferencesNotifier, SettingsPreferences>(
        (ref) {
  return SettingsPreferencesNotifier();
});
