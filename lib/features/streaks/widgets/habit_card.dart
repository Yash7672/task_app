import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/dialog_disposer.dart';
import '../../../models/habit_model.dart';
import '../../../providers/task_provider.dart';
import 'habit_complete_sheet.dart';
import 'habit_detail_popup.dart';

class HabitCard extends ConsumerWidget {
  final Habit habit;

  const HabitCard({
    super.key,
    required this.habit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompletedToday = habit.isCompletedToday;
    final effectiveStreak = habit.effectiveCurrentStreak();
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetailPopup(context, habit),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: icon + name + status badge ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCompletedToday
                          ? Colors.green.withValues(alpha: 0.12)
                          : theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_fire_department,
                      color: isCompletedToday ? Colors.green : Colors.orange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (habit.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            habit.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isCompletedToday
                          ? Colors.green
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: isCompletedToday
                          ? null
                          : Border.all(
                              color: Colors.grey.withValues(alpha: 0.4),
                              width: 1,
                            ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCompletedToday
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 14,
                          color: isCompletedToday
                              ? Colors.white
                              : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCompletedToday ? 'COMPLETED' : 'PENDING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isCompletedToday
                                ? Colors.white
                                : Colors.grey[500],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Streak info ──
              Row(
                children: [
                  Expanded(
                    child: _InfoTile(
                      icon: Icons.local_fire_department,
                      label: 'Current Streak',
                      value: '$effectiveStreak Days',
                      color: effectiveStreak > 0 ? Colors.orange : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoTile(
                      icon: Icons.emoji_events_outlined,
                      label: 'Best Streak',
                      value: '${habit.bestStreak} Days',
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Last completed ──
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    'Last Completed: ${habit.getLastCompletedLabel(referenceDate: DateTime.now())}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Actions ──
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          showHabitCompleteSheet(context, ref, habit),
                      icon: Icon(
                        isCompletedToday ? Icons.check_circle : Icons.check,
                        size: 18,
                      ),
                      label: Text(
                        isCompletedToday ? 'Completed Today' : 'Complete Today',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: isCompletedToday
                            ? Colors.grey.withValues(alpha: 0.25)
                            : Colors.green,
                        foregroundColor: isCompletedToday
                            ? Colors.grey[600]
                            : Colors.white,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () =>
                        _showEditHabitDialog(context, ref, habit),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit',
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        _showDeleteConfirmation(context, ref, habit),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Delete',
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.red[400],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailPopup(BuildContext context, Habit habit) {
    showDialog(
      context: context,
      builder: (context) => HabitDetailPopup(habit: habit),
    );
  }

  Future<void> _showEditHabitDialog(
      BuildContext context, WidgetRef ref, Habit habit) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController(text: habit.name);
    final descriptionController =
        TextEditingController(text: habit.description);

    final result = await showDialog<Habit>(
      context: context,
      builder: (context) => DisposeOnExit(
        controllers: [nameController, descriptionController],
        child: AlertDialog(
          title: const Text('Edit Streak'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Streak Name',
                  prefixIcon: Icon(Icons.local_fire_department),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.pop(
                    context,
                    habit.copyWith(
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim(),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await ref.read(habitsProvider.notifier).updateHabit(result);
      final _ = ref.refresh(habitsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Streak updated!')),
      );
    }
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context, WidgetRef ref, Habit habit) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Streak?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(habitsProvider.notifier).deleteHabit(habit.id);
      final _ = ref.refresh(habitsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Streak deleted!')),
      );
    }
  }
}

// ── Info tile used for streak stats ──

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
