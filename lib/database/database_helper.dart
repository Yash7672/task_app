import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/category_model.dart';
import '../models/habit_model.dart';
import '../models/task_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();
  static Database? _database;
  static String? _cachedDbPath;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('taskflow.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (_cachedDbPath == null) {
      final dbPath = await getDatabasesPath();
      _cachedDbPath = p.join(dbPath, filePath);
    }

    return openDatabase(
      _cachedDbPath!,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final columns = await db.rawQuery('PRAGMA table_info(habits)');
      final hasLastCompletedDate = columns.any(
        (column) => column['name'] == 'lastCompletedDate',
      );
      if (!hasLastCompletedDate) {
        await db
            .execute('ALTER TABLE habits ADD COLUMN lastCompletedDate INTEGER');
      }
    }
    if (oldVersion < 3) {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'habit_logs'",
      );
      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE habit_logs (
            id TEXT PRIMARY KEY,
            habitId TEXT,
            date TEXT,
            isCompleted INTEGER DEFAULT 0
          )
        ''');
      }
    }
    if (oldVersion < 4) {
      final columns = await db.rawQuery('PRAGMA table_info(tasks)');
      final hasNew = columns.any((c) => c['name'] == 'reminderMinutes');
      final hasOld = columns.any((c) => c['name'] == 'reminderMinutesBefore');
      if (!hasNew) {
        await db.execute(
            "ALTER TABLE tasks ADD COLUMN reminderMinutes TEXT DEFAULT '[]'");
      }
      if (hasOld && hasNew) {
        final rows = await db.query('tasks', columns: ['id', 'reminderMinutesBefore', 'reminderMinutes']);
        for (final row in rows) {
          final oldVal = row['reminderMinutesBefore'];
          final newVal = row['reminderMinutes'];
          if (newVal == null || newVal == '[]' || newVal == '') {
            final List<int> migrated = [];
            if (oldVal is int && oldVal > 0) {
              migrated.add(oldVal);
            }
            await db.update(
              'tasks',
              {'reminderMinutes': jsonEncode(migrated)},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
        await db.execute('ALTER TABLE tasks DROP COLUMN reminderMinutesBefore');
      }
      await _createIndexes(db);
    }
  }

  Future<void> _createIndexes(Database db) async {
    final indexes = [
      'CREATE INDEX IF NOT EXISTS idx_tasks_isDeleted_isArchived ON tasks(isDeleted, isArchived)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_dueDate ON tasks(dueDate)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_category ON tasks(category)',
      'CREATE INDEX IF NOT EXISTS idx_habit_logs_habitId ON habit_logs(habitId)',
    ];
    for (final sql in indexes) {
      await db.execute(sql);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT,
        priority TEXT,
        dueDate INTEGER,
        startTime INTEGER,
        endTime INTEGER,
        isCompleted INTEGER DEFAULT 0,
        isArchived INTEGER DEFAULT 0,
        isDeleted INTEGER DEFAULT 0,
        isFavorite INTEGER DEFAULT 0,
        isPinned INTEGER DEFAULT 0,
        notes TEXT,
        repeatRule TEXT,
        color TEXT,
        checklist TEXT,
        reminderMinutes TEXT DEFAULT '[]',
        estimatedDuration TEXT,
        completedAt INTEGER,
        createdAt INTEGER,
        updatedAt INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        colorHex TEXT,
        icon TEXT
      )
    ''');

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
      CREATE TABLE habit_logs (
        id TEXT PRIMARY KEY,
        habitId TEXT,
        date TEXT,
        isCompleted INTEGER DEFAULT 0
      )
    ''');

    final defaultCategories = [
      {'id': '1', 'name': 'Personal', 'colorHex': '#4CAF50', 'icon': '🧘'},
      {'id': '2', 'name': 'College', 'colorHex': '#2196F3', 'icon': '🎓'},
      {'id': '3', 'name': 'Study', 'colorHex': '#9C27B0', 'icon': '📚'},
      {'id': '4', 'name': 'Gym', 'colorHex': '#FF9800', 'icon': '💪'},
      {'id': '5', 'name': 'Shopping', 'colorHex': '#E91E63', 'icon': '🛍️'},
      {'id': '6', 'name': 'Work', 'colorHex': '#607D8B', 'icon': '💼'},
      {'id': '7', 'name': 'Health', 'colorHex': '#F44336', 'icon': '🩺'},
      {'id': '8', 'name': 'Finance', 'colorHex': '#FFC107', 'icon': '💰'},
      {
        'id': '9',
        'name': 'Family',
        'colorHex': '#795548',
        'icon': '👨‍👩‍👧‍👦'
      },
      {'id': '10', 'name': 'Travel', 'colorHex': '#00BCD4', 'icon': '✈️'},
    ];

    for (final item in defaultCategories) {
      await db.insert('categories', item,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await db.execute(
        'CREATE INDEX idx_tasks_isDeleted_isArchived ON tasks(isDeleted, isArchived)');
    await db.execute('CREATE INDEX idx_tasks_dueDate ON tasks(dueDate)');
    await db.execute('CREATE INDEX idx_tasks_category ON tasks(category)');
    await db.execute(
        'CREATE INDEX idx_habit_logs_habitId ON habit_logs(habitId)');
  }

  Future<Task> createTask(Task task) async {
    final db = await database;
    await db.insert('tasks', task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return task;
  }

  Future<Task?> getTask(String id) async {
    final db = await database;
    final maps = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Task>> getAllTasks({bool includeArchived = false}) async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: includeArchived
          ? 'isDeleted = 0'
          : 'isDeleted = 0 AND isArchived = 0',
      orderBy: 'dueDate ASC',
    );
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<Task>> getArchivedTasks() async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: 'isDeleted = 0 AND isArchived = 1',
      orderBy: 'dueDate ASC',
    );
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<Task>> getTasksByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final result = await db.query(
      'tasks',
      where:
          'dueDate >= ? AND dueDate <= ? AND isDeleted = 0 AND isArchived = 0',
      whereArgs: [
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch
      ],
      orderBy: 'dueDate ASC',
    );
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<Task>> searchTasks(String query) async {
    final db = await database;
    final value = '%$query%';
    final result = await db.query(
      'tasks',
      where:
          '(title LIKE ? OR description LIKE ? OR notes LIKE ? OR category LIKE ?) AND isDeleted = 0 AND isArchived = 0',
      whereArgs: [value, value, value, value],
      orderBy: 'dueDate ASC',
    );
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> archiveTask(String id) async {
    final db = await database;
    return db.update(
      'tasks',
      {'isArchived': 1, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> restoreTask(String id) async {
    final db = await database;
    return db.update(
      'tasks',
      {
        'isArchived': 0,
        'isDeleted': 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTask(String id) async {
    final db = await database;
    return db.update(
      'tasks',
      {
        'isDeleted': 1,
        'isArchived': 1,
        'updatedAt': DateTime.now().millisecondsSinceEpoch
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTaskPermanently(String id) async {
    final db = await database;
    return db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearTasks() async {
    final db = await database;
    await db.delete('tasks');
  }

  Future<TaskCategory> createCategory(TaskCategory category) async {
    final db = await database;
    await db.insert('categories', category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return category;
  }

  Future<List<TaskCategory>> getAllCategories() async {
    final db = await database;
    final result = await db.query('categories', orderBy: 'name ASC');
    return result.map((json) => TaskCategory.fromMap(json)).toList();
  }

  Future<Habit> createHabit(Habit habit) async {
    final db = await database;
    await db.insert('habits', habit.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return habit;
  }

  Future<Habit?> getHabit(String id) async {
    final db = await database;
    final maps = await db.query('habits', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Habit.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Habit>> getAllHabits() async {
    final db = await database;
    final result = await db.query('habits', orderBy: 'createdAt DESC');
    return result.map((json) => Habit.fromMap(json)).toList();
  }

  Future<void> logHabitCompletion(String habitId, String date) async {
    final db = await database;
    await db.insert(
      'habit_logs',
      {
        'id': '$habitId-$date',
        'habitId': habitId,
        'date': date,
        'isCompleted': 1
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateHabit(Habit habit) async {
    final db = await database;
    return db.update(
      'habits',
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  Future<int> deleteHabit(String id) async {
    final db = await database;
    await db.delete('habit_logs', where: 'habitId = ?', whereArgs: [id]);
    return db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getHabitLogs(String habitId) async {
    final db = await database;
    return db.query('habit_logs',
        where: 'habitId = ?', whereArgs: [habitId], orderBy: 'date DESC');
  }

  Future<void> initDatabase() async {
    await database;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
