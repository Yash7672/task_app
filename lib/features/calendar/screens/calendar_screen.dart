import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../providers/task_provider.dart';
import '../../dashboard/widgets/task_list_item.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksMap = ref.watch(tasksByDateProvider);
    final selectedDate = ValueNotifier<DateTime>(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: ValueListenableBuilder<DateTime>(
        valueListenable: selectedDate,
        builder: (context, date, _) {
          final normalizedDate = DateTime(date.year, date.month, date.day);
          final selectedTasks = tasksMap[normalizedDate] ?? [];

          return ListView(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: date,
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                },
                headerStyle: const HeaderStyle(formatButtonVisible: false),
                selectedDayPredicate: (day) => isSameDay(day, date),
                onDaySelected: (selectedDay, _) =>
                    selectedDate.value = selectedDay,
                eventLoader: (day) {
                  final d = DateTime(day.year, day.month, day.day);
                  return tasksMap[d] ?? [];
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Tasks for ${date.day}/${date.month}/${date.year}',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (selectedTasks.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No tasks scheduled for this day.'))
              else
                ...selectedTasks.map((task) => TaskListItem(task: task)),
            ],
          );
        },
      ),
    );
  }
}
