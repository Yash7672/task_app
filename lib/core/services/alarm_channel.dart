import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native bridge to the task-alarm pipeline held by MainActivity's
/// `pylo/alarm` MethodChannel. The actual ringing is done entirely inside
/// Android (AlarmManager exact alarm → AlarmActivity) so a task alarm fires
/// and rings whether the Flutter app is open, backgrounded, or dead — it is
/// never chained to a notification tap.
///
/// The global sound / vibration / snooze settings are read by the native side
/// at ring time from the shared_preferences plugin store, so changing a
/// pref here always affects the next ring without re-scheduling anything.
class AlarmChannel {
  AlarmChannel._();

  static const MethodChannel _channel = MethodChannel('pylo/alarm');

  /// Arms a task alarm at [alarmTime]. Uses the deterministic
  /// `NotificationId.taskAlarm(taskId)` request code so cancels always find
  /// it. Returns true when a real EXACT alarm was armed (best-effort inexact
  /// otherwise), matching the SCHEDULE_EXACT_ALARM permission state.
  static Future<bool> schedule({
    required int requestCode,
    required DateTime alarmTime,
    required String taskId,
    required String taskTitle,
  }) async {
    try {
      final exact = await _channel.invokeMethod<bool>('scheduleAlarm', {
        'requestCode': requestCode,
        'timeMs': alarmTime.millisecondsSinceEpoch,
        'taskId': taskId,
        'title': taskTitle,
      });
      return exact ?? false;
    } catch (e) {
      debugPrint('AlarmChannel.schedule failed: $e');
      return false;
    }
  }

  static Future<void> cancel({required int requestCode}) async {
    try {
      await _channel.invokeMethod('cancelAlarm', {
        'requestCode': requestCode,
      });
    } catch (e) {
      debugPrint('AlarmChannel.cancel failed: $e');
    }
  }

  /// Whether Android can arm exact alarms (Android 12+ special access; always
  /// true on older versions).
  static Future<bool> canScheduleExactAlarms() async {
    try {
      final result = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the system "Alarms & reminders" screen so the user can grant exact
  /// alarm access (Android 12+). No-op on older versions.
  static Future<void> openExactAlarmSettings() async {
    try {
      await _channel.invokeMethod('openExactAlarmSettings');
    } catch (e) {
      debugPrint('AlarmChannel.openExactAlarmSettings failed: $e');
    }
  }
}