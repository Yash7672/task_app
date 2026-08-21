import 'package:flutter_test/flutter_test.dart';
import 'package:task_app/models/task_model.dart';

void main() {
  group('recurrence', () {
    test('daily advances by one day and keeps time of day', () {
      final task = Task(
        title: 'Meditate',
        category: 'Personal',
        dueDate: DateTime(2026, 8, 20, 7, 30),
        startTime: DateTime(2026, 8, 20, 7, 30),
        endTime: DateTime(2026, 8, 20, 8, 0),
        repeatRule: 'Daily',
      );

      final next = task.regenerate();

      expect(next.dueDate, DateTime(2026, 8, 21, 7, 30));
      expect(next.startTime, DateTime(2026, 8, 21, 7, 30));
      expect(next.endTime, DateTime(2026, 8, 21, 8, 0));
      expect(next.isCompleted, isFalse);
      expect(next.id, isNot(task.id));
    });

    test('weekly advances by seven days', () {
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

    test('monthly clamps to the last day of short months', () {
      final task = Task(
        title: 'Pay rent',
        category: 'Finance',
        dueDate: DateTime(2026, 1, 31),
        repeatRule: 'Monthly',
      );

      final next = task.nextOccurrence();
      expect(next.dueDate.year, 2026);
      expect(next.dueDate.month, 2);
      expect(next.dueDate.day, 28);
    });

    test('monthly keeps day 15 intact across months', () {
      final task = Task(
        title: 'Subscription',
        category: 'Finance',
        dueDate: DateTime(2026, 1, 15),
        repeatRule: 'Monthly',
      );

      final next = task.nextOccurrence();
      expect(next.dueDate, DateTime(2026, 2, 15));
    });

    test('yearly advances the year', () {
      final task = Task(
        title: 'Renew insurance',
        category: 'Finance',
        dueDate: DateTime(2026, 3, 15),
        repeatRule: 'Yearly',
      );

      final next = task.nextOccurrence();
      expect(next.dueDate, DateTime(2027, 3, 15));
    });

    test('regenerate carries checklist state and reminders forward', () {
      final task = Task(
        title: 'Morning routine',
        category: 'Personal',
        dueDate: DateTime(2026, 8, 20),
        repeatRule: 'Daily',
        checklist: [
          const ChecklistItemData(text: 'Stretch', done: true),
          const ChecklistItemData(text: 'Journal'),
        ],
        reminderMinutes: [10],
      );

      final next = task.regenerate();

      expect(next.checklist.length, 2);
      expect(next.checklist.first.text, 'Stretch');
      expect(next.checklist.first.done, isTrue);
      expect(next.reminderMinutes, [10]);
    });

    test('never-repeat tasks do not advance', () {
      final task = Task(
        title: 'One-off',
        category: 'Personal',
        dueDate: DateTime(2026, 8, 20),
        repeatRule: 'Never',
      );

      final next = task.nextOccurrence();
      expect(next.dueDate, task.dueDate);
    });
  });
}
