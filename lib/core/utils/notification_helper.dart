import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

/// Notification ID namespace offsets to prevent hash collisions.
/// Tasks use `id.hashCode`, birthdays use `id.hashCode + _birthdayOffset`.
/// This ensures task "abc" and birthday "abc-0" can never share an ID.
class NotificationId {
  static const int birthdayOffset = 500000000;
}

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Upper bound on how many platform notifications one task may own. Must be
  /// identical between the scheduling loop and cancelAllForTask so a
  /// notification can never be scheduled that no cancel path can reach.
  static const int maxReminders = 12;

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

    await _notifications.initialize(settings);
    _initialized = true;

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
    await ensureInitialized();
    try {
      // Cancel all task reminder IDs concurrently.
      // Use consistent positive ID math matching scheduleTaskReminder.
      final cancelFutures = <Future<void>>[];
      for (int i = 0; i < maxReminders; i++) {
        cancelFutures.add(_notifications.cancel((taskId.hashCode + i) & 0x7FFFFFFF));
      }
      await Future.wait(cancelFutures);
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
}

class FocusNotificationIds {
  static const ongoing = 910001;
  static const complete = 910002;
}
