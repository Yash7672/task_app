import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../features/tasks/screens/add_edit_task_screen.dart';
import '../../../models/task_model.dart';
import '../../../providers/task_provider.dart';
import '../../../utils/extensions.dart';

class TaskListItem extends ConsumerWidget {
  final Task task;

  const TaskListItem({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final priorityColor = AppColors.getPriorityColor(task.priority);
    final categoryColor = AppColors.getCategoryColor(task.category);

    return Dismissible(
      key: Key(task.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref.read(taskProvider.notifier).deleteTask(task.id);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Task moved to trash')));
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 96,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16)),
              ),
            ),
            Expanded(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    value: task.isCompleted,
                    shape: const CircleBorder(),
                    activeColor: theme.colorScheme.primary,
                    onChanged: (_) => ref
                        .read(taskProvider.notifier)
                        .toggleTaskCompletion(task),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted ? Colors.grey : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (task.isPinned)
                      const Icon(Icons.push_pin,
                          size: 16, color: Colors.orange),
                    if (task.isFavorite)
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          task.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: task.isCompleted
                                  ? Colors.grey
                                  : Colors.grey[600]),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            task.category,
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: categoryColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today,
                            size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(task.dueDate.toDisplayString(),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'favorite':
                        ref.read(taskProvider.notifier).toggleFavorite(task);
                        break;
                      case 'pin':
                        ref.read(taskProvider.notifier).togglePin(task);
                        break;
                      case 'archive':
                        ref.read(taskProvider.notifier).archiveTask(task.id);
                        break;
                      case 'restore':
                        ref
                            .read(taskProvider.notifier)
                            .restoreTaskFromModel(task);
                        break;
                      case 'delete':
                        ref
                            .read(taskProvider.notifier)
                            .deleteTaskPermanently(task.id);
                        break;
                      default:
                        break;
                    }
                  },
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<String>>[];
                    items.add(PopupMenuItem(
                        value: 'favorite',
                        child: Text(
                            task.isFavorite ? 'Remove favorite' : 'Favorite')));
                    items.add(PopupMenuItem(
                        value: 'pin',
                        child: Text(task.isPinned ? 'Unpin' : 'Pin')));
                    if (task.isArchived || task.isDeleted) {
                      items.add(const PopupMenuItem(
                          value: 'restore', child: Text('Restore')));
                      items.add(const PopupMenuItem(
                          value: 'delete', child: Text('Delete permanently')));
                    } else {
                      items.add(const PopupMenuItem(
                          value: 'archive', child: Text('Archive')));
                    }
                    return items;
                  },
                ),
                onTap: () {
                  _showTaskDetails(context, task, ref);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTaskDetails(
      BuildContext context, Task task, WidgetRef ref) async {
    final theme = Theme.of(context);
    final priorityColor = AppColors.getPriorityColor(task.priority);
    final categoryColor = AppColors.getCategoryColor(task.category);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(task.title,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: priorityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (task.description.isNotEmpty)
                    Text(task.description,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: Colors.grey[700])),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Chip(
                        label: Text(task.category),
                        backgroundColor: categoryColor.withValues(alpha: 0.15),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(task.dueDate.toDisplayString()),
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Checklist',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (task.checklist.isEmpty)
                    Text('No checklist items.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey[600]))
                  else
                    Column(
                      children: task.checklist
                          .map((item) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.check_circle_outline),
                                title: Text(item),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddEditTaskScreen(taskToEdit: task),
                            ),
                          );
                        },
                        child: const Text('Edit'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
