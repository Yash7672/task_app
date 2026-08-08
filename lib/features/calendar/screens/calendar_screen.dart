import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/task_model.dart';
import '../../../providers/task_provider.dart';
import '../../dashboard/widgets/task_list_item.dart';

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
    final visibleTasks =
        tasks.where((task) => !task.isDeleted && !task.isArchived).toList();

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
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            selectedDayPredicate: (day) => isSameDay(day, _selectedDate),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) => visibleTasks
                .where((task) => isSameDay(task.dueDate, day))
                .toList(),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
                'Tasks for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          ..._selectedTasksFor(visibleTasks, _selectedDate),
        ],
      ),
    );
  }

  List<Widget> _selectedTasksFor(List<Task> tasks, DateTime date) {
    final selectedTasks = tasks.where((task) {
      return isSameDay(task.dueDate, date);
    }).toList();

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
