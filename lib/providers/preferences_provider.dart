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

  /// Alarm sound id (`classic`, `marimba`, `gentle`, `digital`, `urgent`,
  /// `custom`).  Kept as a plain string so Settings can render the list.
  final String alarmSoundId;

  /// `content://com.example.task_app.fileProvider/alarms/<file>` for the
  /// user-picked alarm audio file (only used when [alarmSoundId] == 'custom').
  final String? customAlarmUri;

  /// Whether the alarm channel should vibrate while ringing.
  final bool alarmVibrate;

  /// How long the alarm's Snooze button postpones it, in minutes.
  final int alarmSnoozeMinutes;

  SettingsPreferences({
    this.notificationsEnabled = true,
    this.birthdayRemindersEnabled = true,
    List<int>? reminderMinutes,
    this.dailyReminderEnabled = false,
    this.dailyReminderHour = 20,
    this.dailyReminderMinute = 0,
    this.alarmSoundId = 'classic',
    this.customAlarmUri,
    this.alarmVibrate = true,
    this.alarmSnoozeMinutes = 5,
  }) : reminderMinutes = reminderMinutes ?? const [5, 10];

  SettingsPreferences copyWith({
    bool? notificationsEnabled,
    bool? birthdayRemindersEnabled,
    List<int>? reminderMinutes,
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    String? alarmSoundId,
    String? customAlarmUri,
    bool? alarmVibrate,
    int? alarmSnoozeMinutes,
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
      alarmSoundId: alarmSoundId ?? this.alarmSoundId,
      customAlarmUri: customAlarmUri ?? this.customAlarmUri,
      alarmVibrate: alarmVibrate ?? this.alarmVibrate,
      alarmSnoozeMinutes: alarmSnoozeMinutes ?? this.alarmSnoozeMinutes,
    );
  }
}

class SettingsPreferencesNotifier extends StateNotifier<SettingsPreferences> {
  SettingsPreferencesNotifier() : super(SettingsPreferences()) {
    _loadPreferences();
  }

  SharedPreferences? _cachedPrefs;

  Future<SharedPreferences> _getPrefs() async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  Future<void> _loadPreferences() async {
    final prefs = await _getPrefs();
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
      alarmSoundId: prefs.getString('alarm_sound_id') ?? 'classic',
      customAlarmUri: prefs.getString('custom_alarm_uri'),
      alarmVibrate: prefs.getBool('alarm_vibrate') ?? true,
      alarmSnoozeMinutes: prefs.getInt('alarm_snooze_minutes') ?? 5,
    );
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    state = state.copyWith(notificationsEnabled: enabled);
    await prefs.setBool('notifications_enabled', enabled);
  }

  Future<void> setBirthdayRemindersEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    state = state.copyWith(birthdayRemindersEnabled: enabled);
    await prefs.setBool('birthday_reminders_enabled', enabled);
  }

  Future<void> setReminderMinutes(List<int> minutes) async {
    final prefs = await _getPrefs();
    state = state.copyWith(reminderMinutes: minutes);
    await prefs.setString('reminder_minutes', jsonEncode(minutes));
  }

  Future<void> setDailyReminderEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    state = state.copyWith(dailyReminderEnabled: enabled);
    await prefs.setBool('daily_reminder_enabled', enabled);
  }

  Future<void> setDailyReminderTime(int hour, int minute) async {
    final prefs = await _getPrefs();
    state = state.copyWith(
      dailyReminderHour: hour,
      dailyReminderMinute: minute,
    );
    await prefs.setInt('daily_reminder_hour', hour);
    await prefs.setInt('daily_reminder_minute', minute);
  }

  Future<void> setAlarmSoundId(String soundId) async {
    final prefs = await _getPrefs();
    state = state.copyWith(alarmSoundId: soundId);
    await prefs.setString('alarm_sound_id', soundId);
  }

  Future<void> setCustomAlarmUri(String? uri) async {
    final prefs = await _getPrefs();
    state = state.copyWith(customAlarmUri: uri);
    if (uri == null) {
      await prefs.remove('custom_alarm_uri');
    } else {
      await prefs.setString('custom_alarm_uri', uri);
    }
  }

  Future<void> setAlarmVibrate(bool vibrate) async {
    final prefs = await _getPrefs();
    state = state.copyWith(alarmVibrate: vibrate);
    await prefs.setBool('alarm_vibrate', vibrate);
  }

  Future<void> setAlarmSnoozeMinutes(int minutes) async {
    final prefs = await _getPrefs();
    state = state.copyWith(alarmSnoozeMinutes: minutes);
    await prefs.setInt('alarm_snooze_minutes', minutes);
  }
}

final settingsPreferencesProvider =
    StateNotifierProvider<SettingsPreferencesNotifier, SettingsPreferences>(
        (ref) {
  return SettingsPreferencesNotifier();
});
