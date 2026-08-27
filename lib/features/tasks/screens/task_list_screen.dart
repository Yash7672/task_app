import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/task_model.dart';
import '../../../providers/task_provider.dart';
import '../../dashboard/widgets/task_list_item.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  String _queryLower = '';
  String _filter = 'All';
  bool _showArchived = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(allTasksProvider);
    final showArchived = _showArchived || _filter == 'Archived';
    final archivedTasks = showArchived
        ? ref.watch(archivedTasksProvider).valueOrNull ?? []
        : const <Task>[];
    final allVisibleTasks = [...tasks, ...archivedTasks];
    final filteredTasks = allVisibleTasks.where((task) {
      final matchesQuery = _queryLower.isEmpty ||
          task.title.toLowerCase().contains(_queryLower) ||
          task.category.toLowerCase().contains(_queryLower) ||
          task.notes.toLowerCase().contains(_queryLower);

      final matchesFilter = switch (_filter) {
        'Completed' => task.isCompleted,
        'Pending' => !task.isCompleted,
        'Favorites' => task.isFavorite,
        'Pinned' => task.isPinned,
        'Archived' => task.isArchived,
        _ => true,
      };

      return matchesQuery && matchesFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search tasks',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  setState(() {
                    _queryLower = value.toLowerCase();
                  });
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'Filter', border: OutlineInputBorder()),
              child: DropdownButton<String>(
                value: _filter,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'Favorites', child: Text('Favorites')),
                  DropdownMenuItem(value: 'Pinned', child: Text('Pinned')),
                  DropdownMenuItem(value: 'Archived', child: Text('Archived')),
                ],
                onChanged: (value) => setState(() => _filter = value ?? 'All'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show archived tasks'),
              value: _showArchived,
              onChanged: (value) => setState(() => _showArchived = value),
            ),
          ),
          Expanded(
            child: filteredTasks.isEmpty
                ? const Center(child: Text('No tasks match your search.'))
                : ListView.builder(
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) =>
                        TaskListItem(task: filteredTasks[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
