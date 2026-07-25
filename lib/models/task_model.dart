import 'dart:convert';
import 'package:uuid/uuid.dart';

class Task {
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
  final List<String> checklist;
  final int reminderMinutesBefore;
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
    List<String>? checklist,
    this.reminderMinutesBefore = 0,
    this.estimatedDuration = '',
    this.completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        checklist = checklist ?? const [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? priority,
    DateTime? dueDate,
    DateTime? startTime,
    DateTime? endTime,
    bool? isCompleted,
    bool? isArchived,
    bool? isDeleted,
    bool? isFavorite,
    bool? isPinned,
    String? notes,
    String? repeatRule,
    String? color,
    List<String>? checklist,
    int? reminderMinutesBefore,
    String? estimatedDuration,
    DateTime? completedAt,
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
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isCompleted: isCompleted ?? this.isCompleted,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      isFavorite: isFavorite ?? this.isFavorite,
      isPinned: isPinned ?? this.isPinned,
      notes: notes ?? this.notes,
      repeatRule: repeatRule ?? this.repeatRule,
      color: color ?? this.color,
      checklist: checklist ?? this.checklist,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      completedAt: completedAt ?? this.completedAt,
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
      'checklist': jsonEncode(checklist),
      'reminderMinutesBefore': reminderMinutesBefore,
      'estimatedDuration': estimatedDuration,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    dynamic checklistValue = map['checklist'];
    List<String> parsedChecklist = [];
    if (checklistValue is String && checklistValue.isNotEmpty) {
      parsedChecklist = (jsonDecode(checklistValue) as List)
          .map((e) => e.toString())
          .toList();
    } else if (checklistValue is List) {
      parsedChecklist = checklistValue.map((e) => e.toString()).toList();
    }

    return Task(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'Personal',
      priority: map['priority'] ?? 'Medium',
      dueDate: _parseDate(map['dueDate']),
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
      reminderMinutesBefore: map['reminderMinutesBefore'] ?? 0,
      estimatedDuration: map['estimatedDuration'] ?? '',
      completedAt:
          map['completedAt'] != null ? _parseDate(map['completedAt']) : null,
      createdAt: map['createdAt'] != null
          ? _parseDate(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? _parseDate(map['updatedAt'])
          : DateTime.now(),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Task nextOccurrence() {
    if (repeatRule == 'Never') {
      return copyWith();
    }

    final increment = switch (repeatRule.toLowerCase()) {
      'daily' => const Duration(days: 1),
      'weekly' => const Duration(days: 7),
      'monthly' => const Duration(days: 30),
      'yearly' => const Duration(days: 365),
      _ => const Duration(days: 1),
    };

    return copyWith(
      dueDate: dueDate.add(increment),
      isCompleted: false,
      completedAt: null,
      updatedAt: DateTime.now(),
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
