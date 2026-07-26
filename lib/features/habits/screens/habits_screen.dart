import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/habit_model.dart';
import '../../../providers/task_provider.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  @override
  Widget build(BuildContext context) {
    final habitsState = ref.watch(habitsProvider);
    final today = DateTime.now().toIso8601String().split('T').first;

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
              final dailyLogs = ref.watch(habitLogsProvider(habit.id));

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(habit.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  final updatedHabit = await _showHabitDialog(
                                      context,
                                      habit: habit);
                                  if (updatedHabit != null) {
                                    await ref
                                        .read(habitsProvider.notifier)
                                        .updateHabit(updatedHabit);
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await ref
                                      .read(habitsProvider.notifier)
                                      .deleteHabit(habit.id);
                                },
                              ),
                              FilledButton(
                                onPressed: () async {
                                  await ref
                                      .read(habitsProvider.notifier)
                                      .logToday(habit.id);
                                  ref.refresh(habitLogsProvider(habit.id));
                                },
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (habit.description.isNotEmpty) Text(habit.description),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('Freq: ${habit.frequency}')),
                          Chip(label: Text('Streak: ${habit.currentStreak}')),
                          Chip(label: Text('Best: ${habit.bestStreak}')),
                          dailyLogs.when(
                            data: (logs) {
                              final todayCount = logs
                                  .where((log) => log['date'] == today)
                                  .length;
                              final totalCount = logs.length;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(label: Text('Today: $todayCount')),
                                  const SizedBox(width: 6),
                                  Chip(label: Text('Total: $totalCount')),
                                ],
                              );
                            },
                            loading: () =>
                                const Chip(label: Text('Loading...')),
                            error: (_, __) => const Chip(label: Text('Error')),
                          ),
                        ],
                      ),
                    ],
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
          final createdHabit = await _showHabitDialog(context);
          if (createdHabit != null) {
            ref.read(habitsProvider.notifier).addHabit(createdHabit);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Habit'),
      ),
    );
  }

  Future<Habit?> _showHabitDialog(BuildContext context, {Habit? habit}) async {
    final nameController = TextEditingController(text: habit?.name ?? '');
    final descriptionController =
        TextEditingController(text: habit?.description ?? '');
    String selectedFrequency = habit?.frequency ?? 'Daily';

    final result = await showDialog<Habit>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(habit == null ? 'New Habit' : 'Edit Habit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Habit name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedFrequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: const [
                DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
              ],
              onChanged: (value) {
                if (value != null) {
                  selectedFrequency = value;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(
                    context,
                    Habit(
                      id: habit?.id,
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim(),
                      frequency: selectedFrequency,
                      currentStreak: habit?.currentStreak ?? 0,
                      bestStreak: habit?.bestStreak ?? 0,
                      createdAt: habit?.createdAt,
                    ));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    return result;
  }
}
