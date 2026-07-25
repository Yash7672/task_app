import 'package:intl/intl.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

extension DateExtension on DateTime {
  String toFormattedString() {
    return DateFormat('yyyy-MM-dd').format(this);
  }

  String toDisplayString() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final checkDate = DateTime(year, month, day);

    if (checkDate == today) {
      return 'Today';
    } else if (checkDate == tomorrow) {
      return 'Tomorrow';
    } else {
      return DateFormat('MMM dd, yyyy').format(this);
    }
  }

  bool isSameDate(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}
