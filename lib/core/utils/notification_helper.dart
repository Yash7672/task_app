import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'alarm_sound_service.dart';

/// Notification ID namespace offsets to prevent hash collisions.
/// Tasks use `id.hashCode`, birthdays use `id.hashCode + _birthdayOffset`.
/// This ensures task "abc" and birthday "abc-0" can never share an ID.
class NotificationId {
  static const int birthdayOffset = 500000000;

  /// Deterministic ID for a task reminder based on its offset in minutes.
  /// Using the offset instead of list index ensures that editing a task's
  /// reminder list never causes different reminders to collide.
  static int taskReminder(String taskId, int reminderMinutes) {
    return (taskId.hashCode + reminderMinutes) & 0x7FFFFFFF;
  }

  /// Deterministic ID for a task alarm.  Uses a large offset so it can
  /// never collide with any reminder minute value (max 1440).
  static int taskAlarm(String taskId) {
    return (taskId.hashCode + 999999) & 0x7FFFFFFF;
  }

  /// Returns all possible reminder notification IDs for a task across the
  /// full minute range 0–1440.  Used by cancelAllForTask to guarantee no
  /// stale reminders leak when the user adds custom minute offsets.
  static List<int> allReminderIds(String taskId) {
    // The range 0–1440 covers every minute of the day.  Using a fixed range
    // ensures that any user-configured offset (including non-standard values
    // like 3 or 7 minutes) is always cancelled.
    return List<int>.generate(1441, (i) => (taskId.hashCode + i) & 0x7FFFFFFF);
  }
}

/// The payload routed back into the app when an alarm fires.  A full-screen
/// alarm launches the activity with the notification's payload, so decoding
/// it here is how we know WHICH task woke the user and can show its screen.
class AlarmInfo {
  const AlarmInfo({
    required this.taskId,
    required this.taskTitle,
    required this.alarmTime,
    this.soundId,
    this.customUri,
  });

  final String taskId;
  final String taskTitle;
  final DateTime alarmTime;

  /// Per-task alarm sound override (`classic` … `custom`), or null to use the
  /// global Settings sound.  Embedded in the payload so the alarm screen can
  /// ring the right music for the right task even on a cold start.
  final String? soundId;

  /// Per-task custom sound content URI (used only when [soundId] == 'custom').
  final String? customUri;

  /// Stable identity used to de-duplicate alarm open events.
  String get key => '$taskId:${alarmTime.millisecondsSinceEpoch}';
}

class AlarmPayload {
  static const String scheme = 'pylo:alarm';

  /// Encodes the alarm into the notification payload string.
  /// Format: `pylo:alarm|<taskId>|<taskTitle>|<epochMs>|<soundId>|<customUri>`.
  /// The trailing sound fields are optional and empty when the task uses the
  /// global Settings sound, keeping older 4-part payloads decodable.
  static String encode({
    required String taskId,
    required String taskTitle,
    required DateTime alarmTime,
    String? soundId,
    String? customUri,
  }) {
    return '$scheme|${_encodePart(taskId)}|${_encodePart(taskTitle)}|'
        '${alarmTime.millisecondsSinceEpoch}'
        '|${_encodePart(soundId ?? '')}|${_encodePart(customUri ?? '')}';
  }

  /// Decodes a notification payload.  Returns null when the payload is not
  /// (or is no longer) a valid alarm payload.
  static AlarmInfo? decode(String? payload) {
    if (payload == null) return null;
    final parts = payload.split('|');
    if (parts.length < 4 || parts[0] != scheme) return null;
    final ms = int.tryParse(parts[3]);
    if (ms == null) return null;
    return AlarmInfo(
      taskId: _decodePart(parts[1]),
      taskTitle: _decodePart(parts[2]),
      alarmTime: DateTime.fromMillisecondsSinceEpoch(ms),
      soundId: parts.length > 4 && parts[4].isNotEmpty
          ? _decodePart(parts[4])
          : null,
      customUri: parts.length > 5 && parts[5].isNotEmpty
          ? _decodePart(parts[5])
          : null,
    );
  }

  static String _encodePart(String value) =>
      value.replaceAll('%', '%25').replaceAll('|', '%7C');
  static String _decodePart(String value) =>
      value.replaceAll('%7C', '|').replaceAll('%25', '%');
}

/// Built-in alarm sounds bundled as Android raw resources in
/// `res/raw/`.  `custom` uses a user-picked audio file instead.
enum PyloAlarmSound {
  classic('Classic', 'alarm_classic'),
  marimba('Marimba', 'alarm_marimba'),
  gentle('Gentle', 'alarm_gentle'),
  digital('Digital', 'alarm_digital'),
  urgent('Urgent', 'alarm_urgent'),
  custom('Custom', null);

  const PyloAlarmSound(this.label, this.rawName);

  /// Human-readable name shown in Settings.
  final String label;

  /// Raw resource name in res/raw (null for [PyloAlarmSound.custom]).
  final String? rawName;

  static PyloAlarmSound fromId(String? id) {
    return PyloAlarmSound.values.firstWhere(
      (sound) => sound.name == id,
      orElse: () => PyloAlarmSound.classic,
    );
  }
}

/// Everything that shapes the alarm's behaviour.  The configured sound is only
/// ever *played* by the in-app audioplayers engine (see AlarmScreen and
/// AlarmSoundService) — the OS notification that triggers the alarm is SILENT
/// because Android cannot open an app-private content:// sound while the app
/// process is closed and instead plays the default notification tone.
class AlarmChannelConfig {
  const AlarmChannelConfig({
    this.sound = PyloAlarmSound.classic,
    this.customUri,
    this.vibrate = true,
  });

  final PyloAlarmSound sound;

  /// `content://com.example.task_app.fileProvider/alarms/<file>` URI used
  /// when [sound] is [PyloAlarmSound.custom].
  final String? customUri;

  final bool vibrate;

  AlarmChannelConfig copyWith({
    PyloAlarmSound? sound,
    String? customUri,
    bool? vibrate,
  }) {
    return AlarmChannelConfig(
      sound: sound ?? this.sound,
      customUri: customUri ?? this.customUri,
      vibrate: vibrate ?? this.vibrate,
    );
  }

  static AlarmChannelConfig fromPrefs({
    required String? soundId,
    required String? customUri,
    required bool? vibrate,
  }) {
    return AlarmChannelConfig(
      sound: PyloAlarmSound.fromId(soundId),
      customUri: customUri,
      vibrate: vibrate ?? true,
    );
  }
}

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Upper bound on how many platform notifications one task may own. Must be
  /// identical between the scheduling loop and cancelAllForTask so a
  /// notification can never be scheduled that no cancel path can reach.
  static const int maxReminders = 12;

  /// Well-known reminder minute offsets used for deterministic cancel.
  static const List<int> knownReminderOffsets = [
    1, 5, 10, 15, 30, 60, 120, 180, 1440,
  ];

  static const String alarmChannelId = 'pylo_alarm_channel';

  /// SharedPreferences key remembering the last alarm already surfaced to the
  /// UI, so a cold start from an already-handled full-screen alarm never
  /// re-opens (and re-rings) the same alarm a second time.
  static const String _keyLastHandledAlarm = 'pylo_last_handled_alarm';

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'taskflow_channel',
    'TaskFlow Notifications',
    channelDescription: 'Reminders for your tasks',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/launcher_icon',
  );

  static const AndroidNotificationDetails _birthdayDetails =
      AndroidNotificationDetails(
    'birthday_channel',
    'Birthday Reminders',
    channelDescription: 'Reminders for upcoming birthdays',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/launcher_icon',
  );

  static const AndroidNotificationDetails _focusDetails =
      AndroidNotificationDetails(
    'focus_channel',
    'Focus Mode',
    channelDescription: 'Focus session notifications',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    ongoing: true,
    onlyAlertOnce: true,
    icon: '@mipmap/launcher_icon',
  );

  /// Current alarm channel configuration.  Stays in sync with the persisted
  /// Settings preferences; any change triggers a delete+recreate of the
  /// alarm channel (Android channels are immutable once created) followed by
  /// a reschedule of pending alarms.
  static AlarmChannelConfig _alarmConfig = const AlarmChannelConfig();

  static AlarmChannelConfig get alarmConfig => _alarmConfig;

  /// Fired every time an alarm actually goes off (either the app was woken by
  /// the full-screen intent, or the user tapped the alarm notification).
  /// Listeners (e.g. main.dart) present the full-screen alarm UI.
  static final StreamController<AlarmInfo> _alarmController =
      StreamController<AlarmInfo>.broadcast();

  static Stream<AlarmInfo> get alarmEvents => _alarmController.stream;

  static AlarmInfo? _lastEmitted;
  static Timer? _dedupeResetTimer;

  /// Used by the AlarmScreen to suppress duplicate pushes while an alarm is
  /// already on screen.
  static bool isAlarmOpen = false;

  /// Notification details for a REAL (full-screen) alarm.  The notification is
  /// deliberately silenced: the OS would otherwise play the channel sound
  /// directly, and FileProvider content URIs are unreadable once the app
  /// process is dead — exactly why custom music regressed to the default tone.
  /// The selected music is played by the in-app audioplayers engine once the
  /// full-screen alarm UI is on screen.
  static _alarmDetails(AlarmChannelConfig config) {
    return AndroidNotificationDetails(
      alarmChannelId,
      'PYLO Alarms',
      channelDescription: 'Full-screen alarm alerts for your tasks',
      importance: Importance.max,
      priority: Priority.max,
      playSound: false,
      enableVibration: config.vibrate,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      // FLAG_INSISTENT = 0x4: keeps the (silent) alert active until the user
      // acts — vibration repeats for a real alarm while the music loops in-app.
      additionalFlags: Int32List.fromList([4]),
      icon: '@mipmap/launcher_icon',
    );
  }

  /// Ensure the notification plugin is initialized exactly once.
  /// Safe to call from any context; idempotent.
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await init();
  }

  static Future<void> init() async {
    if (kIsWeb) {
      return;
    }
    if (_initialized) return;

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      debugPrint('Timezone init failed: $e');
    }

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _initialized = true;

    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  /// (Re)builds the alarm channel to match [config] then schedules the
  /// effects that depend on editing settings. Deleting and recreating the
  /// channel is required because Android channels are immutable once created —
  /// a sound or vibration change must drop the old channel entirely.
  static Future<void> reconfigureAlarmChannel(AlarmChannelConfig config) async {
    if (kIsWeb) return;
    await ensureInitialized();
    _alarmConfig = config;
    await _recreateAlarmChannel();
  }

  /// Called once at startup (after [init]) with the persisted preferences so
  /// the channel always reflects the stored sound/vibration, migrating older
  /// builds whose alarm channel was created with the default sound.
  static Future<void> ensureAlarmChannel(AlarmChannelConfig config) async {
    if (kIsWeb) return;
    await ensureInitialized();
    _alarmConfig = config;
    await _recreateAlarmChannel();
  }

  static Future<void> _recreateAlarmChannel() async {
    if (kIsWeb) return;
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await androidImpl?.deleteNotificationChannel(alarmChannelId);
    } catch (e) {
      debugPrint('deleteNotificationChannel failed: $e');
    }
    try {
      await androidImpl?.createNotificationChannel(
        AndroidNotificationChannel(
          alarmChannelId,
          'PYLO Alarms',
          description: 'Full-screen alarm alerts for your tasks',
          importance: Importance.max,
          playSound: false,
          sound: null,
          enableVibration: _alarmConfig.vibrate,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
    } catch (e) {
      debugPrint('createNotificationChannel failed: $e');
    }
  }

  /// Decodes a notification response (warm start: the alarm's full-screen
  /// intent brought the app forward) and surfaces the alarm to the UI.
  static void _onNotificationResponse(NotificationResponse response) {
    final alarm = AlarmPayload.decode(response.payload);
    if (alarm != null) _emitAlarm(alarm);
  }

  static void _emitAlarm(AlarmInfo alarm) {
    // Guard against duplicate deliveries for the same alarm (the full-screen
    // intent and a user tap can both reach the callback in quick succession).
    final last = _lastEmitted;
    if (last != null &&
        last.taskId == alarm.taskId &&
        alarm.alarmTime.difference(last.alarmTime).inSeconds.abs() <= 2) {
      return;
    }
    _lastEmitted = alarm;
    _dedupeResetTimer?.cancel();
    _dedupeResetTimer =
        Timer(const Duration(seconds: 5), () => _lastEmitted = null);
    unawaited(_markAlarmHandled(alarm));
    if (!isAlarmOpen) {
      _alarmController.add(alarm);
    }
  }

  /// Cold-start path: the OS launched the app directly from an alarm's
  /// full-screen intent.  Returns the alarm to present (skipping one that was
  /// already surfaced while the app was alive).
  static Future<AlarmInfo?> pendingLaunchAlarm() async {
    if (kIsWeb) return null;
    try {
      final details = await _notifications.getNotificationAppLaunchDetails();
      final alarm = AlarmPayload.decode(details?.notificationResponse?.payload);
      if (alarm == null) return null;
      final handled = await _lastHandledAlarmKey();
      if (handled == alarm.key) return null;
      await _markAlarmHandled(alarm);
      return alarm;
    } catch (e) {
      debugPrint('pendingLaunchAlarm failed: $e');
      return null;
    }
  }

  static Future<String?> _lastHandledAlarmKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyLastHandledAlarm);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _markAlarmHandled(AlarmInfo alarm) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastHandledAlarm, alarm.key);
    } catch (_) {}
  }

  static NotificationDetails _details(AndroidNotificationDetails android) {
    return NotificationDetails(
      android: android,
      iOS: const DarwinNotificationDetails(),
    );
  }

  /// Show an immediate notification using the shared plugin instance.
  static Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await ensureInitialized();
    await _notifications.show(id, title, body, _details(_androidDetails),
        payload: payload);
  }

  static Future<void> scheduleTaskReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (kIsWeb) {
      return;
    }
    await ensureInitialized();
    final now = DateTime.now();
    if (!scheduledDate.isAfter(now)) {
      debugPrint('Skipping reminder id=$id: $scheduledDate is in the past (now=$now)');
      return;
    }

    // Ensure task notification IDs are always positive and within 32-bit range.
    final safeId = id & 0x7FFFFFFF;

    try {
      await _notifications.zonedSchedule(
        safeId,
        title,
        body,
        _toTZDate(scheduledDate),
        _details(_androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Scheduled reminder id=$id: "$body" at $scheduledDate');
    } catch (e) {
      // Exact alarms need the (separate) Alarms & reminders permission on
      // Android 12+. If it was denied, fall back to an inexact schedule so
      // reminders still fire instead of being silently dropped forever.
      debugPrint('Exact schedule failed for id=$id ($e); retrying inexact');
      try {
        await _notifications.zonedSchedule(
          safeId,
          title,
          body,
          _toTZDate(scheduledDate),
          _details(_androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e2) {
        debugPrint('Failed to schedule reminder id=$id: $e2');
      }
    }
  }

  static Future<void> scheduleTaskReminders({
    required String taskId,
    required String taskTitle,
    required DateTime taskDateTime,
    required List<int> reminderMinutes,
  }) async {
    if (kIsWeb) {
      return;
    }

    await ensureInitialized();
    final capped = reminderMinutes.length > maxReminders
        ? reminderMinutes.sublist(0, maxReminders)
        : reminderMinutes;
    for (int i = 0; i < capped.length; i++) {
      final minutes = capped[i];
      final scheduledDate = taskDateTime.subtract(Duration(minutes: minutes));
      final now = DateTime.now();
      if (!scheduledDate.isAfter(now)) {
        continue;
      }

      final timeStr =
          '${taskDateTime.hour.toString().padLeft(2, '0')}:${taskDateTime.minute.toString().padLeft(2, '0')}';

      final body = minutes <= 1
          ? '$taskTitle starts at $timeStr'
          : 'In $minutes min: $taskTitle at $timeStr';

      // Use deterministic ID based on reminder offset (not list index) so
      // editing the reminder list never causes collisions.
      await scheduleTaskReminder(
        id: NotificationId.taskReminder(taskId, minutes),
        title: 'Task Reminder',
        body: body,
        scheduledDate: scheduledDate,
      );
    }
  }

  /// Schedules a single alarm notification at [alarmTime] for the task.
  /// The alarm fires exactly at the specified time through the dedicated
  /// alarm channel with a full-screen intent carrying an AlarmPayload that
  /// lets the app present the matching full-screen alarm UI.
  static Future<void> scheduleTaskAlarm({
    required String taskId,
    required String taskTitle,
    required DateTime alarmTime,
    String? soundId,
    String? customUri,
  }) async {
    if (kIsWeb) return;
    await ensureInitialized();

    final now = DateTime.now();
    if (!alarmTime.isAfter(now)) {
      debugPrint('Skipping alarm for task $taskId: $alarmTime is in the past');
      return;
    }

    final id = NotificationId.taskAlarm(taskId);
    final timeStr =
        '${alarmTime.hour.toString().padLeft(2, '0')}:${alarmTime.minute.toString().padLeft(2, '0')}';
    final payload = AlarmPayload.encode(
      taskId: taskId,
      taskTitle: taskTitle,
      alarmTime: alarmTime,
      soundId: soundId,
      customUri: customUri,
    );

    // Use the dedicated alarm channel with MAX importance + full-screen intent
    // + a SILENT notification.  The music/vibration the user picked is played
    // by AlarmScreen's audioplayers engine when the full-screen UI mounts.  The
    // payload lets us route the fired alarm to its screen (and sound).
    try {
      await _notifications.zonedSchedule(
        id,
        '⏰ Task Alarm',
        '$taskTitle — alarm at $timeStr',
        _toTZDate(alarmTime),
        _details(_alarmDetails(_alarmConfig)),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('Scheduled alarm id=$id: "$taskTitle" at $alarmTime (alarm channel)');
    } catch (e) {
      debugPrint('Exact alarm schedule failed for id=$id ($e); retrying inexact');
      try {
        await _notifications.zonedSchedule(
          id,
          '⏰ Task Alarm',
          '$taskTitle — alarm at $timeStr',
          _toTZDate(alarmTime),
          _details(_alarmDetails(_alarmConfig)),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } catch (e2) {
        debugPrint('Failed to schedule alarm id=$id: $e2');
      }
    }
  }

  /// Re-alarms the same task [duration] from now. Cancels the original
  /// firing alarm first so the two can never ring together.  [soundId] and
  /// [customUri] carry the task's sound override across the re-schedule.
  static Future<void> snoozeTaskAlarm({
    required String taskId,
    required String taskTitle,
    required Duration duration,
    String? soundId,
    String? customUri,
  }) async {
    if (kIsWeb) return;
    await ensureInitialized();
    await _notifications.cancel(NotificationId.taskAlarm(taskId));
    await scheduleTaskAlarm(
      taskId: taskId,
      taskTitle: taskTitle,
      alarmTime: DateTime.now().add(duration),
      soundId: soundId,
      customUri: customUri,
    );
  }

  /// Plays a short sample of the configured alarm sound without stealing the
  /// screen.  Routes through the same in-app audioplayers engine as a real
  /// alarm so the preview always sounds faithful; auto-stops after 6s.
  static Future<void> previewAlarm(AlarmChannelConfig config) async {
    if (kIsWeb) return;
    await AlarmSoundService.playPreview(
      soundId: config.sound.name,
      customUri: config.sound == PyloAlarmSound.custom
          ? config.customUri
          : null,
    );
  }

  static Future<void> cancelAllForTask(String taskId,
      {List<int>? reminderMinutes}) async {
    if (kIsWeb) {
      return;
    }
    await ensureInitialized();
    try {
      final ids = <int>{NotificationId.taskAlarm(taskId)};
      if (reminderMinutes != null && reminderMinutes.isNotEmpty) {
        for (final m in reminderMinutes) {
          ids.add(NotificationId.taskReminder(taskId, m));
        }
      }
      for (final m in knownReminderOffsets) {
        ids.add(NotificationId.taskReminder(taskId, m));
      }
      // Without the exact minute list, sweep the full 0–1440 range so a
      // removed custom offset can never leave an orphaned notification.
      if (reminderMinutes == null) {
        for (final id in NotificationId.allReminderIds(taskId)) {
          ids.add(id);
        }
      }
      // Deliver cancels in small bounded batches: pushing 1441 cancels in a
      // single Future.wait floods the platform channel and can stall the app.
      final ordered = ids.toList();
      const batchSize = 100;
      for (var start = 0; start < ordered.length; start += batchSize) {
        final end = start + batchSize > ordered.length
            ? ordered.length
            : start + batchSize;
        await Future.wait(
            ordered.sublist(start, end).map(_notifications.cancel));
      }
    } catch (e) {
      debugPrint('Failed to cancel notifications for task $taskId: $e');
    }
  }

  static Future<void> scheduleYearlyReminder({
    required String key,
    required String title,
    required String body,
    required DateTime firstOccurrence,
  }) async {
    if (kIsWeb) {
      return;
    }
    final now = DateTime.now();
    var scheduled = firstOccurrence;
    if (!scheduled.isAfter(now)) {
      final nextYear = now.year + 1;
      // Clamp to the real last day of the target month/year. DateTime()
      // would otherwise silently roll Feb 29 over to Mar 1, turning a
      // Feb-29 birthday into a never-ending Mar-1 reminder.
      final lastDay = DateTime(nextYear, firstOccurrence.month + 1, 0).day;
      final safeDay = firstOccurrence.day.clamp(1, lastDay);
      scheduled = DateTime(nextYear, firstOccurrence.month, safeDay,
          firstOccurrence.hour, firstOccurrence.minute);
    }

    // Birthday IDs use an offset namespace to prevent collisions with task IDs.
    final notificationId = (key.hashCode + NotificationId.birthdayOffset) & 0x7FFFFFFF;

    try {
      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        _toTZDate(scheduled),
        _details(_birthdayDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
      debugPrint('Scheduled yearly reminder "$title" at $scheduled');
    } catch (e) {
      debugPrint('Exact yearly schedule failed for "$title" ($e); retrying inexact');
      try {
        await _notifications.zonedSchedule(
          notificationId,
          title,
          body,
          _toTZDate(scheduled),
          _details(_birthdayDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
      } catch (e2) {
        debugPrint('Failed to schedule yearly reminder "$title": $e2');
      }
    }
  }

  static Future<void> scheduleBirthdayReminders({
    required String birthdayId,
    required String name,
    required DateTime nextBirthday,
    required List<int> reminderDaysBefore,
    int reminderHour = 9,
    int reminderMinute = 0,
  }) async {
    if (kIsWeb) {
      return;
    }
    final now = DateTime.now();

    await cancelAllForBirthday(birthdayId);

    final dateStr =
        '${nextBirthday.day}/${nextBirthday.month}';

    for (final days in reminderDaysBefore) {
      // Build the scheduled DateTime with the user's chosen reminder time.
      final reminderDate = DateTime(
        nextBirthday.year,
        nextBirthday.month,
        nextBirthday.day,
        reminderHour,
        reminderMinute,
      ).subtract(Duration(days: days));

      final body = days == 0
          ? "🎉 Today is $name's birthday! ($dateStr)"
          : days == 1
              ? "🎂 $name's birthday is tomorrow! ($dateStr)"
              : "🎂 $name's birthday in $days days ($dateStr)";

      // When the requested lead time has already passed but the birthday
      // itself is still ahead, schedule on the birthday instead of letting
      // scheduleYearlyReminder push the reminder a full year out (which would
      // silently skip this whole cycle).
      var firstOccurrence = reminderDate;
      if (!firstOccurrence.isAfter(now)) {
        firstOccurrence = DateTime(
          nextBirthday.year,
          nextBirthday.month,
          nextBirthday.day,
          reminderHour,
          reminderMinute,
        );
      }

      // Stable id per (birthday, offset): re-scheduling overwrites the
      // previous year's notification instead of stacking a new one each
      // year, and cancelAllForBirthday can always find it.
      await scheduleYearlyReminder(
        key: '$birthdayId-$days',
        // Offset birthday IDs into a separate namespace to avoid collisions
        // with task reminder IDs that use raw hashCode.
        title: days == 0 ? 'Birthday Today 🎂' : 'Birthday Reminder 🎂',
        body: body,
        firstOccurrence: firstOccurrence,
      );
    }
  }

  static Future<void> cancelAllForBirthday(String birthdayId) async {
    if (kIsWeb) {
      return;
    }
    // Batch cancel: cancel current year IDs and legacy year IDs concurrently.
    // Birthday IDs use the offset namespace.
    final cancelFutures = <Future<void>>[];
    for (final days in [0, 1, 3, 7]) {
      final id = (('$birthdayId-$days'.hashCode) + NotificationId.birthdayOffset) & 0x7FFFFFFF;
      cancelFutures.add(_notifications.cancel(id));
      // Legacy ids (older builds) included a birth-year suffix.
      final now = DateTime.now();
      for (var year = now.year - 2; year <= now.year + 2; year++) {
        final legacyId = (('$birthdayId-$days-$year'.hashCode) + NotificationId.birthdayOffset) & 0x7FFFFFFF;
        cancelFutures.add(_notifications.cancel(legacyId));
      }
    }
    await Future.wait(cancelFutures);
  }

  static Future<void> showFocusOngoing({
    required String label,
    required DateTime endTime,
    required bool isStrict,
  }) async {
    if (kIsWeb) return;
    final remaining = endTime.difference(DateTime.now());
    final mins = remaining.inMinutes;
    try {
      await _notifications.show(
        FocusNotificationIds.ongoing,
        isStrict ? '🔒 Strict Focus' : '🎯 Focus Mode',
        mins > 0 ? '$label • $mins min remaining' : '$label • finishing…',
        _details(_focusDetails),
      );
    } catch (e) {
      debugPrint('Focus notification failed: $e');
    }
  }

  static Future<void> scheduleFocusComplete({
    required String label,
    required DateTime endTime,
  }) async {
    if (kIsWeb) return;
    try {
      await _notifications.zonedSchedule(
        FocusNotificationIds.complete,
        '🎉 Focus Complete!',
        'Nice work — $label session finished.',
        _toTZDate(endTime),
        _details(_androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule focus completion: $e');
    }
  }

  static Future<void> cancelFocusNotifications() async {
    if (kIsWeb) return;
    await _notifications.cancel(FocusNotificationIds.ongoing);
    await _notifications.cancel(FocusNotificationIds.complete);
  }

  static Future<void> cancel(int id) async {
    if (kIsWeb) {
      return;
    }
    await _notifications.cancel(id);
  }

  static tz.TZDateTime _toTZDate(DateTime date) {
    return tz.TZDateTime.from(date, tz.local);
  }

  /// Shared zonedSchedule for use by NotificationService and other callers.
  static Future<void> zonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDate,
    NotificationDetails details, {
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (kIsWeb) return;
    await ensureInitialized();
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (e) {
      debugPrint('Exact zonedSchedule failed id=$id ($e); retrying inexact');
      try {
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchDateTimeComponents,
        );
      } catch (e2) {
        debugPrint('Failed to zonedSchedule id=$id: $e2');
      }
    }
  }

  /// Cancel all notifications across all channels.
  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    await ensureInitialized();
    await _notifications.cancelAll();
  }

  /// Request notification permissions (iOS).
  static Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    await ensureInitialized();
    final platform = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (platform != null) {
      final permissions = await platform.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return permissions != null;
    }
    return true;
  }

  /// Check if SCHEDULE_EXACT_ALARM permission is granted on Android 12+.
  /// Returns true on non-Android or older Android versions.
  static Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb) return true;
    await ensureInitialized();
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true;
    final areNotificationsEnabled = await androidImpl.areNotificationsEnabled();
    // On Android 12+ (API 31+), exact alarms require explicit permission.
    // flutter_local_notifications v17 handles this via requestExactAlarmsPermission().
    // If the user denied it, scheduled alarms will use inexact mode.
    return areNotificationsEnabled ?? true;
  }

  /// Android 12+: asks the user for the special "full-screen intent alarms"
  /// access that lets a fired alarm take over the whole screen.
  static Future<bool?> requestFullScreenAlarmPermission() async {
    if (kIsWeb) return null;
    await ensureInitialized();
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidImpl?.requestFullScreenIntentPermission();
  }
}

class FocusNotificationIds {
  static const ongoing = 910001;
  static const complete = 910002;
}