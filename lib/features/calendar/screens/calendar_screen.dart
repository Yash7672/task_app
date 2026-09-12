import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/widgets/glass_components.dart';
import '../../../models/task_model.dart';
import '../../../providers/task_provider.dart';
import '../../../theme/app_theme.dart';
import '../../dashboard/widgets/task_list_item.dart';

/// Shared, theme-aware styling for [TableCalendar]. Without it the calendar
/// hardcodes white/light defaults and turns into a bright panel on the dark
/// Glass background.
class PyloCalendarStyle {

  /// Glass styling for the calendar header (month title + chevrons).
  static HeaderStyle header(BuildContext context) => const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: GlassColors.textPrimary,
        ),
        leftChevronIcon: Icon(Icons.chevron_left,
            color: GlassColors.textSecondary),
        rightChevronIcon: Icon(Icons.chevron_right,
            color: GlassColors.textSecondary),
      );

  /// Glass styling for the weekday labels row.
  static DaysOfWeekStyle daysOfWeek(BuildContext context) =>
      const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: GlassColors.textMuted),
        weekendStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: GlassColors.textMuted),
      );

  /// Glass styling for the day grid (text, selection, today, markers).
  static CalendarStyle calendar(BuildContext context) => const CalendarStyle(
        outsideDaysVisible: false,
        cellAlignment: Alignment.center,
        defaultTextStyle: TextStyle(color: GlassColors.textPrimary),
        weekendTextStyle: TextStyle(color: GlassColors.textSecondary),
        outsideTextStyle: TextStyle(color: GlassColors.textFaint),
        selectedDecoration: BoxDecoration(
          color: GlassColors.accent,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(
            color: GlassColors.onAccent, fontWeight: FontWeight.w700),
        todayDecoration: BoxDecoration(
          color: GlassColors.accentSubtle,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
              BorderSide(color: GlassColors.accent)),
        ),
        todayTextStyle: TextStyle(
            color: GlassColors.accent, fontWeight: FontWeight.w700),
        markerDecoration: BoxDecoration(
          color: GlassColors.accent,
          shape: BoxShape.circle,
        ),
        markerSize: 5,
        markersMaxCount: 3,
        rowDecoration: BoxDecoration(color: Colors.transparent),
        tablePadding: EdgeInsets.symmetric(horizontal: 4),
      );
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(allTasksProvider);

    // Pre-compute O(N) once instead of O(42*N) per eventLoader call
    final tasksByDay = <DateTime, List<Task>>{};
    for (final task in tasks) {
      if (task.isDeleted || task.isArchived) continue;
      final day = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      tasksByDay.putIfAbsent(day, () => []).add(task);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: ListView(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
            },
            headerStyle: isGlassTheme(context)
                ? PyloCalendarStyle.header(context)
                : const HeaderStyle(formatButtonVisible: false),
            daysOfWeekStyle: isGlassTheme(context)
                ? PyloCalendarStyle.daysOfWeek(context)
                : const DaysOfWeekStyle(),
            calendarStyle: isGlassTheme(context)
                ? PyloCalendarStyle.calendar(context)
                : const CalendarStyle(),
            selectedDayPredicate: (day) => isSameDay(day, _selectedDate),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) =>
                tasksByDay[DateTime(day.year, day.month, day.day)] ??
                const [],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
                'Tasks for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          ..._buildSelectedTasks(tasksByDay, _selectedDate),
        ],
      ),
    );
  }

  List<Widget> _buildSelectedTasks(Map<DateTime, List<Task>> tasksByDay, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final selectedTasks = tasksByDay[day] ?? [];

    if (selectedTasks.isEmpty) {
      return const [
        Padding(
            padding: EdgeInsets.all(16),
            child: Text('No tasks scheduled for this day.')),
      ];
    }
    return selectedTasks.map((task) => TaskListItem(task: task)).toList();
  }
}
