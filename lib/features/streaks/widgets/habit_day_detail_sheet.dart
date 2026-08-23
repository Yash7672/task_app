import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/habit_completion_item.dart';
import '../../../models/habit_model.dart';
import '../../../providers/database_provider.dart';

/// Bottom sheet shown when tapping a 🔥 (completed) date on the streak
/// history calendar. Displays the checklist snapshotted when the habit was
/// completed on that specific day. Users can add, edit, and delete items
/// for that specific date without affecting other dates.
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

class _HabitDayDetailSheet extends ConsumerStatefulWidget {
  final Habit habit;
  final DateTime day;

  const _HabitDayDetailSheet({required this.habit, required this.day});

  @override
  ConsumerState<_HabitDayDetailSheet> createState() =>
      _HabitDayDetailSheetState();
}

class _HabitDayDetailSheetState extends ConsumerState<_HabitDayDetailSheet> {
  late List<HabitCompletionItem> _items;
  bool _isLoading = true;
  final _addController = TextEditingController();
  final _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _addController.dispose();
    _editController.dispose();
    super.dispose();
  }

  String get _dateKey {
    final m = widget.day.month.toString().padLeft(2, '0');
    final d = widget.day.day.toString().padLeft(2, '0');
    return '${widget.day.year}-$m-$d';
  }

  Future<void> _loadItems() async {
    final dbHelper = ref.read(databaseProvider);
    final items = await dbHelper.getCompletionChecklist(
      widget.habit.id,
      _dateKey,
    );
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _addItem() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;

    final item = HabitCompletionItem(
      habitId: widget.habit.id,
      completionDate: _dateKey,
      text: text,
      completed: true,
      position: _items.length,
    );

    final dbHelper = ref.read(databaseProvider);
    await dbHelper.addCompletionItem(item);
    _addController.clear();
    await _loadItems();
  }

  Future<void> _editItem(HabitCompletionItem item) async {
    _editController.text = item.text;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit item'),
        content: TextField(
          controller: _editController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Item text'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, _editController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty && result.trim() != item.text) {
      final dbHelper = ref.read(databaseProvider);
      await dbHelper.updateCompletionItem(
        item.copyWith(text: result.trim()),
      );
      await _loadItems();
    }
  }

  Future<void> _deleteItem(HabitCompletionItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove "${item.text}" from this day?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final dbHelper = ref.read(databaseProvider);
      await dbHelper.deleteCompletionItem(item.id);
      await _loadItems();
    }
  }

  Future<void> _toggleItem(HabitCompletionItem item) async {
    final dbHelper = ref.read(databaseProvider);
    await dbHelper.updateCompletionItem(
      item.copyWith(completed: !item.completed),
    );
    await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
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
                          DateFormat('d MMMM yyyy').format(widget.day),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.habit.name,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No checklist recorded for this day.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  )
                else
                  ...(_items.map((item) => _CompletionTile(
                        item: item,
                        onToggle: () => _toggleItem(item),
                        onEdit: () => _editItem(item),
                        onDelete: () => _deleteItem(item),
                      ))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Add checklist item…',
                          prefixIcon: const Icon(Icons.add_task_rounded),
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onSubmitted: (_) => _addItem(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      tooltip: 'Add item',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionTile extends StatelessWidget {
  final HabitCompletionItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CompletionTile({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = item.completed ? Colors.green : Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Icon(
              item.completed
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              size: 22,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.text,
              style: TextStyle(
                fontSize: 15,
                decoration:
                    item.completed ? null : TextDecoration.lineThrough,
                color: item.completed
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.grey[600],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit',
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: Colors.red.shade400),
            tooltip: 'Delete',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
