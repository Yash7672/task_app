import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('🔥 Streaks')),
      body: habitsState.when(
        data: (habits) {
          if (habits.isEmpty) {
            return const Center(
                child: Text('No streaks yet. Create your first streak.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habit = habits[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.local_fire_department,
                      color: Colors.orange),
                  title: Text(habit.name),
                  subtitle: Text(habit.description.isEmpty
                      ? 'No description'
                      : habit.description),
                  trailing: Text('${habit.currentStreak} days'),
                ),
              );
            },
          );
        },
        error: (error, _) => Center(child: Text('Error: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
