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

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const NotificationDetails details = NotificationDetails(
      android: _androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(id, title, body, details, payload: payload);
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

    const details = NotificationDetails(
      android: _androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        _toTZDate(scheduledDate),
        details,
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

    debugPrint('Scheduling ${reminderMinutes.length} reminders for "$taskTitle" at $taskDateTime');

    for (int i = 0; i < reminderMinutes.length; i++) {
      final minutes = reminderMinutes[i];
      final scheduledDate = taskDateTime.subtract(Duration(minutes: minutes));
      final now = DateTime.now();
      if (!scheduledDate.isAfter(now)) {
        debugPrint('Skipping ${minutes}min reminder: $scheduledDate is past (now=$now)');
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
    for (int i = 0; i < maxReminders; i++) {
      await _notifications.cancel(taskId.hashCode + i);
    }
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
