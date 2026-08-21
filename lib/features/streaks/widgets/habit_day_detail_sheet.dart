import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/habit_completion_item.dart';
import '../../../models/habit_model.dart';
import '../../../providers/task_provider.dart';

/// Bottom sheet shown when tapping a 🔥 (completed) date on the streak
/// history calendar. Displays the checklist snapshotted when the habit was
/// completed on that specific day.
Future<void> showHabitDayDetailSheet(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
  DateTime day,
) {
  final dateOnly = DateTime(day.year, day.month, day.day);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _HabitDayDetailSheet(habit: habit, day: dateOnly),
  );
}

class _HabitDayDetailSheet extends ConsumerWidget {
  final Habit habit;
  final DateTime day;

  const _HabitDayDetailSheet({required this.habit, required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final checklistAsync = ref.watch(habitCompletionChecklistProvider(
      completionChecklistKey(habit.id, habitDateKey(day)),
    ));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('d MMMM yyyy').format(day),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        habit.name,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            checklistAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Could not load the checklist for this day.',
                  style:
                      TextStyle(color: theme.colorScheme.error, fontSize: 14),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No checklist recorded for this day.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final item in items)
                      _CompletionTile(item: item),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionTile extends StatelessWidget {
  final HabitCompletionItem item;

  const _CompletionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.completed ? Colors.green : Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            item.completed
                ? Icons.check_box
                : Icons.check_box_outline_blank,
            size: 22,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.text,
              style: TextStyle(
                fontSize: 15,
                color: item.completed
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
