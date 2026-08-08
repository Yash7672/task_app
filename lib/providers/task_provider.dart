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
      final tasks = await dbHelper.getAllTasks();
      state = AsyncValue.data(tasks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTask(Task task) async {
    try {
      await dbHelper.createTask(task);
      await loadTasks();
    } catch (e) {
      print('Error adding task: $e');
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      await dbHelper.updateTask(task);
      await loadTasks();
    } catch (e) {
      print('Error updating task: $e');
    }
  }

  Future<void> archiveTask(String id) async {
    try {
      await dbHelper.archiveTask(id);
      await loadTasks();
    } catch (e) {
      print('Error archiving task: $e');
    }
  }

  Future<void> restoreTask(String id) async {
    try {
      await dbHelper.restoreTask(id);
      await loadTasks();
    } catch (e) {
      print('Error restoring task: $e');
    }
  }

  Future<void> restoreTaskFromModel(Task task) async {
    await updateTask(task.restore());
  }

  Future<void> deleteTask(String id) async {
    try {
      await dbHelper.deleteTask(id);
      await loadTasks();
    } catch (e) {
      print('Error deleting task: $e');
    }
  }

  Future<void> deleteTaskPermanently(String id) async {
    try {
      await dbHelper.deleteTaskPermanently(id);
      await loadTasks();
    } catch (e) {
      print('Error permanently deleting task: $e');
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
      await loadTasks();
    } catch (e) {
      print('Error clearing tasks: $e');
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

final tasksByDateProvider = Provider<Map<DateTime, List<Task>>>((ref) {
  final tasks = ref.watch(allTasksProvider);
  final map = <DateTime, List<Task>>{};
  
  for (final task in tasks) {
    if (task.isDeleted) continue;
    final date = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    if (map[date] == null) {
      map[date] = [];
    }
    map[date]!.add(task);
  }
  return map;
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
  return tasks.where((task) => task.isFavorite).toList();
});

final habitLogsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, habitId) async {
  final dbHelper = ref.watch(databaseProvider);
  return dbHelper.getHabitLogs(habitId);
});

final habitsProvider =
    StateNotifierProvider<HabitNotifier, AsyncValue<List<Habit>>>((ref) {
  final dbHelper = ref.watch(databaseProvider);
  return HabitNotifier(dbHelper);
});

final overallStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dbHelper = ref.watch(databaseProvider);
  final habits = await dbHelper.getAllHabits();
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
      await loadHabits();
    } catch (e) {
      print('Error adding habit: $e');
    }
  }

  Future<void> updateHabit(Habit habit) async {
    try {
      await dbHelper.updateHabit(habit);
      await loadHabits();
    } catch (e) {
      print('Error updating habit: $e');
    }
  }

  Future<void> deleteHabit(String id) async {
    try {
      await dbHelper.deleteHabit(id);
      await loadHabits();
    } catch (e) {
      print('Error deleting habit: $e');
    }
  }

  Future<Habit?> completeToday(String habitId, {DateTime? now}) async {
    try {
      final habit = await dbHelper.getHabit(habitId);
      if (habit == null) {
        return null;
      }

      final updatedHabit = habit.markCompleted(now: now ?? DateTime.now());
      await dbHelper.updateHabit(updatedHabit);
      await loadHabits();
      return updatedHabit;
    } catch (e) {
      print('Error logging habit: $e');
      return null;
    }
  }
}
