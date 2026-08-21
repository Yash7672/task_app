import 'package:uuid/uuid.dart';

/// A single checklist entry snapshotted at the moment a habit was completed.
///
/// Instances are immutable historical records keyed by [habitId] +
/// [completionDate]. They are never updated after the day has passed, so
/// editing today's log never rewrites previous days' history.
class HabitCompletionItem {
  final String id;
  final String habitId;
  final String completionDate; // 'yyyy-MM-dd'
  final String text;
  final bool completed;
  final int position;

  HabitCompletionItem({
    String? id,
    required this.habitId,
    required this.completionDate,
    required this.text,
    this.completed = true,
    this.position = 0,
  }) : id = id ?? const Uuid().v4();

  HabitCompletionItem copyWith({
    String? id,
    String? habitId,
    String? completionDate,
    String? text,
    bool? completed,
    int? position,
  }) {
    return HabitCompletionItem(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      completionDate: completionDate ?? this.completionDate,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habitId': habitId,
      'completionDate': completionDate,
      'text': text,
      'completed': completed ? 1 : 0,
      'position': position,
    };
  }

  factory HabitCompletionItem.fromMap(Map<String, dynamic> map) {
    return HabitCompletionItem(
      id: map['id'] as String,
      habitId: map['habitId'] as String? ?? '',
      completionDate: map['completionDate'] as String? ?? '',
      text: map['text'] as String? ?? '',
      completed: (map['completed'] as int? ?? 1) == 1,
      position: map['position'] as int? ?? 0,
    );
  }
}
