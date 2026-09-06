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

    test('monthly anchored day 31 never drifts after a short month', () {
      // The original anchor (31) is stored separately from the clamped due
      // date. Even after Feb 28, March must land back on the 31st.
      final task = Task(
        title: 'Pay rent',
        category: 'Finance',
        dueDate: DateTime(2026, 2, 28),
        repeatMonthday: 31,
        repeatRule: 'Monthly',
      );

      final next = task.nextOccurrence();
      expect(next.dueDate, DateTime(2026, 3, 31));
      // ...and the anchor carries forward so April 30 -> May 31 -> ...
      expect(next.nextOccurrence().dueDate, DateTime(2026, 4, 30));
      expect(next.nextOccurrence().nextOccurrence().dueDate,
          DateTime(2026, 5, 31));
    });

    test('monthly anchored day 31 crosses the year boundary', () {
      final task = Task(
        title: 'Pay rent',
        category: 'Finance',
        dueDate: DateTime(2026, 12, 31),
        repeatMonthday: 31,
        repeatRule: 'Monthly',
      );

      final next = task.nextOccurrence();
      expect(next.dueDate, DateTime(2027, 1, 31));
    });

    test('yearly anchored Feb 29 lands on Feb 28 outside leap years', () {
      final task = Task(
        title: 'Anniversary',
        category: 'Personal',
        dueDate: DateTime(2028, 2, 29),
        repeatMonthday: 29,
        repeatRule: 'Yearly',
      );

      // 2029 is not a leap year -> clamp to Feb 28 (never Mar 1).
      final next = task.nextOccurrence();
      expect(next.dueDate, DateTime(2029, 2, 28));
      // The next occurrence keeps the anchor and fires again on Feb 29 in the
      // next leap year (2032).
      final after2029 = next.nextOccurrence();
      expect(after2029.dueDate, DateTime(2030, 2, 28));
      final after2030 = after2029.nextOccurrence();
      expect(after2030.dueDate, DateTime(2031, 2, 28));
      final after2031 = after2030.nextOccurrence();
      expect(after2031.dueDate, DateTime(2032, 2, 29));
    });

    test('regenerate preserves the recurrence anchor', () {
      final task = Task(
        title: 'Pay rent',
        category: 'Finance',
        dueDate: DateTime(2026, 1, 31),
        repeatMonthday: 31,
        repeatRule: 'Monthly',
      );

      final next = task.regenerate();
      expect(next.repeatMonthday, 31);
    });

    test('monthly preserves time of day', () {
      final task = Task(
        title: 'Pay rent',
        category: 'Finance',
        dueDate: DateTime(2026, 1, 31, 14, 30),
        repeatRule: 'Monthly',
      );

      // Jan 31 clamps to Feb 28 but must keep the 14:30 time.
      final next = task.nextOccurrence();
      expect(next.dueDate, DateTime(2026, 2, 28, 14, 30));
    });

    test('weekly crosses month boundaries on the calendar day', () {
      final task = Task(
        title: 'Weekly review',
        category: 'Work',
        dueDate: DateTime(2026, 1, 28, 9, 0),
        repeatRule: 'Weekly',
      );

      final next = task.nextOccurrence();
      expect(next.dueDate, DateTime(2026, 2, 4, 9, 0));
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
