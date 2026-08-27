import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/habit_model.dart';
import '../models/task_model.dart';

class HomeWidgetService {
  static const _androidProviderName =
      'com.example.task_app.PyloHomeWidgetProvider';
  static const _habitsProviderName =
      'com.example.task_app.PyloHabitsWidgetProvider';
  static const _progressProviderName =
      'com.example.task_app.PyloProgressWidgetProvider';
  static const _quickAddProviderName =
      'com.example.task_app.PyloQuickAddWidgetProvider';
  static const _appGroupId = 'pylo.home_widget';

  static bool _initialized = false;
  static Timer? _debounce;

  static List<Task> _todayTasks = const [];
  static List<Habit> _habits = const [];
  static int _bestStreak = 0;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      _initialized = true;
    } catch (e) {
      debugPrint('HomeWidget init failed: $e');
    }
  }

  // ── Task data ──────────────────────────────────────────────────────

  static void refreshTasks(List<Task> allTasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _todayTasks = allTasks
        .where((t) =>
            !t.isDeleted &&
            !t.isArchived &&
            !today.isBefore(
                DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day)))
        .toList();
    _scheduleFlush();
  }

  // ── Habit data ─────────────────────────────────────────────────────

  static void refreshHabits(int bestStreak, {List<Habit>? habits}) {
    _bestStreak = bestStreak;
    if (habits != null) _habits = habits;
    _scheduleFlush();
  }

  // ── Immediate push ─────────────────────────────────────────────────

  static Future<void> pushNow() async {
    if (kIsWeb) return;
    await init();
    await _flush();
  }

  // ── Widget pinning ─────────────────────────────────────────────────

  static Future<void> requestPinWidget() async {
    if (kIsWeb) return;
    try {
      await init();
      await HomeWidget.requestPinWidget(
        androidName: 'PyloHomeWidgetProvider',
        qualifiedAndroidName: _androidProviderName,
      );
    } catch (e) {
      debugPrint('HomeWidget pin request failed: $e');
    }
  }

  static Future<void> requestPinHabitsWidget() async {
    if (kIsWeb) return;
    try {
      await init();
      await HomeWidget.requestPinWidget(
        androidName: 'PyloHabitsWidgetProvider',
        qualifiedAndroidName: _habitsProviderName,
      );
    } catch (e) {
      debugPrint('HomeWidget pin habits failed: $e');
    }
  }

  static Future<void> requestPinProgressWidget() async {
    if (kIsWeb) return;
    try {
      await init();
      await HomeWidget.requestPinWidget(
        androidName: 'PyloProgressWidgetProvider',
        qualifiedAndroidName: _progressProviderName,
      );
    } catch (e) {
      debugPrint('HomeWidget pin progress failed: $e');
    }
  }

  static Future<void> requestPinQuickAddWidget() async {
    if (kIsWeb) return;
    try {
      await init();
      await HomeWidget.requestPinWidget(
        androidName: 'PyloQuickAddWidgetProvider',
        qualifiedAndroidName: _quickAddProviderName,
      );
    } catch (e) {
      debugPrint('HomeWidget pin quick add failed: $e');
    }
  }

  // ── Debounced flush ────────────────────────────────────────────────

  static void _scheduleFlush() {
    if (kIsWeb) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(_flush());
    });
  }

  // ── Core data push to SharedPreferences ────────────────────────────

  static Future<void> _flush() async {
    try {
      await init();

      // ── Today Tasks widget data ──
      final active = _todayTasks.where((t) => !t.isCompleted).toList();
      final completed = _todayTasks.where((t) => t.isCompleted).toList();
      final totalToday = _todayTasks.length;
      final doneCount = completed.length;
      final pendingCount = active.length;

      await HomeWidget.saveWidgetData<int>('tasks_total', totalToday);
      await HomeWidget.saveWidgetData<int>('tasks_done', doneCount);
      await HomeWidget.saveWidgetData<int>('tasks_pending', pendingCount);

      for (var i = 0; i < 5; i++) {
        if (i < active.length) {
          await HomeWidget.saveWidgetData<String>('tasks_title_$i', active[i].title);
          await HomeWidget.saveWidgetData<String>('tasks_id_$i', active[i].id);
          await HomeWidget.saveWidgetData<bool>('tasks_done_$i', false);
        } else {
          await HomeWidget.saveWidgetData<String>('tasks_title_$i', '');
          await HomeWidget.saveWidgetData<String>('tasks_id_$i', '');
        }
      }

      if (active.length > 5) {
        await HomeWidget.saveWidgetData<int>('tasks_more', active.length - 5);
      } else {
        await HomeWidget.saveWidgetData<int>('tasks_more', 0);
      }

      await HomeWidget.saveWidgetData<int>('best_streak', _bestStreak);
      await HomeWidget.saveWidgetData<String>(
          'tasks_last_updated', DateTime.now().millisecondsSinceEpoch.toString());

      // ── Habits widget data ──
      await HomeWidget.saveWidgetData<int>('habits_best_streak', _bestStreak);
      await HomeWidget.saveWidgetData<int>('habits_count', _habits.length);

      for (var i = 0; i < 5; i++) {
        if (i < _habits.length) {
          final h = _habits[i];
          await HomeWidget.saveWidgetData<String>('habits_name_$i', h.name);
          await HomeWidget.saveWidgetData<String>('habits_id_$i', h.id);
          await HomeWidget.saveWidgetData<int>(
              'habits_streak_$i', h.effectiveCurrentStreak());
          await HomeWidget.saveWidgetData<bool>('habits_done_$i', h.isCompletedToday);
        } else {
          await HomeWidget.saveWidgetData<String>('habits_name_$i', '');
          await HomeWidget.saveWidgetData<String>('habits_id_$i', '');
        }
      }

      await HomeWidget.saveWidgetData<String>(
          'habits_last_updated', DateTime.now().millisecondsSinceEpoch.toString());

      // ── Progress widget data ──
      final percent = totalToday > 0 ? ((doneCount / totalToday) * 100).round() : 0;
      await HomeWidget.saveWidgetData<int>('progress_total', totalToday);
      await HomeWidget.saveWidgetData<int>('progress_done', doneCount);
      await HomeWidget.saveWidgetData<int>('progress_percent', percent);
      await HomeWidget.saveWidgetData<int>('progress_remaining', pendingCount);
      await HomeWidget.saveWidgetData<String>(
          'progress_last_updated', DateTime.now().millisecondsSinceEpoch.toString());

      // ── Update all widget types ──
      await _updateAllWidgets();
    } catch (e) {
      debugPrint('HomeWidget flush failed: $e');
    }
  }

  static Future<void> _updateAllWidgets() async {
    final providers = [
      _androidProviderName,
      _habitsProviderName,
      _progressProviderName,
      _quickAddProviderName,
    ];
    for (final name in providers) {
      try {
        await HomeWidget.updateWidget(
          androidName: name,
          qualifiedAndroidName: name,
        );
      } catch (e) {
        debugPrint('HomeWidget update $name failed: $e');
      }
    }
  }

  // ── Task completion from widget ────────────────────────────────────

  static Future<String?> getWidgetAction() async {
    if (kIsWeb) return null;
    try {
      await init();
      return await HomeWidget.getWidgetData<String>('widget_action');
    } catch (e) {
      debugPrint('HomeWidget getWidgetAction failed: $e');
      return null;
    }
  }

  static Future<String?> getWidgetTaskId() async {
    if (kIsWeb) return null;
    try {
      await init();
      return await HomeWidget.getWidgetData<String>('widget_task_id');
    } catch (e) {
      debugPrint('HomeWidget getWidgetTaskId failed: $e');
      return null;
    }
  }

  static Future<void> clearWidgetAction() async {
    if (kIsWeb) return;
    try {
      await init();
      await HomeWidget.saveWidgetData<String>('widget_action', '');
      await HomeWidget.saveWidgetData<String>('widget_task_id', '');
    } catch (e) {
      debugPrint('HomeWidget clearWidgetAction failed: $e');
    }
  }

  // ── Convenience: refresh everything ────────────────────────────────

  static Future<void> refreshAll({
    required List<Task> tasks,
    required List<Habit> habits,
    required int bestStreak,
  }) async {
    refreshTasks(tasks);
    refreshHabits(bestStreak, habits: habits);
  }
}
