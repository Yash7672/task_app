import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/task_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref
        .watch(allTasksProvider)
        .where((task) => !task.isArchived)
        .toList();
    final completed = tasks.where((task) => task.isCompleted).length;
    final pending =
        tasks.where((task) => !task.isCompleted && !task.isDeleted).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Productivity Overview',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _statCard(context, 'Completed', '$completed'),
            _statCard(context, 'Pending', '$pending'),
            _statCard(context, 'Total', '${tasks.length}'),
          ],
        ),
      ),
    );
  }

  Widget _statCard(BuildContext context, String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(value, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
