import 'package:flutter_test/flutter_test.dart';
import 'package:task_app/models/birthday_model.dart';

void main() {
  test('nextOccurrence returns this year when the date is still ahead', () {
    final birthday = Birthday(
      name: 'Aisha',
      birthDate: DateTime(2001, 12, 5),
    );

    final next = birthday.nextOccurrence(now: DateTime(2026, 8, 21));
    expect(next, DateTime(2026, 12, 5));
  });

  test('nextOccurrence rolls to next year when the date has passed', () {
    final birthday = Birthday(
      name: 'Rohan',
      birthDate: DateTime(1998, 2, 10),
    );

    final next = birthday.nextOccurrence(now: DateTime(2026, 8, 21));
    expect(next, DateTime(2027, 2, 10));
  });

  test('birthday today counts as zero days away', () {
    final birthday = Birthday(
      name: 'Meera',
      birthDate: DateTime(2000, 8, 21),
    );

    expect(birthday.isToday(now: DateTime(2026, 8, 21)), isTrue);
    expect(birthday.daysUntilNext(now: DateTime(2026, 8, 21)), 0);
  });

  test('ageTurningThisYear computes the upcoming age', () {
    final birthday = Birthday(
      name: 'Dev',
      birthDate: DateTime(2010, 3, 3),
    );

    expect(birthday.ageTurningThisYear, 17);
  });

  test('reminder days round-trip through the database map', () {
    final birthday = Birthday(
      name: 'Sara',
      birthDate: DateTime(1995, 11, 30),
      reminderDaysBefore: [0, 3, 7],
    );

    final restored = Birthday.fromMap(birthday.toMap());
    expect(restored.reminderDaysBefore, [0, 3, 7]);
    expect(restored.name, 'Sara');
  });
}
