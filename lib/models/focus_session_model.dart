import 'package:uuid/uuid.dart';

enum FocusMode {
  normal,
  strict;

  String get label => switch (this) {
        FocusMode.normal => 'Normal Focus',
        FocusMode.strict => 'Strict Focus',
      };

  String get description => switch (this) {
        FocusMode.normal =>
          'Light restrictions. Exit with confirmation.',
        FocusMode.strict =>
          'Strong protection. PIN required to end early.',
      };

  static FocusMode fromName(String? name) => FocusMode.values.firstWhere(
        (v) => v.name == name,
        orElse: () => FocusMode.normal,
      );
}

class FocusSession {
  final String id;
  final String? taskId;
  final String label;
  final DateTime startTime;
  final DateTime endTime;
  final int plannedMinutes;
  final bool completed;
  final FocusMode mode;

  FocusSession({
    String? id,
    this.taskId,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.plannedMinutes,
    required this.completed,
    this.mode = FocusMode.normal,
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
        'mode': mode.name,
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
      mode: FocusMode.fromName(map['mode']),
    );
  }
}
