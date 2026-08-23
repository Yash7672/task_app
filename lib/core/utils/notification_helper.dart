import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'taskflow_channel',
    'TaskFlow Notifications',
    channelDescription: 'Reminders for your tasks',
    importance: Importance.max,
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

  static Future<void> init() async {
    if (kIsWeb) {
      return;
    }

    tz_data.initializeTimeZones();
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

    await _notifications.initialize(settings);

    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  static NotificationDetails _details(AndroidNotificationDetails android) {
    return NotificationDetails(
      android: android,
      iOS: const DarwinNotificationDetails(),
    );
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
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
    final now = DateTime.now();
    if (!scheduledDate.isAfter(now)) {
      debugPrint('Skipping reminder id=$id: $scheduledDate is in the past (now=$now)');
      return;
    }

    try {
      await _notifications.zonedSchedule(
        id,
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
      debugPrint('Failed to schedule reminder id=$id: $e');
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

    for (int i = 0; i < reminderMinutes.length; i++) {
      final minutes = reminderMinutes[i];
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

      await scheduleTaskReminder(
        id: taskId.hashCode + i,
        title: 'Task Reminder',
        body: body,
        scheduledDate: scheduledDate,
      );
    }
  }

  static Future<void> cancelAllForTask(String taskId) async {
    if (kIsWeb) {
      return;
    }
    const maxReminders = 12;
    try {
      for (int i = 0; i < maxReminders; i++) {
        await _notifications.cancel(taskId.hashCode + i);
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
      scheduled = DateTime(now.year + 1, firstOccurrence.month,
          firstOccurrence.day, firstOccurrence.hour, firstOccurrence.minute);
    }

    try {
      await _notifications.zonedSchedule(
        key.hashCode,
        title,
        body,
        _toTZDate(scheduled),
        _details(_birthdayDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule yearly reminder "$title": $e');
    }
  }

  static Future<void> scheduleBirthdayReminders({
    required String birthdayId,
    required String name,
    required DateTime nextBirthday,
    required List<int> reminderDaysBefore,
  }) async {
    if (kIsWeb) {
      return;
    }

    await cancelAllForBirthday(birthdayId);

    final dateStr =
        '${nextBirthday.day}/${nextBirthday.month}';

    for (final days in reminderDaysBefore) {
      final when = nextBirthday.subtract(Duration(days: days));
      final body = days == 0
          ? "🎉 Today is $name's birthday! ($dateStr)"
          : days == 1
              ? "🎂 $name's birthday is tomorrow! ($dateStr)"
              : "🎂 $name's birthday in $days days ($dateStr)";

      // Stable id per (birthday, offset): re-scheduling overwrites the
      // previous year's notification instead of stacking a new one each
      // year, and cancelAllForBirthday can always find it.
      await scheduleYearlyReminder(
        key: '$birthdayId-$days',
        title: days == 0 ? 'Birthday Today 🎂' : 'Birthday Reminder 🎂',
        body: body,
        firstOccurrence: when,
      );
    }
  }

  static Future<void> cancelAllForBirthday(String birthdayId) async {
    if (kIsWeb) {
      return;
    }
    for (final days in [0, 1, 3, 7]) {
      await _notifications.cancel('$birthdayId-$days'.hashCode);
      // Legacy ids (older builds) included a birth-year suffix.
      for (var year = DateTime.now().year - 2;
          year <= DateTime.now().year + 2;
          year++) {
        await _notifications.cancel('$birthdayId-$days-$year'.hashCode);
      }
    }
  }

  static Future<void> showFocusOngoing({
    required String label,
    required DateTime endTime,
  }) async {
    if (kIsWeb) return;
    final remaining = endTime.difference(DateTime.now());
    final mins = remaining.inMinutes;
    try {
      await _notifications.show(
        FocusNotificationIds.ongoing,
        '🎯 Focus Mode',
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
}

class FocusNotificationIds {
  static const ongoing = 910001;
  static const complete = 910002;
}
