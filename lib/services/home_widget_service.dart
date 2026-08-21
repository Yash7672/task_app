import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/task_model.dart';

class HomeWidgetService {
  static const _androidProviderName =
      'com.example.task_app.PyloHomeWidgetProvider';
  static const _appGroupId = 'pylo.home_widget';

  static bool _initialized = false;
  static Timer? _debounce;
  static List<Task> _todayTasks = const [];
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

  static void refreshTasks(List<Task> allTasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _todayTasks = allTasks
        .where((t) =>
            !t.isDeleted &&
            !t.isArchived &&
            DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day)
                .isAtSameMomentAs(today))
        .toList();
    _scheduleFlush();
  }

  static void refreshHabits(int bestStreak) {
    _bestStreak = bestStreak;
    _scheduleFlush();
  }

  static void _scheduleFlush() {
    if (kIsWeb) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(_flush());
    });
  }

  static Future<void> _flush() async {
    try {
      await init();

      final active = _todayTasks.where((t) => !t.isCompleted).toList();
      final done = _todayTasks.where((t) => t.isCompleted).length;

      await HomeWidget.saveWidgetData<int>('task_count', active.length);
      await HomeWidget.saveWidgetData<int>('done_count', done);
      await HomeWidget.saveWidgetData<int>('best_streak', _bestStreak);

      for (var i = 0; i < 5; i++) {
        final title = i < active.length ? active[i].title : '';
        await HomeWidget.saveWidgetData<String>('task_$i', title);
      }

      await HomeWidget.updateWidget(
        androidName: _androidProviderName,
        qualifiedAndroidName: _androidProviderName,
      );
    } catch (e) {
      debugPrint('HomeWidget update failed: $e');
    }
  }
}
