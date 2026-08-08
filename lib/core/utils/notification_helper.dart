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
    importance: Importance.high,
    priority: Priority.high,
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
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);

    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
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
      return;
    }

    const details = NotificationDetails(
      android: _androidDetails,
      iOS: DarwinNotificationDetails(),
    );

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
