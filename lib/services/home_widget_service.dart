import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/birthday_model.dart';
import '../models/checklist_model.dart';
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
  static const _focusProviderName =
      'com.example.task_app.PyloFocusWidgetProvider';
  static const _checklistProviderName =
      'com.example.task_app.PyloChecklistWidgetProvider';
  static const _birthdaysProviderName =
      'com.example.task_app.PyloBirthdaysWidgetProvider';
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

  static Future<void> requestPinFocusWidget() async {
    if (kIsWeb) return;
    try {
      await init();
      await HomeWidget.requestPinWidget(
        androidName: 'PyloFocusWidgetProvider',
        qualifiedAndroidName: _focusProviderName,
      );
    } catch (e) {
      debugPrint('HomeWidget pin focus failed: $e');
    }
  }

  static Future<void> requestPinChecklistWidget() async {
    if (kIsWeb) return;
    try {
      await init();
      await HomeWidget.requestPinWidget(
        androidName: 'PyloChecklistWidgetProvider',
        qualifiedAndroidName: _checklistProviderName,
      );
    } catch (e) {
      debugPrint('HomeWidget pin checklist failed: $e');
    }
  }

  static Future<void> requestPinBirthdaysWidget() async {
    if (kIsWeb) return;
    try {
      await init();
      await HomeWidget.requestPinWidget(
        androidName: 'PyloBirthdaysWidgetProvider',
        qualifiedAndroidName: _birthdaysProviderName,
      );
    } catch (e) {
      debugPrint('HomeWidget pin birthdays failed: $e');
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
      // Show pending tasks first (actionable), then completed
      final pendingTasks = _todayTasks.where((t) => !t.isCompleted).toList();
      final completedTasks = _todayTasks.where((t) => t.isCompleted).toList();
      final allDisplayTasks = [...pendingTasks, ...completedTasks];
      final totalToday = _todayTasks.length;
      final doneCount = completedTasks.length;
      final pendingCount = pendingTasks.length;

      await HomeWidget.saveWidgetData<int>('tasks_total', totalToday);
      await HomeWidget.saveWidgetData<int>('tasks_done', doneCount);
      await HomeWidget.saveWidgetData<int>('tasks_pending', pendingCount);

      for (var i = 0; i < 5; i++) {
        if (i < allDisplayTasks.length) {
          final t = allDisplayTasks[i];
          await HomeWidget.saveWidgetData<String>('tasks_title_$i', t.title);
          await HomeWidget.saveWidgetData<String>('tasks_id_$i', t.id);
          await HomeWidget.saveWidgetData<bool>('tasks_done_$i', t.isCompleted);
        } else {
          await HomeWidget.saveWidgetData<String>('tasks_title_$i', '');
          await HomeWidget.saveWidgetData<String>('tasks_id_$i', '');
        }
      }

      if (allDisplayTasks.length > 5) {
        await HomeWidget.saveWidgetData<int>('tasks_more', allDisplayTasks.length - 5);
      } else {
        await HomeWidget.saveWidgetData<int>('tasks_more', 0);
      }

      await HomeWidget.saveWidgetData<int>('best_streak', _bestStreak);
      await HomeWidget.saveWidgetData<String>(
          'tasks_last_updated', DateTime.now().millisecondsSinceEpoch.toString());

      // ── Habits widget data ──
      final habitsCompletedToday = _habits.where((h) => h.isCompletedToday).length;
      await HomeWidget.saveWidgetData<int>('habits_best_streak', _bestStreak);
      await HomeWidget.saveWidgetData<int>('habits_count', _habits.length);
      await HomeWidget.saveWidgetData<int>('habits_completed_today', habitsCompletedToday);

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
      // Also ensure focus/checklist/birthday widgets have default data
      // so they can inflate their initial layout without crash
      final existingFocusActive = await HomeWidget.getWidgetData<bool>('focus_active');
      if (existingFocusActive == null) {
        await HomeWidget.saveWidgetData<bool>('focus_active', false);
        await HomeWidget.saveWidgetData<String>('focus_label', '');
        await HomeWidget.saveWidgetData<int>('focus_remaining_minutes', 0);
        await HomeWidget.saveWidgetData<int>('focus_remaining_seconds', 0);
        await HomeWidget.saveWidgetData<bool>('focus_strict', false);
      }
      await HomeWidget.saveWidgetData<String>('checklist_title', '');
      await HomeWidget.saveWidgetData<int>('checklist_count', 0);
      await HomeWidget.saveWidgetData<int>('birthdays_count', 0);

      await _updateAllWidgets();
    } catch (e) {
      debugPrint('HomeWidget flush failed: $e');
    }
  }

  // ── Focus widget data ─────────────────────────────────────────────

  static Future<void> refreshFocus({
    required bool isActive,
    required String label,
    required int remainingMinutes,
    required int remainingSeconds,
    required bool isStrict,
  }) async {
    if (kIsWeb) return;
    try {
      await init();
      await HomeWidget.saveWidgetData<bool>('focus_active', isActive);
      await HomeWidget.saveWidgetData<String>('focus_label', label);
      await HomeWidget.saveWidgetData<int>('focus_remaining_minutes', remainingMinutes);
      await HomeWidget.saveWidgetData<int>('focus_remaining_seconds', remainingSeconds);
      await HomeWidget.saveWidgetData<bool>('focus_strict', isStrict);
      await HomeWidget.saveWidgetData<String>(
          'focus_last_updated', DateTime.now().millisecondsSinceEpoch.toString());
      await HomeWidget.updateWidget(
        androidName: 'PyloFocusWidgetProvider',
        qualifiedAndroidName: _focusProviderName,
      );
    } catch (e) {
      debugPrint('HomeWidget refreshFocus failed: $e');
    }
  }

  // ── Checklist widget data ─────────────────────────────────────────

  static Future<void> refreshChecklist({
    required String title,
    required List<ChecklistItem> items,
  }) async {
    if (kIsWeb) return;
    try {
      await init();
      await HomeWidget.saveWidgetData<String>('checklist_title', title);
      await HomeWidget.saveWidgetData<int>('checklist_count', items.length);

      for (var i = 0; i < 5; i++) {
        if (i < items.length) {
          await HomeWidget.saveWidgetData<String>('checklist_text_$i', items[i].text);
          await HomeWidget.saveWidgetData<bool>('checklist_done_$i', items[i].completed);
        } else {
          await HomeWidget.saveWidgetData<String>('checklist_text_$i', '');
        }
      }

      await HomeWidget.saveWidgetData<String>(
          'checklist_last_updated', DateTime.now().millisecondsSinceEpoch.toString());
      await HomeWidget.updateWidget(
        androidName: 'PyloChecklistWidgetProvider',
        qualifiedAndroidName: _checklistProviderName,
      );
    } catch (e) {
      debugPrint('HomeWidget refreshChecklist failed: $e');
    }
  }

  // ── Birthdays widget data ─────────────────────────────────────────

  static Future<void> refreshBirthdays(List<Birthday> birthdays) async {
    if (kIsWeb) return;
    try {
      await init();
      final now = DateTime.now();
      final upcoming = birthdays
          .where((b) => b.daysUntilNext(now: now) >= 0)
          .toList()
        ..sort((a, b) => a.daysUntilNext(now: now).compareTo(b.daysUntilNext(now: now)));

      await HomeWidget.saveWidgetData<int>('birthdays_count', upcoming.length);

      for (var i = 0; i < 3; i++) {
        if (i < upcoming.length) {
          final b = upcoming[i];
          final days = b.daysUntilNext(now: now);
          final whenText = days == 0
              ? 'Today'
              : days == 1
                  ? 'Tomorrow'
                  : '${b.nextOccurrence(now: now).day} ${_monthName(b.nextOccurrence(now: now).month)}';
          await HomeWidget.saveWidgetData<String>('birthday_name_$i', b.name);
          await HomeWidget.saveWidgetData<String>('birthday_when_$i', whenText);
        } else {
          await HomeWidget.saveWidgetData<String>('birthday_name_$i', '');
          await HomeWidget.saveWidgetData<String>('birthday_when_$i', '');
        }
      }

      await HomeWidget.saveWidgetData<String>(
          'birthdays_last_updated', DateTime.now().millisecondsSinceEpoch.toString());
      await HomeWidget.updateWidget(
        androidName: 'PyloBirthdaysWidgetProvider',
        qualifiedAndroidName: _birthdaysProviderName,
      );
    } catch (e) {
      debugPrint('HomeWidget refreshBirthdays failed: $e');
    }
  }

  static String _monthName(int month) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month];
  }

  // ── Update all widgets ────────────────────────────────────────────

  static Future<void> _updateAllWidgets() async {
    final providers = [
      _androidProviderName,
      _habitsProviderName,
      _progressProviderName,
      _quickAddProviderName,
      _focusProviderName,
      _checklistProviderName,
      _birthdaysProviderName,
    ];
    for (final name in providers) {
      try {
        await HomeWidget.updateWidget(
          androidName: name.split('.').last,
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
