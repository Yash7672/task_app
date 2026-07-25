import 'dart:convert';
import 'package:uuid/uuid.dart';

class TaskCategory {
  final String id;
  final String name;
  final String colorHex;
  final String? icon; // can store an emoji or icon name

  TaskCategory({
    String? id,
    required this.name,
    required this.colorHex,
    this.icon,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorHex': colorHex,
      'icon': icon,
    };
  }

  factory TaskCategory.fromMap(Map<String, dynamic> map) {
    return TaskCategory(
      id: map['id'],
      name: map['name'],
      colorHex: map['colorHex'],
      icon: map['icon'],
    );
  }

  String toJson() => json.encode(toMap());

  factory TaskCategory.fromJson(String source) => TaskCategory.fromMap(json.decode(source));
}
