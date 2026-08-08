import 'package:flutter_test/flutter_test.dart';
import 'package:task_app/models/habit_model.dart';
import 'package:task_app/models/task_model.dart';

void main() {
  test('task round-trip preserves checklist and reminder metadata', () {
    final task = Task(
      title: 'Study for exam',
      category: 'College',
      priority: 'High',
      dueDate: DateTime(2026, 7, 25, 20, 0),
      checklist: const ['Read notes', 'Solve questions'],
      isFavorite: true,
      isPinned: true,
      reminderMinutesBefore: 30,
    );

    final map = task.toMap();
    final restored = Task.fromMap(map);

    expect(restored.title, 'Study for exam');
    expect(restored.checklist, ['Read notes', 'Solve questions']);
    expect(restored.isFavorite, isTrue);
    expect(restored.isPinned, isTrue);
    expect(restored.reminderMinutesBefore, 30);
  });

  test('recurring tasks advance to the next occurrence', () {
    final task = Task(
      title: 'Workout',
      category: 'Gym',
      dueDate: DateTime(2026, 7, 20),
      repeatRule: 'Weekly',
    );

    final next = task.nextOccurrence();
    expect(next.dueDate, DateTime(2026, 7, 27));
    expect(next.repeatRule, 'Weekly');
  });

  test('archived tasks preserve archive state after serialization', () {
    final task = Task(
      title: 'Review notes',
      category: 'Study',
      dueDate: DateTime(2026, 7, 24),
      isArchived: true,
      isDeleted: false,
    );

    final restored = Task.fromMap(task.toMap());
    expect(restored.isArchived, isTrue);
    expect(restored.isDeleted, isFalse);
  });

  test('restoring a task clears archive and trash state', () {
    final task = Task(
      title: 'Review notes',
      category: 'Study',
      dueDate: DateTime(2026, 7, 24),
      isArchived: true,
      isDeleted: true,
    );

    final restored = task.restore();
    expect(restored.isArchived, isFalse);
    expect(restored.isDeleted, isFalse);
  });

  test('marking a streak complete today increments the streak safely', () {
    final habit = Habit(name: 'Read 20 pages');
    final updated = habit.markCompleted(now: DateTime(2026, 8, 7));

    expect(updated.currentStreak, 1);
    expect(updated.bestStreak, 1);
    expect(updated.isCompletedToday, isTrue);
  });
}
