import 'package:uuid/uuid.dart';

class Birthday {
  final String id;
  final String name;
  final DateTime birthDate;
  final String phone;
  final String notes;
  final List<int> reminderDaysBefore;
  final DateTime createdAt;

  Birthday({
    String? id,
    required this.name,
    required this.birthDate,
    this.phone = '',
    this.notes = '',
    List<int>? reminderDaysBefore,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        reminderDaysBefore = reminderDaysBefore ?? const [0],
        createdAt = createdAt ?? DateTime.now();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  /// Occurrence of the birthday within [year]. Feb 29 birthdays are clamped
  /// to Feb 28 in common years (DateTime would otherwise roll over to Mar 1).
  DateTime _occurrenceIn(int year) {
    var day = birthDate.day;
    if (birthDate.month == 2 && day == 29 && !_isLeapYear(year)) {
      day = 28;
    }
    return DateTime(year, birthDate.month, day);
  }

  DateTime nextOccurrence({DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    var next = _occurrenceIn(today.year);
    if (next.isBefore(today)) {
      next = _occurrenceIn(today.year + 1);
    }
    return next;
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

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'birthDate': birthDate.millisecondsSinceEpoch,
        'phone': phone,
        'notes': notes,
        'reminderDaysBefore': reminderDaysBefore.join(','),
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
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }
}
