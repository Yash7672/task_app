import 'package:uuid/uuid.dart';

class HabitLogItem {
  final String id;
  final String logId;
  final String text;
  final int position;

  HabitLogItem({
    String? id,
    required this.logId,
    required this.text,
    this.position = 0,
  }) : id = id ?? const Uuid().v4();

  HabitLogItem copyWith({
    String? id,
    String? logId,
    String? text,
    int? position,
  }) {
    return HabitLogItem(
      id: id ?? this.id,
      logId: logId ?? this.logId,
      text: text ?? this.text,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'logId': logId,
      'text': text,
      'position': position,
    };
  }

  factory HabitLogItem.fromMap(Map<String, dynamic> map) {
    return HabitLogItem(
      id: map['id'],
      logId: map['logId'] ?? '',
      text: map['text'] ?? '',
      position: map['position'] ?? 0,
    );
  }
}
