import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/habit_model.dart';
import '../../../providers/task_provider.dart';
import 'habit_detail_popup.dart';

class HabitCard extends ConsumerStatefulWidget {
  final Habit habit;

  const HabitCard({
    super.key,
    required this.habit,
  });

  @override
  ConsumerState createState() => _HabitCardState();
}

class _HabitCardState extends ConsumerState<HabitCard> {
  bool _isCompleting = false;

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final isCompletedToday = habit.isCompletedToday;
    final streakEmoji = _getStreakEmoji(habit.currentStreak);
    final streakColor = _getStreakColor(habit.currentStreak);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 14),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: isCompletedToday
              ? BorderSide(color: Colors.green.shade300, width: 1.5)
              : BorderSide(color: Colors.grey.shade200, width: 1.2),
        ),
        child: InkWell(
          onTap: () => _showDetailPopup(context),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: streakColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(streakEmoji,
                          style: const TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(habit.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          if (habit.description.isNotEmpty)
                            Text(habit.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                        label: '🔥 Current Streak ${habit.currentStreak} Days',
                        icon: Icons.local_fire_department,
                        color: streakColor),
                    _buildInfoChip(
                        label: '🏆 Best ${habit.bestStreak} Days',
                        icon: Icons.emoji_events_outlined,
                        color: Colors.amber),
                    _buildInfoChip(
                        label:
                            'Last Completed ${habit.getLastCompletedLabel(referenceDate: DateTime.now())}',
                        icon: Icons.calendar_today_outlined,
                        color: Colors.blue),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isCompletedToday || _isCompleting
                            ? null
                            : () async {
                                setState(() => _isCompleting = true);
                                final messenger = ScaffoldMessenger.of(context);
                                final updated = await ref
                                    .read(habitsProvider.notifier)
                                    .completeToday(habit.id);
                                if (!mounted) return;
                                setState(() => _isCompleting = false);
                                if (updated != null) {
                                  final milestoneMessage = _getMilestoneMessage(
                                      updated.currentStreak);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(milestoneMessage),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                        icon: Icon(isCompletedToday
                            ? Icons.check_circle
                            : Icons.check),
                        label: Text(isCompletedToday
                            ? '✓ Completed Today'
                            : '✓ Complete Today'),
                        style: FilledButton.styleFrom(
                          backgroundColor: isCompletedToday
                              ? Colors.grey.shade400
                              : Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => _showEditHabitDialog(context, habit),
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit',
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => _showDeleteConfirmation(context, habit),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => HabitDetailPopup(habit: widget.habit),
    );
  }

  Widget _buildInfoChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getStreakEmoji(int streak) {
    if (streak >= 30) return '🔥';
    if (streak >= 20) return '⚡';
    if (streak >= 10) return '🌟';
    if (streak >= 5) return '💪';
    if (streak >= 3) return '📈';
    if (streak >= 1) return '✅';
    return '🔄';
  }

  Color _getStreakColor(int streak) {
    if (streak >= 30) return Colors.red;
    if (streak >= 20) return Colors.orange;
    if (streak >= 10) return Colors.amber;
    if (streak >= 5) return Colors.green;
    if (streak >= 3) return Colors.blue;
    if (streak >= 1) return Colors.purple;
    return Colors.grey;
  }

  String _getMilestoneMessage(int streak) {
    if (streak == 7) {
      return '🎉 7-day streak unlocked!';
    }
    if (streak == 30) {
      return '🔥 30-day streak unlocked!';
    }
    if (streak == 50) {
      return '🏆 50-day streak unlocked!';
    }
    if (streak == 100) {
      return '💎 100-day streak unlocked!';
    }
    if (streak == 365) {
      return '🌟 365-day streak unlocked!';
    }
    return '🔥 +1 day! Keep going!';
  }

  Future<void> _showEditHabitDialog(BuildContext context, Habit habit) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController(text: habit.name);
    final descriptionController =
        TextEditingController(text: habit.description);

    final result = await showDialog<Habit>(
      context: context,
      builder: (context) => AlertDialog(
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
      BuildContext context, Habit habit) async {
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
