import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPreferences {
  final bool notificationsEnabled;
  final List<int> reminderMinutes;
  final bool dailyReminderEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;
  final bool birthdayRemindersEnabled;

  SettingsPreferences({
    this.notificationsEnabled = true,
    this.birthdayRemindersEnabled = true,
    List<int>? reminderMinutes,
    this.dailyReminderEnabled = false,
    this.dailyReminderHour = 20,
    this.dailyReminderMinute = 0,
  }) : reminderMinutes = reminderMinutes ?? const [5, 10];

  SettingsPreferences copyWith({
    bool? notificationsEnabled,
    bool? birthdayRemindersEnabled,
    List<int>? reminderMinutes,
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
  }) {
    return SettingsPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      birthdayRemindersEnabled:
          birthdayRemindersEnabled ?? this.birthdayRemindersEnabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
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
    final reminderStr = prefs.getString('reminder_minutes');
    List<int> loadedReminders = [5, 10];
    if (reminderStr != null && reminderStr.isNotEmpty) {
      try {
        loadedReminders = (jsonDecode(reminderStr) as List)
            .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
            .where((e) => e > 0)
            .toList();
      } catch (_) {}
    } else {
      final oldVal = prefs.getInt('reminder_minutes_before');
      if (oldVal != null && oldVal > 0) {
        loadedReminders = [oldVal];
      }
    }
    state = SettingsPreferences(
      notificationsEnabled: prefs.getBool('notifications_enabled') ?? true,
      birthdayRemindersEnabled:
          prefs.getBool('birthday_reminders_enabled') ?? true,
      reminderMinutes: loadedReminders,
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

  Future<void> setBirthdayRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(birthdayRemindersEnabled: enabled);
    await prefs.setBool('birthday_reminders_enabled', enabled);
  }

  Future<void> setReminderMinutes(List<int> minutes) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(reminderMinutes: minutes);
    await prefs.setString('reminder_minutes', jsonEncode(minutes));
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
