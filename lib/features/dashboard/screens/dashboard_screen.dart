import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/task_model.dart';
import '../../../providers/birthday_provider.dart';
import '../../../providers/focus_provider.dart';
import '../../../providers/task_provider.dart';
import '../../focus/screens/focus_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../tasks/screens/add_edit_task_screen.dart';
import '../../tasks/screens/task_list_screen.dart';
import '../widgets/task_list_item.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayTasks = ref.watch(todayTasksProvider);
    final upcomingTasks = ref.watch(upcomingTasksProvider);
    final overdueTasks = ref.watch(overdueTasksProvider);
    final favorites = ref.watch(favoritesProvider);
    final streakSummary = ref.watch(streakSummaryProvider);
    final birthdays = ref.watch(birthdayProvider);
    final focusState = ref.watch(focusProvider);
    final theme = Theme.of(context);

    final completedCount = todayTasks.where((task) => task.isCompleted).length;
    final progress = todayTasks.isEmpty
        ? 0
        : (completedCount / todayTasks.length * 100).round();

    final needsAttention = [
      ...overdueTasks,
      ...todayTasks.where((t) =>
          !t.isCompleted &&
          t.startTime != null &&
          t.startTime!.isAfter(DateTime.now()) &&
          t.startTime!.difference(DateTime.now()).inHours <= 3),
    ];

    final upcomingBirthdays = birthdays.maybeWhen(
      data: (list) => list.where((b) => b.daysUntilNext() <= 30).toList(),
      orElse: () => [],
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Text('PYLO', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TaskListScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreetingHeader(theme, progress, completedCount, todayTasks.length),
            _buildStreakSummaryCard(theme, streakSummary),
            _buildStatsRow(theme, todayTasks.length, overdueTasks.length,
                favorites.length),
            if (needsAttention.isNotEmpty) ...[
              _buildSectionHeader(theme, '⚠️ Needs Attention',
                  needsAttention.length),
              _buildTaskList(needsAttention.take(3).toList()),
            ],
            _buildFocusCard(context, ref, theme, focusState.minutesToday),
            if (upcomingBirthdays.isNotEmpty) ...[
              _buildSectionHeader(
                  theme, '🎂 Birthdays', upcomingBirthdays.length),
              ...upcomingBirthdays.take(2).map((b) => ListTile(
                    leading:
                        const Icon(Icons.cake_rounded, color: Colors.pink),
                    title: Text(b.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(b.daysUntilNext() == 0
                        ? 'Today! 🎉'
                        : b.daysUntilNext() == 1
                            ? 'Tomorrow'
                            : 'In ${b.daysUntilNext()} days'),
                  )),
            ],
            _buildSectionHeader(theme, 'Today', todayTasks.length),
            _buildTaskList(todayTasks),
            _buildSectionHeader(theme, 'Upcoming', upcomingTasks.length),
            _buildTaskList(upcomingTasks.take(5).toList()),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AddEditTaskScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGreetingHeader(
      ThemeData theme, int progress, int completed, int total) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning 👋';
    } else if (hour < 18) {
      greeting = 'Good Afternoon 👋';
    } else {
      greeting = 'Good Evening 👋';
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Stay focused, stay offline, and keep your day on track.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Daily progress',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('$completed of $total done',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 10,
                    backgroundColor:
                        theme.colorScheme.surface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text('$progress% complete',
                    style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakSummaryCard(
      ThemeData theme, Map<String, dynamic> streakSummary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Streak momentum',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _chip(theme, 'Active ${streakSummary['activeStreaks'] ?? 0}'),
                _chip(
                    theme, 'Best ${streakSummary['longestStreak'] ?? 0} days'),
                _chip(theme,
                    'Completed today ${streakSummary['completedToday'] ?? 0}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusCard(BuildContext context, WidgetRef ref, ThemeData theme,
      int minutesToday) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.timer_outlined,
                    color: Colors.deepPurple),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🎯 Focus',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(
                      minutesToday > 0
                          ? '${minutesToday}m focused today'
                          : 'Start a deep work session',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FocusScreen())),
                child: const Text('Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.labelMedium),
    );
  }

  Widget _buildStatsRow(
      ThemeData theme, int todayCount, int overdueCount, int favoriteCount) {
    final cards = [
      _statCard(theme, 'Today', '$todayCount', Icons.today),
      _statCard(theme, 'Overdue', '$overdueCount', Icons.warning_amber_rounded),
      _statCard(theme, 'Favorites', '$favoriteCount', Icons.star),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: cards.map((card) => Expanded(child: card)).toList(),
      ),
    );
  }

  Widget _statCard(ThemeData theme, String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(title, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(count.toString(),
                style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks) {
    if (tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
            child: Text('No tasks here.',
                style: TextStyle(color: Colors.grey[500]))),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: tasks.map((task) => TaskListItem(task: task)).toList(),
    );
  }
}
