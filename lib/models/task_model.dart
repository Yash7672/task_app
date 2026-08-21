import 'dart:convert';
import 'package:uuid/uuid.dart';

class ChecklistItemData {
  final String text;
  final bool done;

  const ChecklistItemData({
    required this.text,
    this.done = false,
  });

  ChecklistItemData copyWith({String? text, bool? done}) {
    return ChecklistItemData(
      text: text ?? this.text,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toMap() => {'text': text, 'done': done ? 1 : 0};

  factory ChecklistItemData.fromMap(Map<String, dynamic> map) {
    return ChecklistItemData(
      text: map['text']?.toString() ?? '',
      done: map['done'] == 1 || map['done'] == true,
    );
  }

  factory ChecklistItemData.fromString(String text) {
    return ChecklistItemData(text: text);
  }
}

class Task {
  static const _clear = Object();

  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final DateTime dueDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isCompleted;
  final bool isArchived;
  final bool isDeleted;
  final bool isFavorite;
  final bool isPinned;
  final String notes;
  final String repeatRule;
  final String color;
  final List<ChecklistItemData> checklist;
  final List<int> reminderMinutes;
  final String estimatedDuration;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    String? id,
    required this.title,
    this.description = '',
    required this.category,
    this.priority = 'Medium',
    required this.dueDate,
    this.startTime,
    this.endTime,
    this.isCompleted = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.isFavorite = false,
    this.isPinned = false,
    this.notes = '',
    this.repeatRule = 'Never',
    this.color = '',
    List<ChecklistItemData>? checklist,
    List<int>? reminderMinutes,
    this.estimatedDuration = '',
    this.completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        checklist = checklist ?? const [],
        reminderMinutes = reminderMinutes ?? const [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? priority,
    DateTime? dueDate,
    Object? startTime = _clear,
    Object? endTime = _clear,
    bool? isCompleted,
    bool? isArchived,
    bool? isDeleted,
    bool? isFavorite,
    bool? isPinned,
    String? notes,
    String? repeatRule,
    String? color,
    List<ChecklistItemData>? checklist,
    List<int>? reminderMinutes,
    String? estimatedDuration,
    Object? completedAt = _clear,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      startTime: startTime == _clear ? this.startTime : startTime as DateTime?,
      endTime: endTime == _clear ? this.endTime : endTime as DateTime?,
      isCompleted: isCompleted ?? this.isCompleted,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      isFavorite: isFavorite ?? this.isFavorite,
      isPinned: isPinned ?? this.isPinned,
      notes: notes ?? this.notes,
      repeatRule: repeatRule ?? this.repeatRule,
      color: color ?? this.color,
      checklist: checklist ?? this.checklist,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      completedAt:
          completedAt == _clear ? this.completedAt : completedAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'dueDate': dueDate.millisecondsSinceEpoch,
      'startTime': startTime?.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'isCompleted': isCompleted ? 1 : 0,
      'isArchived': isArchived ? 1 : 0,
      'isDeleted': isDeleted ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
      'isPinned': isPinned ? 1 : 0,
      'notes': notes,
      'repeatRule': repeatRule,
      'color': color,
      'checklist':
          jsonEncode(checklist.map((item) => item.toMap()).toList()),
      'reminderMinutes': jsonEncode(reminderMinutes),
      'estimatedDuration': estimatedDuration,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    dynamic checklistValue = map['checklist'];
    List<ChecklistItemData> parsedChecklist = [];
    if (checklistValue is String && checklistValue.isNotEmpty) {
      try {
        final decoded = jsonDecode(checklistValue) as List;
        for (final entry in decoded) {
          if (entry is Map) {
            parsedChecklist.add(ChecklistItemData.fromMap(
                Map<String, dynamic>.from(entry)));
          } else if (entry is String && entry.isNotEmpty) {
            parsedChecklist.add(ChecklistItemData.fromString(entry));
          }
        }
      } catch (_) {}
    } else if (checklistValue is List) {
      for (final entry in checklistValue) {
        if (entry is Map) {
          parsedChecklist.add(
              ChecklistItemData.fromMap(Map<String, dynamic>.from(entry)));
        } else if (entry is String && entry.isNotEmpty) {
          parsedChecklist.add(ChecklistItemData.fromString(entry));
        }
      }
    }

    dynamic reminderValue = map['reminderMinutes'];
    List<int> parsedReminders = [];
    if (reminderValue is String && reminderValue.isNotEmpty) {
      parsedReminders = (jsonDecode(reminderValue) as List)
          .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .toList();
    } else if (reminderValue is List) {
      parsedReminders =
          reminderValue.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList();
    } else if (reminderValue == null && map['reminderMinutesBefore'] != null) {
      final oldVal = map['reminderMinutesBefore'];
      if (oldVal is int && oldVal > 0) {
        parsedReminders = [oldVal];
      }
    }

    final createdAt = map['createdAt'] != null
        ? _parseDate(map['createdAt'])
        : DateTime.now();
    final updatedAt = map['updatedAt'] != null
        ? _parseDate(map['updatedAt'])
        : DateTime.now();

    return Task(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'Personal',
      priority: map['priority'] ?? 'Medium',
      dueDate: _parseDate(map['dueDate'], fallback: createdAt),
      startTime: map['startTime'] != null ? _parseDate(map['startTime']) : null,
      endTime: map['endTime'] != null ? _parseDate(map['endTime']) : null,
      isCompleted: map['isCompleted'] == 1,
      isArchived: map['isArchived'] == 1,
      isDeleted: map['isDeleted'] == 1,
      isFavorite: map['isFavorite'] == 1,
      isPinned: map['isPinned'] == 1,
      notes: map['notes'] ?? '',
      repeatRule: map['repeatRule'] ?? 'Never',
      color: map['color'] ?? '',
      checklist: parsedChecklist,
      reminderMinutes: parsedReminders,
      estimatedDuration: map['estimatedDuration'] ?? '',
      completedAt:
          map['completedAt'] != null ? _parseDate(map['completedAt']) : null,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime _parseDate(dynamic value, {DateTime? fallback}) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      final millis = int.tryParse(value);
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
      return DateTime.tryParse(value) ?? (fallback ?? DateTime.now());
    }
    return fallback ?? DateTime.now();
  }

  Task nextOccurrence() {
    if (repeatRule == 'Never') {
      return copyWith();
    }

    final DateTime nextDate;
    switch (repeatRule.toLowerCase()) {
      case 'daily':
        nextDate = dueDate.add(const Duration(days: 1));
      case 'weekly':
        nextDate = dueDate.add(const Duration(days: 7));
      case 'monthly':
        var year = dueDate.year;
        var month = dueDate.month + 1;
        if (month > 12) {
          month = 1;
          year++;
        }
        final lastDay = DateTime(year, month + 1, 0).day;
        nextDate =
            DateTime(year, month, dueDate.day.clamp(1, lastDay));
      case 'yearly':
        final year = dueDate.year + 1;
        final lastDay = DateTime(year, dueDate.month + 1, 0).day;
        nextDate = DateTime(
            year, dueDate.month, dueDate.day.clamp(1, lastDay));
      default:
        nextDate = dueDate.add(const Duration(days: 1));
    }

    return copyWith(
      dueDate: nextDate,
      isCompleted: false,
      completedAt: null,
      updatedAt: DateTime.now(),
    );
  }

  Task regenerate() {
    final next = nextOccurrence();
    final delta = next.dueDate.difference(dueDate);

    return Task(
      id: null,
      title: title,
      description: description,
      category: category,
      priority: priority,
      dueDate: next.dueDate,
      startTime: startTime?.add(delta),
      endTime: endTime?.add(delta),
      notes: notes,
      repeatRule: repeatRule,
      color: color,
      checklist: List<ChecklistItemData>.from(checklist),
      reminderMinutes: List<int>.from(reminderMinutes),
      estimatedDuration: estimatedDuration,
    );
  }

  Task restore() {
    return copyWith(
      isArchived: false,
      isDeleted: false,
      updatedAt: DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) => Task.fromMap(json.decode(source));
}
