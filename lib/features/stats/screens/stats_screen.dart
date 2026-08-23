import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/focus_provider.dart';
import '../../../providers/task_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(allTasksProvider);
    final streakStats = ref.watch(overallStatsProvider);
    final focusState = ref.watch(focusProvider);
    final theme = Theme.of(context);

    // Count consistently over non-archived tasks so "Completed" can never
    // exceed "Total Tasks".
    final active = tasks.where((task) => !task.isArchived).toList();
    final completed = active.where((task) => task.isCompleted).length;
    final pending = active.where((task) => !task.isCompleted).length;
    final total = active.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Productivity Overview',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _statCard(context, Icons.check_circle_outline, Colors.green,
              'Completed', '$completed'),
          _statCard(context, Icons.pending_outlined, Colors.orange,
              'Pending', '$pending'),
          _statCard(context, Icons.list_alt_rounded, Colors.blue,
              'Total Tasks', '$total'),
          const SizedBox(height: 24),
          Text('🔥 Streaks',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _statCard(context, Icons.local_fire_department, Colors.deepOrange,
              'Active Streaks', '${streakStats['totalStreaks']}'),
          _statCard(context, Icons.emoji_events_outlined, Colors.amber,
              'Best Streak Ever', '${streakStats['bestStreakEver']} days'),
          _statCard(context, Icons.show_chart, Colors.teal,
              'Average Streak', '${(streakStats['averageStreak'] ?? 0.0).toStringAsFixed(1)} days'),
          const SizedBox(height: 24),
          Text('🎯 Focus',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _statCard(context, Icons.timer_outlined, Colors.deepPurple,
              'Focus Today', _formatMinutes(focusState.minutesToday)),
          _statCard(context, Icons.history_rounded, Colors.indigo,
              'Sessions Logged', '${focusState.history.length}'),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Widget _statCard(BuildContext context, IconData icon, Color color,
      String title, String value) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title),
        trailing: Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
