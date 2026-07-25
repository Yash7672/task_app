import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/habit_model.dart';
import '../../../providers/task_provider.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsState = ref.watch(habitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Habits')),
      body: habitsState.when(
        data: (habits) {
          if (habits.isEmpty) {
            return const Center(
                child: Text('No habits yet. Add one to start your streak.'));
          }
          return ListView.builder(
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habit = habits[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(habit.name),
                  subtitle: Text(
                      '${habit.frequency} • streak ${habit.currentStreak}'),
                  trailing: FilledButton(
                    onPressed: () =>
                        ref.read(habitsProvider.notifier).logToday(habit.id),
                    child: const Text('Done'),
                  ),
                ),
              );
            },
          );
        },
        error: (error, _) => Center(child: Text('Error: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final nameController = TextEditingController();
          final result = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('New Habit'),
              content: TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Habit name')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, nameController.text.trim()),
                    child: const Text('Save')),
              ],
            ),
          );
          if (result != null && result.isNotEmpty) {
            ref.read(habitsProvider.notifier).addHabit(Habit(name: result));
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Habit'),
      ),
    );
  }
}
