import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/notification_helper.dart';

/// Thin wrapper around [NotificationHelper] for habit-related notifications.
/// All heavy lifting (plugin init, timezone, permissions) is handled by
/// [NotificationHelper.init] — this class only provides convenience methods
/// for the settings screen and habit reminders.
class NotificationService {
  /// No-op: initialization is handled by [NotificationHelper.init].
  /// Kept for call-site compatibility (settings screen, providers).
  static Future<void> initialize() async => NotificationHelper.ensureInitialized();

  static Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return false;
    try {
      await NotificationHelper.ensureInitialized();
      await NotificationHelper.cancel(0);

      final now = DateTime.now();
      final scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      final tzNow = tz.TZDateTime.now(tz.local);
      var scheduledDate = scheduledTime;
      if (scheduledDate.isBefore(tzNow)) {
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

      await NotificationHelper.zonedSchedule(
        0,
        '⏰ Time to complete your habits!',
        'Don\'t break your streak! Open the app and mark your progress.',
        scheduledDate,
        platformDetails,
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
    await NotificationHelper.ensureInitialized();
    await NotificationHelper.show(id: 1, title: title, body: body);
  }

  static Future<void> sendStreakNotification({
    required String habitName,
    required int streakCount,
  }) async {
    if (kIsWeb) return;
    await NotificationHelper.ensureInitialized();

    final message = streakCount >= 30
        ? '🔥 Amazing! $streakCount day streak! You\'re on fire!'
        : streakCount >= 10
            ? '🌟 $streakCount day streak! Keep going!'
            : '✅ $streakCount day streak! You\'re building a great habit!';

    await NotificationHelper.show(
      id: 2,
      title: '🎉 Streak Update: $habitName',
      body: message,
    );
  }

  static Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await NotificationHelper.ensureInitialized();
    await NotificationHelper.cancelAll();
  }

  static Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    await NotificationHelper.ensureInitialized();
    await NotificationHelper.cancel(0);
  }

  static Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await NotificationHelper.ensureInitialized();
    await NotificationHelper.cancel(id);
  }

  static Future<bool> checkPermissions() async {
    return NotificationHelper.requestPermissions();
  }
}
