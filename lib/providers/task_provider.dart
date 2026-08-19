import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/habit_model.dart';
import '../models/task_model.dart';
import 'database_provider.dart';

final taskProvider =
    StateNotifierProvider<TaskNotifier, AsyncValue<List<Task>>>((ref) {
  final dbHelper = ref.watch(databaseProvider);
  return TaskNotifier(dbHelper);
});

class TaskNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  final DatabaseHelper dbHelper;

  TaskNotifier(this.dbHelper) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    try {
      state = const AsyncValue.loading();
      final tasks = await dbHelper.getAllTasks(includeArchived: true);
      state = AsyncValue.data(tasks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  List<Task> get _currentTasks => state.maybeWhen(
        data: (tasks) => tasks,
        orElse: () => [],
      );

  void _updateState(List<Task> tasks) {
    state = AsyncValue.data(tasks);
  }

  Future<void> addTask(Task task) async {
    try {
      await dbHelper.createTask(task);
      _updateState([..._currentTasks, task]);
    } catch (e) {
      debugPrint('Error adding task: $e');
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      await dbHelper.updateTask(task);
      final tasks = _currentTasks;
      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        final updated = List<Task>.from(tasks);
        updated[index] = task;
        _updateState(updated);
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  Future<void> archiveTask(String id) async {
    try {
      await dbHelper.archiveTask(id);
      final tasks = _currentTasks;
      final index = tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        final updated = List<Task>.from(tasks);
        updated[index] =
            updated[index].copyWith(isArchived: true, updatedAt: DateTime.now());
        _updateState(updated);
      }
    } catch (e) {
      debugPrint('Error archiving task: $e');
    }
  }

  Future<void> restoreTask(String id) async {
    try {
      await dbHelper.restoreTask(id);
      final tasks = _currentTasks;
      final index = tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        final updated = List<Task>.from(tasks);
        updated[index] = updated[index]
            .copyWith(isArchived: false, isDeleted: false, updatedAt: DateTime.now());
        _updateState(updated);
      }
    } catch (e) {
      debugPrint('Error restoring task: $e');
    }
  }

  Future<void> restoreTaskFromModel(Task task) async {
    await updateTask(task.restore());
  }

  Future<void> deleteTask(String id) async {
    try {
      await dbHelper.deleteTask(id);
      final tasks = _currentTasks;
      final index = tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        final updated = List<Task>.from(tasks);
        updated[index] = updated[index].copyWith(
            isDeleted: true, isArchived: true, updatedAt: DateTime.now());
        _updateState(updated);
      }
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  Future<void> deleteTaskPermanently(String id) async {
    try {
      await dbHelper.deleteTaskPermanently(id);
      _updateState(_currentTasks.where((t) => t.id != id).toList());
    } catch (e) {
      debugPrint('Error permanently deleting task: $e');
    }
  }

  Future<void> toggleTaskCompletion(Task task) async {
    final updatedTask = task.copyWith(
      isCompleted: !task.isCompleted,
      completedAt: !task.isCompleted ? DateTime.now() : null,
    );
    await updateTask(updatedTask);
  }

  Future<void> toggleFavorite(Task task) async {
    await updateTask(task.copyWith(isFavorite: !task.isFavorite));
  }

  Future<void> togglePin(Task task) async {
    await updateTask(task.copyWith(isPinned: !task.isPinned));
  }

  Future<void> clearAllTasks() async {
    try {
      await dbHelper.clearTasks();
      _updateState([]);
    } catch (e) {
      debugPrint('Error clearing tasks: $e');
    }
  }
}

final allTasksProvider = Provider<List<Task>>((ref) {
  final state = ref.watch(taskProvider);
  return state.maybeWhen(
    data: (tasks) => tasks.where((task) => !task.isDeleted).toList(),
    orElse: () => [],
  );
});

final todayTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(allTasksProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return tasks.where((task) {
    final taskDate =
        DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    return taskDate.isAtSameMomentAs(today) &&
        !task.isArchived &&
        !task.isDeleted;
  }).toList();
});

final upcomingTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(allTasksProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return tasks.where((task) {
    final taskDate =
        DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    return taskDate.isAfter(today) && !task.isArchived && !task.isDeleted;
  }).toList();
});

final overdueTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(allTasksProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return tasks.where((task) {
    final taskDate =
        DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    return taskDate.isBefore(today) &&
        !task.isCompleted &&
        !task.isArchived &&
        !task.isDeleted;
  }).toList();
});

final favoritesProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(allTasksProvider);
  return tasks
      .where((task) => task.isFavorite && !task.isArchived)
      .toList();
});

final habitLogsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, habitId) async {
  final dbHelper = ref.watch(databaseProvider);
  return dbHelper.getHabitLogs(habitId);
});

final habitsProvider =
    StateNotifierProvider<HabitNotifier, AsyncValue<List<Habit>>>((ref) {
  final dbHelper = ref.watch(databaseProvider);
  return HabitNotifier(dbHelper);
});

final overallStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final habitsState = ref.watch(habitsProvider);
  final habits = habitsState.maybeWhen(
    data: (items) => items,
    orElse: () => <Habit>[],
  );
  final totalStreaks = habits.length;
  final longestStreak = habits.fold<int>(
    0,
    (previousValue, habit) => habit.currentStreak > previousValue
        ? habit.currentStreak
        : previousValue,
  );
  final averageStreak = totalStreaks == 0
      ? 0.0
      : habits.fold<int>(0, (sum, habit) => sum + habit.currentStreak) /
          totalStreaks;
  final completedToday = habits.where((habit) => habit.isCompletedToday).length;
  final bestStreakEver = habits.fold<int>(
    0,
    (previousValue, habit) =>
        habit.bestStreak > previousValue ? habit.bestStreak : previousValue,
  );

  return {
    'totalStreaks': totalStreaks,
    'longestStreak': longestStreak,
    'averageStreak': averageStreak,
    'completedToday': completedToday,
    'bestStreakEver': bestStreakEver,
  };
});

final streakSummaryProvider = Provider<Map<String, dynamic>>((ref) {
  final habitsState = ref.watch(habitsProvider);
  final habits = habitsState.maybeWhen(
    data: (items) => items,
    orElse: () => <Habit>[],
  );

  final activeStreaks = habits.where((habit) => habit.currentStreak > 0).length;
  final longestStreak = habits.fold<int>(
    0,
    (previousValue, habit) => habit.currentStreak > previousValue
        ? habit.currentStreak
        : previousValue,
  );
  final completedToday = habits.where((habit) => habit.isCompletedToday).length;

  return {
    'activeStreaks': activeStreaks,
    'longestStreak': longestStreak,
    'completedToday': completedToday,
  };
});

class HabitNotifier extends StateNotifier<AsyncValue<List<Habit>>> {
  final DatabaseHelper dbHelper;

  HabitNotifier(this.dbHelper) : super(const AsyncValue.loading()) {
    loadHabits();
  }

  List<Habit> get _currentHabits => state.maybeWhen(
        data: (habits) => habits,
        orElse: () => [],
      );

  void _updateState(List<Habit> habits) {
    state = AsyncValue.data(habits);
  }

  Future<void> loadHabits() async {
    try {
      state = const AsyncValue.loading();
      final habits = await dbHelper.getAllHabits();
      state = AsyncValue.data(habits);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addHabit(Habit habit) async {
    try {
      await dbHelper.createHabit(habit);
      _updateState([habit, ..._currentHabits]);
    } catch (e) {
      debugPrint('Error adding habit: $e');
    }
  }

  Future<void> updateHabit(Habit habit) async {
    try {
      await dbHelper.updateHabit(habit);
      final habits = _currentHabits;
      final index = habits.indexWhere((h) => h.id == habit.id);
      if (index != -1) {
        final updated = List<Habit>.from(habits);
        updated[index] = habit;
        _updateState(updated);
      }
    } catch (e) {
      debugPrint('Error updating habit: $e');
    }
  }

  Future<void> deleteHabit(String id) async {
    try {
      await dbHelper.deleteHabit(id);
      _updateState(_currentHabits.where((h) => h.id != id).toList());
    } catch (e) {
      debugPrint('Error deleting habit: $e');
    }
  }

  Future<Habit?> completeToday(String habitId, {DateTime? now}) async {
    try {
      final habit = await dbHelper.getHabit(habitId);
      if (habit == null) {
        return null;
      }

      final moment = now ?? DateTime.now();
      final updatedHabit = habit.markCompleted(now: moment);
      await dbHelper.updateHabit(updatedHabit);
      await dbHelper.logHabitCompletion(habitId, moment.toIso8601String());

      final habits = _currentHabits;
      final index = habits.indexWhere((h) => h.id == habitId);
      if (index != -1) {
        final updated = List<Habit>.from(habits);
        updated[index] = updatedHabit;
        _updateState(updated);
      }

      return updatedHabit;
    } catch (e) {
      debugPrint('Error logging habit: $e');
      return null;
    }
  }
}
