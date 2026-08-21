import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/notification_helper.dart';
import '../database/database_helper.dart';
import '../models/birthday_model.dart';
import 'database_provider.dart';

final birthdayProvider =
    StateNotifierProvider<BirthdayNotifier, AsyncValue<List<Birthday>>>((ref) {
  final dbHelper = ref.watch(databaseProvider);
  return BirthdayNotifier(dbHelper);
});

class BirthdayNotifier extends StateNotifier<AsyncValue<List<Birthday>>> {
  final DatabaseHelper dbHelper;

  BirthdayNotifier(this.dbHelper) : super(const AsyncValue.loading()) {
    loadBirthdays();
  }

  Future<void> loadBirthdays() async {
    try {
      final birthdays = await dbHelper.getAllBirthdays();
      final sorted = [...birthdays]..sort((a, b) =>
          a.daysUntilNext().compareTo(b.daysUntilNext()));
      state = AsyncValue.data(sorted);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  List<Birthday> get _current =>
      state.maybeWhen(data: (b) => b, orElse: () => []);

  void _resort() {
    final sorted = [..._current]..sort((a, b) =>
        a.daysUntilNext().compareTo(b.daysUntilNext()));
    state = AsyncValue.data(sorted);
  }

  Future<void> addBirthday(Birthday birthday,
      {bool notificationsEnabled = true}) async {
    try {
      await dbHelper.createBirthday(birthday);
      state = AsyncValue.data([..._current, birthday]);
      _resort();
      if (notificationsEnabled) {
        await NotificationHelper.scheduleBirthdayReminders(
          birthdayId: birthday.id,
          name: birthday.name,
          nextBirthday: birthday.nextOccurrence(),
          reminderDaysBefore: birthday.reminderDaysBefore,
        );
      }
    } catch (e) {
      debugPrint('Error adding birthday: $e');
    }
  }

  Future<void> updateBirthday(Birthday birthday,
      {bool notificationsEnabled = true}) async {
    try {
      await dbHelper.updateBirthday(birthday);
      final list = _current;
      final index = list.indexWhere((b) => b.id == birthday.id);
      if (index != -1) {
        final updated = List<Birthday>.from(list);
        updated[index] = birthday;
        state = AsyncValue.data(updated);
        _resort();
      }
      await NotificationHelper.cancelAllForBirthday(birthday.id);
      if (notificationsEnabled) {
        await NotificationHelper.scheduleBirthdayReminders(
          birthdayId: birthday.id,
          name: birthday.name,
          nextBirthday: birthday.nextOccurrence(),
          reminderDaysBefore: birthday.reminderDaysBefore,
        );
      }
    } catch (e) {
      debugPrint('Error updating birthday: $e');
    }
  }

  Future<void> deleteBirthday(String id) async {
    try {
      await NotificationHelper.cancelAllForBirthday(id);
      await dbHelper.deleteBirthday(id);
      state = AsyncValue.data(_current.where((b) => b.id != id).toList());
    } catch (e) {
      debugPrint('Error deleting birthday: $e');
    }
  }
}
