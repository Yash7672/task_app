import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:task_app/database/database_helper.dart';
import 'package:task_app/features/streaks/widgets/habit_detail_popup.dart';
import 'package:task_app/models/habit_completion_item.dart';
import 'package:task_app/models/habit_log_item.dart';
import 'package:task_app/models/habit_model.dart';
import 'package:task_app/providers/database_provider.dart';
import 'package:task_app/providers/task_provider.dart';
import 'package:task_app/theme/app_theme.dart';

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    // No-isolate variant: identical behaviour but without spawning the
    // long-lived ffi isolate that would keep the test VM alive forever.
    databaseFactory = databaseFactoryFfiNoIsolate;
    final dbsPath = await databaseFactory.getDatabasesPath();
    await Directory(dbsPath).create(recursive: true);
  });

  setUp(() async {
    final path = await DatabaseHelper.instance.databasePath;
    await databaseFactory.deleteDatabase(path);
    await DatabaseHelper.instance.initDatabase();
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
  });

  /// [autoDispose] can be disabled inside `testWidgets`, where addTearDown
  /// runs after the framework's pending-timer check — dispose manually there.
  ProviderContainer createContainer({bool autoDispose = true}) {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(DatabaseHelper.instance),
    ]);
    if (autoDispose) addTearDown(container.dispose);
    return container;
  }

  Future<Habit> seedHabit() {
    return DatabaseHelper.instance.createHabit(Habit(name: 'Workout'));
  }

  Future<void> addLogItem(String habitId, DateTime date, String text,
      {int position = 0}) async {
    await DatabaseHelper.instance.createHabitLogItem(HabitLogItem(
      logId: habitLogIdFor(habitId, date),
      text: text,
      position: position,
    ));
  }

  test('HabitCompletionItem round-trips through the database map', () {
    final item = HabitCompletionItem(
      habitId: 'habit-1',
      completionDate: '2026-08-21',
      text: 'Morning workout',
      completed: true,
      position: 2,
    );

    final restored = HabitCompletionItem.fromMap(item.toMap());

    expect(restored.id, item.id);
    expect(restored.habitId, 'habit-1');
    expect(restored.completionDate, '2026-08-21');
    expect(restored.text, 'Morning workout');
    expect(restored.completed, isTrue);
    expect(restored.position, 2);
  });

  test('effectiveCurrentStreak decays once the last completion is stale', () {
    final now = DateTime(2026, 8, 23);

    Habit buildHabit({DateTime? lastCompleted}) => Habit(
          name: 'Workout',
          currentStreak: 12,
          bestStreak: 20,
          lastCompletedDate: lastCompleted,
        );

    // Completed today or yesterday -> stored streak still alive.
    expect(
      buildHabit(lastCompleted: DateTime(2026, 8, 23)).effectiveCurrentStreak(now: now),
      12,
    );
    expect(
      buildHabit(lastCompleted: DateTime(2026, 8, 22)).effectiveCurrentStreak(now: now),
      12,
    );
    // Missed two or more days -> streak is gone even though the counter
    // still says 12.
    expect(
      buildHabit(lastCompleted: DateTime(2026, 8, 21)).effectiveCurrentStreak(now: now),
      0,
    );
    expect(buildHabit().effectiveCurrentStreak(now: now), 0);
  });

  test('a) completing a habit logs the day and advances streaks', () async {
    final habit = await seedHabit();
    final container = createContainer();

    final now = DateTime.now();
    final updated =
        await container.read(habitsProvider.notifier).completeToday(
              habit.id,
              now: now,
            );

    expect(updated, isNotNull);
    expect(updated!.currentStreak, 1);
    expect(updated.bestStreak, 1);
    expect(_startOfDay(updated.lastCompletedDate!), _startOfDay(now));

    final logs = await DatabaseHelper.instance.getHabitLogs(habit.id);
    expect(logs, hasLength(1));
    expect(logs.first['date'], habitDateKey(now));
    expect(logs.first['isCompleted'], 1);

    // Completing again on the same day must not double-count.
    final again =
        await container.read(habitsProvider.notifier).completeToday(
              habit.id,
              now: now,
            );
    expect(again!.currentStreak, 1);
    expect(
        (await DatabaseHelper.instance.getHabitLogs(habit.id)).length, 1);
  });

  test('b) saving checklist history stores a per-date snapshot', () async {
    final habit = await seedHabit();
    const dateKey = '2026-08-20';

    await DatabaseHelper.instance.saveCompletionChecklist(
      habit.id,
      dateKey,
      [
        HabitCompletionItem(
            habitId: habit.id,
            completionDate: dateKey,
            text: 'Run 2 km',
            completed: true,
            position: 0),
        HabitCompletionItem(
            habitId: habit.id,
            completionDate: dateKey,
            text: '20 push-ups',
            completed: true,
            position: 1),
      ],
    );

    final items =
        await DatabaseHelper.instance.getCompletionChecklist(habit.id, dateKey);
    expect(items.map((i) => i.text), ['Run 2 km', '20 push-ups']);
    expect(items.every((i) => i.completed), isTrue);
  });

  test('c) retrieving history returns only that exact date', () async {
    final habit = await seedHabit();

    await DatabaseHelper.instance.saveCompletionChecklist(habit.id, '2026-08-20', [
      HabitCompletionItem(
          habitId: habit.id,
          completionDate: '2026-08-20',
          text: 'Run 2 km',
          position: 0),
    ]);
    await DatabaseHelper.instance.saveCompletionChecklist(habit.id, '2026-08-21', [
      HabitCompletionItem(
          habitId: habit.id,
          completionDate: '2026-08-21',
          text: 'Run 3 km',
          position: 0),
    ]);

    final day20 =
        await DatabaseHelper.instance.getCompletionChecklist(habit.id, '2026-08-20');
    expect(day20.map((i) => i.text), ['Run 2 km']);

    final day21 =
        await DatabaseHelper.instance.getCompletionChecklist(habit.id, '2026-08-21');
    expect(day21.map((i) => i.text), ['Run 3 km']);

    final otherDay =
        await DatabaseHelper.instance.getCompletionChecklist(habit.id, '2026-08-22');
    expect(otherDay, isEmpty);

    final otherHabit = await DatabaseHelper.instance
        .getCompletionChecklist('some-other-habit', '2026-08-20');
    expect(otherHabit, isEmpty);
  });

  test('f) history snapshots stay unchanged when today\'s checklist changes',
      () async {
    final habit = await seedHabit();
    final container = createContainer();

    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    // Day 1: complete with its own checklist.
    await addLogItem(habit.id, yesterday, 'Run 2 km', position: 0);
    await addLogItem(habit.id, yesterday, '20 push-ups', position: 1);
    await container.read(habitsProvider.notifier).completeToday(
          habit.id,
          now: yesterday,
        );

    // Day 2 (today): a different checklist.
    await addLogItem(habit.id, today, 'Run 3 km', position: 0);
    await addLogItem(habit.id, today, '30 push-ups', position: 1);
    final updatedToday =
        await container.read(habitsProvider.notifier).completeToday(
              habit.id,
              now: today,
            );
    expect(updatedToday!.currentStreak, 2,
        reason: 'consecutive completions keep the streak working');

    // Now mutate TODAY's live log entries (edit, add, delete).
    final liveItems =
        await DatabaseHelper.instance.getHabitLogItems(habitLogIdFor(habit.id, today));
    await DatabaseHelper.instance.updateHabitLogItem(
        liveItems[0].copyWith(text: 'Run 10 km'));
    await DatabaseHelper.instance.deleteHabitLogItem(liveItems[1].id);
    await DatabaseHelper.instance.createHabitLogItem(HabitLogItem(
      logId: habitLogIdFor(habit.id, today),
      text: 'Brand new entry',
      position: 5,
    ));

    // Yesterday's snapshot is untouched.
    final yesterdayHistory = await DatabaseHelper.instance
        .getCompletionChecklist(habit.id, habitDateKey(yesterday));
    expect(yesterdayHistory.map((i) => i.text), ['Run 2 km', '20 push-ups']);
    expect(yesterdayHistory.every((i) => i.completed), isTrue);

    // Today's snapshot still reflects completion time, not later edits.
    final todayHistory = await DatabaseHelper.instance
        .getCompletionChecklist(habit.id, habitDateKey(today));
    expect(todayHistory.map((i) => i.text), ['Run 3 km', '30 push-ups']);
  });

  test('g) same-day checklist updates refresh only today\'s snapshot',
      () async {
    final habit = await seedHabit();
    final container = createContainer();
    final notifier = container.read(habitsProvider.notifier);

    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    // Yesterday: completed with its own entry.
    await addLogItem(habit.id, yesterday, 'Run 2 km', position: 0);
    await notifier.completeToday(habit.id, now: yesterday);

    // Today: complete with two entries.
    await addLogItem(habit.id, today, 'Morning workout', position: 0);
    await addLogItem(habit.id, today, '30 push-ups', position: 1);
    await notifier.completeToday(habit.id, now: today);

    // User does it "one more time" — adds another entry after completing.
    await addLogItem(habit.id, today, '20 squats', position: 2);
    await notifier.syncTodaySnapshot(habit.id, now: today);

    final todayHistory = await DatabaseHelper.instance
        .getCompletionChecklist(habit.id, habitDateKey(today));
    expect(todayHistory.map((i) => i.text),
        ['Morning workout', '30 push-ups', '20 squats']);

    // Deleting a same-day entry also reflects in today's snapshot...
    final live =
        await DatabaseHelper.instance.getHabitLogItems(habitLogIdFor(habit.id, today));
    await DatabaseHelper.instance.deleteHabitLogItem(live[1].id);
    await notifier.syncTodaySnapshot(habit.id, now: today);
    final updated = await DatabaseHelper.instance
        .getCompletionChecklist(habit.id, habitDateKey(today));
    expect(updated.map((i) => i.text), ['Morning workout', '20 squats']);

    // ...while yesterday's history stays frozen.
    final yesterdayHistory = await DatabaseHelper.instance
        .getCompletionChecklist(habit.id, habitDateKey(yesterday));
    expect(yesterdayHistory.map((i) => i.text), ['Run 2 km']);
  });

  test('v6 -> v7 migration preserves existing daily log entries', () async {
    final path = await DatabaseHelper.instance.databasePath;
    const habitId = 'legacy-habit';
    const legacyLogId = '$habitId-2026-08-20';

    // Release the helper's pooled connection and remove the file so the
    // legacy database is created cleanly at v6 (opening over the existing v7
    // file would trigger sqflite's downgrade path instead of onCreate).
    await DatabaseHelper.instance.close();
    await databaseFactory.deleteDatabase(path);

    final oldDb = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 6,
          onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE habits (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          currentStreak INTEGER DEFAULT 0,
          bestStreak INTEGER DEFAULT 0,
          lastCompletedDate INTEGER,
          createdAt INTEGER,
          updatedAt INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE habit_log_items (
          id TEXT PRIMARY KEY,
          logId TEXT NOT NULL,
          text TEXT NOT NULL,
          position INTEGER DEFAULT 0
        )
      ''');
      await db.insert('habit_log_items', {
        'id': 'legacy-item-1',
        'logId': legacyLogId,
        'text': 'Legacy entry',
        'position': 0,
      });
    }));
    await oldDb.close();
    await DatabaseHelper.instance.initDatabase();

    final migrated = await DatabaseHelper.instance
        .getCompletionChecklist(habitId, '2026-08-20');
    expect(migrated, hasLength(1));
    expect(migrated.first.text, 'Legacy entry');
    expect(migrated.first.habitId, habitId);
    expect(migrated.first.completed, isTrue);
  });

  group('streak history calendar UI', () {
    Future<void> pumpPopup(WidgetTester tester, Habit habit) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(DatabaseHelper.instance),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: HabitDetailPopup(habit: habit),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('d) tapping a 🔥 date opens that day\'s snapshotted checklist',
        (tester) async {
      final habit = await seedHabit();
      final now = DateTime.now();

      await addLogItem(habit.id, now, 'Morning workout', position: 0);
      await addLogItem(habit.id, now, '30 push-ups', position: 1);
      final container = createContainer(autoDispose: false);
      await container.read(habitsProvider.notifier).completeToday(
            habit.id,
            now: now,
          );

      await pumpPopup(tester, habit);

      // Completed day carries the fire marker.
      expect(find.text('🔥'), findsOneWidget);

      final dayFinder = find.byWidgetPredicate((w) =>
          w is Text && w.data == '${now.day}' && w.style?.fontSize == 14);
      await tester.tap(dayFinder);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(DateFormat('d MMMM yyyy').format(now)),
        findsOneWidget,
      );
      expect(find.text('Morning workout'), findsOneWidget);
      expect(find.text('30 push-ups'), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsNWidgets(2));

      // Flush HomeWidgetService debounce timer so no timer stays pending.
      await tester.pump(const Duration(seconds: 1));

      // Dispose before the test body ends: the midnight-reload Timer armed
      // by HabitNotifier must be cancelled before the framework's invariant
      // check, and addTearDown runs too late inside testWidgets.
      container.dispose();
    });

    testWidgets('e) tapping an incomplete date opens the day detail sheet',
        (tester) async {
      final habit = await seedHabit(); // never completed
      final now = DateTime.now();
      final container = createContainer(autoDispose: false);
      await container.read(habitsProvider.notifier).loadHabits();

      await pumpPopup(tester, habit);

      expect(find.text('🔥'), findsNothing);

      final dayFinder = find.byWidgetPredicate((w) =>
          w is Text && w.data == '${now.day}' && w.style?.fontSize == 14);
      await tester.tap(dayFinder);
      await tester.pumpAndSettle();

      // Now opens a detail sheet with streak/miss controls
      expect(find.text('✕ Miss Streak'), findsOneWidget);
      expect(find.text('✓ Streak'), findsOneWidget);

      // Flush HomeWidgetService debounce timer so no timer stays pending.
      await tester.pump(const Duration(seconds: 1));

      // Dispose before the test body ends.
      container.dispose();
    });
  });
}
