import 'package:uuid/uuid.dart';

class Birthday {
  final String id;
  final String name;
  final DateTime birthDate;
  final String phone;
  final String notes;
  final List<int> reminderDaysBefore;
  final int reminderHour;
  final int reminderMinute;
  final DateTime createdAt;

  Birthday({
    String? id,
    required this.name,
    required this.birthDate,
    this.phone = '',
    this.notes = '',
    List<int>? reminderDaysBefore,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        reminderDaysBefore = reminderDaysBefore ?? const [0],
        createdAt = createdAt ?? DateTime.now();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime nextOccurrence({DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    var next = _safeDate(today.year, birthDate.month, birthDate.day);
    if (next.isBefore(today)) {
      next = _safeDate(today.year + 1, birthDate.month, birthDate.day);
    }
    return next;
  }

  /// Creates a DateTime, clamping the day to the last valid day of the month.
  /// This handles Feb 29 birthdays on non-leap years (falls back to Feb 28).
  static DateTime _safeDate(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, lastDay));
  }

  int daysUntilNext({DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final next = nextOccurrence(now: today);
    // Compare via UTC midnights so DST shifts can never skew the day count.
    return DateTime.utc(next.year, next.month, next.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;
  }

  int get ageTurningThisYear {
    final now = DateTime.now();
    final next = nextOccurrence(now: now);
    return next.year - birthDate.year;
  }

  bool isToday({DateTime? now}) => daysUntilNext(now: now) == 0;

  /// Returns the next occurrence as a full DateTime with the configured
  /// reminder time applied (hour + minute).
  DateTime nextOccurrenceWithReminderTime({DateTime? now}) {
    final next = nextOccurrence(now: now);
    return DateTime(next.year, next.month, next.day, reminderHour, reminderMinute);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'birthDate': birthDate.millisecondsSinceEpoch,
        'phone': phone,
        'notes': notes,
        'reminderDaysBefore': reminderDaysBefore.join(','),
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Birthday.fromMap(Map<String, dynamic> map) {
    dynamic rawDays = map['reminderDaysBefore'];
    List<int> days = [];
    if (rawDays is String && rawDays.isNotEmpty) {
      days = rawDays
          .split(',')
          .map((e) => int.tryParse(e.trim()) ?? -1)
          .where((e) => e >= 0)
          .toList();
    } else if (rawDays is List) {
      days = rawDays.map((e) => e is int ? e : int.tryParse('$e') ?? -1).where((e) => e >= 0).toList();
    }

    dynamic rawDate = map['birthDate'];
    DateTime birthDate;
    if (rawDate is int) {
      birthDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else if (rawDate is String) {
      birthDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      birthDate = DateTime.now();
    }

    return Birthday(
      id: map['id'],
      name: map['name'] ?? '',
      birthDate: birthDate,
      phone: map['phone'] ?? '',
      notes: map['notes'] ?? '',
      reminderDaysBefore: days.isEmpty ? const [0] : days,
      reminderHour: map['reminderHour'] is int ? map['reminderHour'] : 9,
      reminderMinute: map['reminderMinute'] is int ? map['reminderMinute'] : 0,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }
}
