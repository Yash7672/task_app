import 'package:uuid/uuid.dart';

class FocusSession {
  final String id;
  final String? taskId;
  final String label;
  final DateTime startTime;
  final DateTime endTime;
  final int plannedMinutes;
  final bool completed;

  FocusSession({
    String? id,
    this.taskId,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.plannedMinutes,
    required this.completed,
  }) : id = id ?? const Uuid().v4();

  int get actualMinutes => endTime.difference(startTime).inMinutes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'label': label,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'plannedMinutes': plannedMinutes,
        'completed': completed ? 1 : 0,
      };

  factory FocusSession.fromMap(Map<String, dynamic> map) {
    return FocusSession(
      id: map['id'],
      taskId: map['taskId'],
      label: map['label'] ?? '',
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] ?? 0),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] ?? 0),
      plannedMinutes: map['plannedMinutes'] ?? 0,
      completed: map['completed'] == 1 || map['completed'] == true,
    );
  }
}
