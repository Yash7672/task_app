import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/focus_channel.dart';
import '../../core/utils/notification_helper.dart';
import '../../database/database_helper.dart';
import '../../models/focus_session_model.dart';

class ActiveFocus {
  final String label;
  final String? taskId;
  final DateTime startTime;
  final DateTime endTime;
  final int plannedMinutes;
  final FocusMode mode;

  const ActiveFocus({
    required this.label,
    this.taskId,
    required this.startTime,
    required this.endTime,
    required this.plannedMinutes,
    this.mode = FocusMode.normal,
  });

  Duration get remaining => endTime.difference(DateTime.now());

  bool get isExpired => remaining.isNegative;

  double get progress {
    final total = endTime.difference(startTime).inMilliseconds;
    if (total <= 0) return 1;
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

class FocusService {
  static const _keyLabel = 'focus_label';
  static const _keyTaskId = 'focus_task_id';
  static const _keyStartMs = 'focus_start_ms';
  static const _keyEndMs = 'focus_end_ms';
  static const _keyMinutes = 'focus_planned_minutes';
  static const _keyMode = 'focus_mode';
  static const _keyStrictPref = 'focus_strict_mode_pref';

  Future<bool> isStrictMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyStrictPref) ?? false;
  }

  Future<void> setStrictMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyStrictPref, value);
  }

  Future<ActiveFocus?> loadActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final label = prefs.getString(_keyLabel);
    final startMs = prefs.getInt(_keyStartMs);
    final endMs = prefs.getInt(_keyEndMs);
    final minutes = prefs.getInt(_keyMinutes) ?? 25;

    if (label == null || startMs == null || endMs == null) return null;

    final session = ActiveFocus(
      label: label,
      taskId: prefs.getString(_keyTaskId),
      startTime: DateTime.fromMillisecondsSinceEpoch(startMs),
      endTime: DateTime.fromMillisecondsSinceEpoch(endMs),
      plannedMinutes: minutes,
      mode: FocusMode.fromName(prefs.getString(_keyMode)),
    );

    if (session.isExpired) {
      await _finalize(session, completed: true);
      return null;
    }

    // If restoring a strict session, re-enter lock task and set lock screen flags.
    if (session.mode == FocusMode.strict) {
      await FocusChannel.enterLockTask();
      await FocusChannel.setLockScreenFlags(true);
    }

    return session;
  }

  Future<ActiveFocus> startFocus({
    required String label,
    String? taskId,
    required int minutes,
    required FocusMode mode,
  }) async {
    final now = DateTime.now();
    final session = ActiveFocus(
      label: label,
      taskId: taskId,
      startTime: now,
      endTime: now.add(Duration(minutes: minutes)),
      plannedMinutes: minutes,
      mode: mode,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLabel, session.label);
    if (taskId != null) {
      await prefs.setString(_keyTaskId, taskId);
    } else {
      await prefs.remove(_keyTaskId);
    }
    await prefs.setInt(_keyStartMs, session.startTime.millisecondsSinceEpoch);
    await prefs.setInt(_keyEndMs, session.endTime.millisecondsSinceEpoch);
    await prefs.setInt(_keyMinutes, minutes);
    await prefs.setString(_keyMode, mode.name);

    if (mode == FocusMode.strict) {
      // Ensure phone state permission so we can detect calls and
      // temporarily release Lock Task mode to let Android's normal
      // call UI handle incoming calls.
      await FocusChannel.requestPhoneStatePermission();
      // Enter Android Lock Task mode and set lock screen flags.
      await FocusChannel.enterLockTask();
      await FocusChannel.setLockScreenFlags(true);
    }

    await NotificationHelper.showFocusOngoing(
      label: label,
      endTime: session.endTime,
      isStrict: mode == FocusMode.strict,
    );
    await NotificationHelper.scheduleFocusComplete(
      label: label,
      endTime: session.endTime,
    );

    return session;
  }

  Future<void> stopFocus(ActiveFocus session, {bool completed = false}) async {
    if (session.mode == FocusMode.strict) {
      // Exit Android Lock Task mode and clear lock screen flags.
      await FocusChannel.exitLockTask();
      await FocusChannel.setLockScreenFlags(false);
    }
    await _finalize(session, completed: completed);
  }

  Future<void> _finalize(ActiveFocus session,
      {required bool completed}) async {
    try {
      final now = DateTime.now();
      final effectiveEnd =
          now.isBefore(session.endTime) ? now : session.endTime;
      await DatabaseHelper.instance.createFocusSession(
        FocusSession(
          taskId: session.taskId,
          label: session.label,
          startTime: session.startTime,
          endTime: effectiveEnd,
          plannedMinutes: session.plannedMinutes,
          completed: completed,
          mode: session.mode,
        ),
      );
      // Only clear prefs after successful DB write to prevent data loss.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLabel);
      await prefs.remove(_keyTaskId);
      await prefs.remove(_keyStartMs);
      await prefs.remove(_keyEndMs);
      await prefs.remove(_keyMinutes);
      await prefs.remove(_keyMode);
    } catch (e) {
      debugPrint('Failed to save focus session: $e');
    }

    await NotificationHelper.cancelFocusNotifications();
  }
}
