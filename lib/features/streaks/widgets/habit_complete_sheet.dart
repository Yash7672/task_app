import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/habit_log_item.dart';
import '../../../models/habit_model.dart';
import '../../../providers/task_provider.dart';

Future<void> showHabitCompleteSheet(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _HabitCompleteSheet(habit: habit),
  );
}

class _HabitCompleteSheet extends ConsumerStatefulWidget {
  final Habit habit;

  const _HabitCompleteSheet({required this.habit});

  @override
  ConsumerState<_HabitCompleteSheet> createState() =>
      _HabitCompleteSheetState();
}

class _HabitCompleteSheetState extends ConsumerState<_HabitCompleteSheet> {
  final _controller = TextEditingController();
  bool _isCompleting = false;

  String get _todayLogId => habitLogIdFor(widget.habit.id, DateTime.now());

  /// After any checklist change, refresh today's completion snapshot so the
  /// streak history shows the latest entries for today (past days untouched).
  Future<void> _syncSnapshot() async {
    await ref
        .read(habitsProvider.notifier)
        .syncTodaySnapshot(widget.habit.id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    setState(() => _isCompleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final updated =
        await ref.read(habitsProvider.notifier).completeToday(widget.habit.id);
    if (!mounted) return;
    setState(() => _isCompleting = false);
    Navigator.pop(context);
    if (updated != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_milestoneMessage(updated.currentStreak)),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _editItem(HabitLogItem item) async {
    final controller = TextEditingController(text: item.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit entry'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'What did you do?'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.trim().isNotEmpty) {
      await ref
          .read(habitLogItemsProvider(_todayLogId).notifier)
          .updateItemText(item, result);
      await _syncSnapshot();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(habitLogItemsProvider(_todayLogId));
    final notifier = ref.read(habitLogItemsProvider(_todayLogId).notifier);
    final isCompletedToday = widget.habit.isCompletedToday;
    final theme = Theme.of(context);

    void addItemAndSync(String value) {
      notifier.addItem(value).then((_) => _syncSnapshot());
    }

    void deleteItemAndSync(HabitLogItem item) {
      notifier.deleteItem(item).then((_) => _syncSnapshot());
    }

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.habit.name,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        isCompletedToday
                            ? '✓ Completed today — add or edit entries anytime'
                            : 'What did you do today? (optional)',
                        style: TextStyle(
                            color: isCompletedToday
                                ? Colors.green
                                : Colors.grey[600],
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'e.g. Legs day, Chest, 5km run',
                      prefixIcon: const Icon(Icons.add_task_rounded),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onSubmitted: (value) {
                      addItemAndSync(value);
                      _controller.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    addItemAndSync(_controller.text);
                    _controller.clear();
                  },
                  icon: const Icon(Icons.add),
                  tooltip: 'Add to today\'s log',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'No entries yet. Add what you completed — or just hit Complete.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              )
            else
              ...items.map(
                (item) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.check_circle_outline,
                        color: Colors.green),
                    title: Text(item.text),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Edit',
                          onPressed: () => _editItem(item),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 20, color: Colors.red.shade400),
                          tooltip: 'Delete',
                          onPressed: () => deleteItemAndSync(item),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed:
                    isCompletedToday || _isCompleting ? null : () => _complete(),
                icon: Icon(isCompletedToday
                    ? Icons.check_circle
                    : Icons.check_circle_outline),
                label: Text(isCompletedToday
                    ? '✓ Completed Today'
                    : '✓ Complete Today'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isCompletedToday ? Colors.grey.shade400 : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _milestoneMessage(int streak) {
    if (streak == 7) return '🎉 7-day streak unlocked!';
    if (streak == 30) return '🔥 30-day streak unlocked!';
    if (streak == 50) return '🏆 50-day streak unlocked!';
    if (streak == 100) return '💎 100-day streak unlocked!';
    if (streak == 365) return '🌟 365-day streak unlocked!';
    return '🔥 +1 day! Keep going!';
  }
}
