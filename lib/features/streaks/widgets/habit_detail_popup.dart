import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/habit_model.dart';
import '../../../providers/task_provider.dart';
import 'habit_day_detail_sheet.dart';

/// Streak History view for a single habit: a calendar where every completed
/// day is marked with a 🔥. Tapping a 🔥 day opens that day's snapshotted
/// checklist; tapping any other day explains the habit was not completed.
class HabitDetailPopup extends ConsumerStatefulWidget {
  final Habit habit;

  const HabitDetailPopup({
    super.key,
    required this.habit,
  });

  @override
  ConsumerState createState() => _HabitDetailPopupState();
}

class _HabitDetailPopupState extends ConsumerState<HabitDetailPopup> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// Accepts both legacy keys ('{habitId}-yyyy-MM-dd') and plain
  /// 'yyyy-MM-dd' keys — the date is always the trailing 10 characters.
  DateTime? _parseDateKey(dynamic raw) {
    if (raw is! String || raw.length < 10) return null;
    return DateTime.tryParse(raw.substring(raw.length - 10));
  }

  Set<DateTime> _completedDatesFrom(List<Map<String, dynamic>> logs) {
    return {
      for (final log in logs)
        if (_parseDateKey(log['date']) case final DateTime date)
          DateTime(date.year, date.month, date.day),
    };
  }

  Future<void> _handleDayTap(DateTime selectedDay, DateTime focusedDay) async {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    final day =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final logs = ref.read(habitLogsProvider(widget.habit.id)).value;
    final isCompleted =
        logs != null && _completedDatesFrom(logs).contains(day);

    if (isCompleted) {
      await showHabitDayDetailSheet(context, ref, widget.habit, day);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Habit not completed on this day.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logsAsync = ref.watch(habitLogsProvider(widget.habit.id));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.habit.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
            logsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load streak history.',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
              data: (logs) {
                final completedDates = _completedDatesFrom(logs);
                return TableCalendar(
                  firstDay: DateTime(2020),
                  lastDay: DateTime.now(),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  onDaySelected: _handleDayTap,
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, date, focusedDay) =>
                        _buildDayCell(date, focusedDay, completedDates),
                    todayBuilder: (context, date, focusedDay) => _buildDayCell(
                        date, focusedDay, completedDates,
                        isToday: true),
                    selectedBuilder: (context, date, focusedDay) =>
                        _buildDayCell(date, focusedDay, completedDates,
                            isSelected: true),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(
    DateTime date,
    DateTime focusedDay,
    Set<DateTime> completedDates, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    if (date.month != focusedDay.month || date.year != focusedDay.year) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isFuture = date.isAfter(DateTime.now());
    final isCompleted = completedDates.contains(
      DateTime(date.year, date.month, date.day),
    );

    Color? background;
    if (isSelected) {
      background = colorScheme.primary;
    } else if (isToday) {
      background = colorScheme.primaryContainer;
    }

    final numberColor = isSelected
        ? colorScheme.onPrimary
        : isFuture
            ? colorScheme.outline.withValues(alpha: 0.4)
            : colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: isToday && !isSelected
            ? Border.all(color: colorScheme.primary, width: 1.4)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 14,
              height: 1.1,
              color: numberColor,
              fontWeight:
                  isToday || isCompleted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isCompleted && !isFuture)
            const Text(
              '🔥',
              style: TextStyle(fontSize: 9, height: 1),
            ),
        ],
      ),
    );
  }
}
