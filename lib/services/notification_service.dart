import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

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
    try {
      await _notifications.cancelAll();

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
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        sound: 'default.wav',
      );

      const platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.periodicallyShow(
        0,
        '⏰ Time to complete your habits!',
        'Don\'t break your streak! Open the app and mark your progress.',
        RepeatInterval.daily,
        platformDetails,
        androidAllowWhileIdle: true,
      );

      await showImmediateNotification(
        '✅ Reminder Set!',
        'You will get daily reminders at ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      );

      return true;
    } catch (e) {
      print('Error scheduling notification: $e');
      return false;
    }
  }

  static Future<void> showImmediateNotification(
      String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'habit_reminder_channel',
      'Habit Reminders',
      channelDescription: 'Daily reminder to complete your habits',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
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
    await _notifications.cancelAll();
  }

  static Future<void> cancelNotification(int id) async {
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
