import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:task_app/database/database_helper.dart';
import 'package:task_app/models/task_model.dart';
import 'package:task_app/providers/database_provider.dart';
import 'package:task_app/providers/task_provider.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    final dbsPath = await databaseFactory.getDatabasesPath();
    await Directory(dbsPath).create(recursive: true);
    // Own private DB file: the full suite runs test files in parallel
    // isolates, and they must not share the one production taskflow.db.
    DatabaseHelper.testDbPathOverride = p.join(dbsPath, 'taskflow_undo_test.db');
  });

  setUp(() async {
    final path = await DatabaseHelper.instance.databasePath;
    await databaseFactory.deleteDatabase(path);
    await DatabaseHelper.instance.initDatabase();
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(DatabaseHelper.instance),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Task makeTask({String? id}) {
    return Task(
      id: id,
      title: 'Study DAA',
      description: 'Chapter 4',
      category: 'College',
      priority: 'High',
      dueDate: DateTime(2026, 9, 6, 18, 0),
      startTime: DateTime(2026, 9, 6, 18, 0),
      reminderMinutes: const [10],
      isFavorite: true,
      isPinned: true,
      repeatRule: 'Weekly',
    );
  }

  Future<void> seed(List<Task> tasks) async {
    for (final t in tasks) {
      await DatabaseHelper.instance.createTask(t);
    }
  }

  List<Task> uiTasks(ProviderContainer c) =>
      c.read(taskProvider).maybeWhen(data: (t) => t, orElse: () => []);

  Future<Task?> dbTask(String id) async =>
      DatabaseHelper.instance.getTask(id);

  Future<void> settle(ProviderContainer c) async {
    await c.read(taskProvider.notifier).loadTasks();
  }

  test('delete then undo restores the exact same task', () async {
    final container = createContainer();
    final task = makeTask(id: '123');
    await seed([task]);
final notifier = container.read(taskProvider.notifier);
    await settle(container);

    expect(uiTasks(container).map((t) => t.id), ['123']);

    await notifier.deleteTask('123');
    expect(uiTasks(container), isEmpty);
    expect(await dbTask('123').then((t) => t?.isDeleted), isTrue);

    await notifier.restoreTask('123');
    expect(uiTasks(container).map((t) => t.id), ['123']);
    final restored = await dbTask('123');
    expect(restored, isNotNull);
    expect(restored!.isDeleted, isFalse);
    expect(restored.isArchived, isFalse);
    expect(restored.id, '123');
    expect(restored.title, 'Study DAA');
    expect(restored.dueDate, DateTime(2026, 9, 6, 18, 0));
    expect(restored.priority, 'High');
    expect(restored.category, 'College');
    expect(restored.isFavorite, isTrue);
    expect(restored.isPinned, isTrue);
    expect(restored.repeatRule, 'Weekly');
    expect(restored.reminderMinutes, [10]);
    expect(restored.isCompleted, isFalse);
  });

  test('immediate undo (restore before delete settles) still restores', () async {
    final container = createContainer();
    final task = makeTask(id: 'abc');
    await seed([task]);
    final notifier = container.read(taskProvider.notifier);
    await settle(container);
    final del = notifier.deleteTask('abc');
    final res = notifier.restoreTask('abc');
    await Future.wait([del, res]);

    expect(uiTasks(container).map((t) => t.id), ['abc']);
    final restored = await dbTask('abc');
    expect(restored, isNotNull);
    expect(restored!.isDeleted, isFalse);
    expect(restored.isArchived, isFalse);
  });

  test('delete A then delete B then undo restores A, not B', () async {
    final container = createContainer();
    await seed(
        [makeTask(id: 'A'), Task(id: 'B', title: 'B', category: 'x', dueDate: DateTime(2026, 9, 7))]);
    final notifier = container.read(taskProvider.notifier);
    await settle(container);
    await notifier.deleteTask('A');
    await notifier.deleteTask('B');
    expect(uiTasks(container), isEmpty);

    await notifier.restoreTask('A');
    final ids = uiTasks(container).map((t) => t.id).toList();
    expect(ids, ['A']);

    await notifier.restoreTask('B');
    expect(uiTasks(container).map((t) => t.id).toList(), containsAll(['A', 'B']));
  });

  test('delete completed task then undo preserves completed state', () async {
    final container = createContainer();
    final task = makeTask(id: 'done').copyWith(isCompleted: true);
    await seed([task]);
    final notifier = container.read(taskProvider.notifier);
    await settle(container);
    await notifier.deleteTask('done');
    await notifier.restoreTask('done');

    final restored = await dbTask('done');
    expect(restored, isNotNull);
    expect(restored!.isCompleted, isTrue);
  });

  test('rapid repeated undo does not duplicate tasks', () async {
    final container = createContainer();
    await seed([makeTask(id: 'x')]);
    final notifier = container.read(taskProvider.notifier);
    await settle(container);
    await notifier.deleteTask('x');
    await notifier.restoreTask('x');
    await notifier.restoreTask('x'); // duplicate undo tap
    await notifier.loadTasks();
    final ids = (await DatabaseHelper.instance.getAllTasks()).map((t) => t.id).toList();
    expect(ids.where((id) => id == 'x').length, 1); // no duplicates
  });
}
