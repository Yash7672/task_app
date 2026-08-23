import 'dart:convert';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';

class Habit {
  final String id;
  final String name;
  final String description;
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastCompletedDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Habit({
    String? id,
    required this.name,
    this.description = '',
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastCompletedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isCompletedToday {
    final today = _startOfDay(DateTime.now());
    return lastCompletedDate != null && _isSameDay(lastCompletedDate!, today);
  }

  bool isCompletedOnDate(DateTime date) {
    return lastCompletedDate != null &&
        _isSameDay(lastCompletedDate!, _startOfDay(date));
  }

  Habit copyWith({
    String? id,
    String? name,
    String? description,
    int? currentStreak,
    int? bestStreak,
    DateTime? lastCompletedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Whole calendar days from [from] to [to] (positive when [to] is later).
  /// Uses UTC date components so DST transitions can never skew the count.
  static int calendarDaysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// The calendar day before [date] — component math, immune to DST shifts
  /// (subtracting an absolute 24h from midnight breaks after spring-forward).
  static DateTime calendarDayBefore(DateTime date) {
    return DateTime(date.year, date.month, date.day - 1);
  }

  /// Streak as it should be displayed right now: a stored counter goes stale
  /// once days pass without completion, so it decays to zero when the last
  /// completion is older than yesterday.
  int effectiveCurrentStreak({DateTime? now}) {
    if (lastCompletedDate == null || currentStreak <= 0) return 0;
    final today = _startOfDay(now ?? DateTime.now());
    final gap = calendarDaysBetween(_startOfDay(lastCompletedDate!), today);
    return gap <= 1 ? currentStreak : 0;
  }

  Habit markCompleted({required DateTime now}) {
    final today = _startOfDay(now);
    if (lastCompletedDate != null && _isSameDay(lastCompletedDate!, today)) {
      return this;
    }

    int nextCurrentStreak = 1;
    int nextBestStreak = math.max(bestStreak, 1);

    if (lastCompletedDate != null) {
      final previousDay = _startOfDay(lastCompletedDate!);
      final yesterday = calendarDayBefore(today);

      if (_isSameDay(previousDay, yesterday)) {
        nextCurrentStreak = currentStreak + 1;
        nextBestStreak = math.max(bestStreak, nextCurrentStreak);
      } else if (calendarDaysBetween(previousDay, today) > 1) {
        nextCurrentStreak = 1;
      }
    }

    return copyWith(
      currentStreak: nextCurrentStreak,
      bestStreak: nextBestStreak,
      lastCompletedDate: today,
      updatedAt: now,
    );
  }

  String getLastCompletedLabel({DateTime? referenceDate}) {
    final today = _startOfDay(referenceDate ?? DateTime.now());
    if (lastCompletedDate == null) {
      return 'Never';
    }

    final differenceInDays =
        calendarDaysBetween(_startOfDay(lastCompletedDate!), today);

    if (differenceInDays <= 0) {
      return 'Today';
    }
    if (differenceInDays == 1) {
      return 'Yesterday';
    }
    return '$differenceInDays days ago';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'lastCompletedDate': lastCompletedDate?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'],
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      currentStreak: map['currentStreak'] ?? 0,
      bestStreak: map['bestStreak'] ?? 0,
      lastCompletedDate: map['lastCompletedDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastCompletedDate'])
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          map['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  static DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return _startOfDay(a).isAtSameMomentAs(_startOfDay(b));
  }

  String toJson() => json.encode(toMap());

  factory Habit.fromJson(String source) => Habit.fromMap(json.decode(source));
}
