import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Idempotent: safe to call before every scheduling call. The settings
  /// screen uses this service directly without going through
  /// [NotificationHelper.init], so lazy init is required for the daily
  /// habit reminder to actually fire.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      debugPrint('Timezone init failed: $e');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
    _initialized = true;

    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return false;
    try {
      await initialize();
      await _notifications.cancel(0);

      final scheduledTime = tz.TZDateTime(
        tz.local,
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        hour,
        minute,
      );

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = scheduledTime;
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'habit_reminder_channel',
        'Habit Reminders',
        channelDescription: 'Daily reminder to complete your habits',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        sound: 'default.wav',
      );

      const platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        0,
        '⏰ Time to complete your habits!',
        'Don\'t break your streak! Open the app and mark your progress.',
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      await showImmediateNotification(
        '✅ Reminder Set!',
        'You will get daily reminders at ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      );

      return true;
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      return false;
    }
  }

  static Future<void> showImmediateNotification(
      String title, String body) async {
    if (kIsWeb) return;
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      'habit_reminder_channel',
      'Habit Reminders',
      channelDescription: 'Daily reminder to complete your habits',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );

    const iosDetails = DarwinNotificationDetails(
      sound: 'default.wav',
    );

    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      title,
      body,
      platformDetails,
    );
  }

  static Future<void> sendStreakNotification({
    required String habitName,
    required int streakCount,
  }) async {
    if (kIsWeb) return;
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      'streak_channel',
      'Streak Updates',
      channelDescription: 'Celebrate your streak achievements!',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      sound: 'default.wav',
    );

    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final message = streakCount >= 30
        ? '🔥 Amazing! $streakCount day streak! You\'re on fire!'
        : streakCount >= 10
            ? '🌟 $streakCount day streak! Keep going!'
            : '✅ $streakCount day streak! You\'re building a great habit!';

    await _notifications.show(
      2,
      '🎉 Streak Update: $habitName',
      message,
      platformDetails,
    );
  }

  static Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await initialize();
    await _notifications.cancelAll();
  }

  static Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    await initialize();
    await _notifications.cancel(0);
  }

  static Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await initialize();
    await _notifications.cancel(id);
  }

  static Future<bool> checkPermissions() async {
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
}
