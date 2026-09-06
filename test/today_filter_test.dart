import 'package:flutter_test/flutter_test.dart';
import 'package:task_app/models/task_model.dart';
import 'package:task_app/services/home_widget_service.dart';

void main() {
  final today = DateTime(2026, 9, 6);

  Task taskOn(DateTime date,
      {bool completed = false,
      bool archived = false,
      bool deleted = false}) {
    return Task(
      title: 'Task',
      category: 'Personal',
      dueDate: date,
      isCompleted: completed,
      isArchived: archived,
      isDeleted: deleted,
    );
  }

  group('HomeWidgetService.isDueOn (today-only filter)', () {
    test('accepts only tasks due on the same calendar date', () {
      expect(HomeWidgetService.isDueOn(taskOn(DateTime(2026, 9, 6, 9, 0)), today),
          isTrue);
    });

    test('ignores the time-of-day component', () {
      final early = taskOn(DateTime(2026, 9, 6, 0, 0, 0, 1));
      final late = taskOn(DateTime(2026, 9, 6, 23, 59, 59, 999));
      expect(HomeWidgetService.isDueOn(early, today), isTrue);
      expect(HomeWidgetService.isDueOn(late, today), isTrue);
    });

    test('excludes yesterday tasks', () {
      expect(HomeWidgetService.isDueOn(taskOn(DateTime(2026, 9, 5, 23, 59)), today),
          isFalse);
    });

    test('excludes tomorrow tasks', () {
      expect(HomeWidgetService.isDueOn(taskOn(DateTime(2026, 9, 7, 0, 1)), today),
          isFalse);
    });

    test('excludes next week tasks', () {
      expect(HomeWidgetService.isDueOn(taskOn(DateTime(2026, 9, 13)), today),
          isFalse);
    });

    test('accepts next month tasks on the same day only if it is today', () {
      // Same shape as the "Sep 6 -> Sep 7 -> Sep 10" scenario but within
      // the same day of a later month: still excluded unless it is today.
      expect(HomeWidgetService.isDueOn(taskOn(DateTime(2026, 10, 6)), today),
          isFalse);
    });

    test('completed tasks due today are still today tasks', () {
      expect(
          HomeWidgetService.isDueOn(taskOn(DateTime(2026, 9, 6), completed: true),
              today),
          isTrue);
    });

    test('excludes archived and deleted tasks', () {
      expect(
          HomeWidgetService.isDueOn(taskOn(today, archived: true), today), isFalse);
      expect(
          HomeWidgetService.isDueOn(taskOn(today, deleted: true), today), isFalse);
    });
  });
}