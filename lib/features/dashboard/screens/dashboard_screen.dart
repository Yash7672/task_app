import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/task_model.dart';
import '../../../providers/birthday_provider.dart';
import '../../../providers/focus_provider.dart';
import '../../../providers/task_provider.dart';
import '../../focus/screens/focus_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../tasks/screens/add_edit_task_screen.dart';
import '../../tasks/screens/task_list_screen.dart';
import '../widgets/task_list_item.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GreetingHeader(),
            _StreakSummaryCard(),
            _StatsRow(),
            _FocusCard(),
            _NeedsAttentionSection(),
            _BirthdaysSection(),
            _TodayTasksSection(),
            _UpcomingTasksSection(),
            SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'dashboard_fab',
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
}

// ── Greeting + daily progress (watches todayTasks only) ──────────────

class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayTasks = ref.watch(todayTasksProvider);
    final theme = Theme.of(context);

    final completedCount = todayTasks.where((t) => t.isCompleted).length;
    final progress = todayTasks.isEmpty
        ? 0
        : (completedCount / todayTasks.length * 100).round();

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning 👋'
        : hour < 18
            ? 'Good Afternoon 👋'
            : 'Good Evening 👋';

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
                    Text('$completedCount of ${todayTasks.length} done',
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
}

// ── Streak summary (watches streakSummary only) ──────────────────────

class _StreakSummaryCard extends ConsumerWidget {
  const _StreakSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakSummary = ref.watch(streakSummaryProvider);
    final theme = Theme.of(context);

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
}

// ── Stats row (watches todayTasks + overdueTasks + favorites) ────────

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayTasks = ref.watch(todayTasksProvider);
    final overdueTasks = ref.watch(overdueTasksProvider);
    final favorites = ref.watch(favoritesProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
              child: _statCard(theme, 'Today', '${todayTasks.length}', Icons.today)),
          const SizedBox(width: 8),
          Expanded(
              child: _statCard(theme, 'Overdue', '${overdueTasks.length}',
                  Icons.warning_amber_rounded)),
          const SizedBox(width: 8),
          Expanded(
              child: _statCard(
                  theme, 'Favorites', '${favorites.length}', Icons.star)),
        ],
      ),
    );
  }

  Widget _statCard(ThemeData theme, String title, String value, IconData icon) {
    return Container(
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
}

// ── Needs attention (watches overdueTasks + todayTasks) ──────────────

class _NeedsAttentionSection extends ConsumerWidget {
  const _NeedsAttentionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdueTasks = ref.watch(overdueTasksProvider);
    final todayTasks = ref.watch(todayTasksProvider);

    final now = DateTime.now();
    final needsAttention = [
      ...overdueTasks,
      ...todayTasks.where((t) =>
          !t.isCompleted &&
          t.startTime != null &&
          t.startTime!.isAfter(now) &&
          t.startTime!.difference(now).inHours <= 3),
    ];

    if (needsAttention.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, '⚠️ Needs Attention', needsAttention.length),
        ...needsAttention.take(3).map((task) => TaskListItem(task: task)),
      ],
    );
  }
}

// ── Focus card (watches focusProvider only) ──────────────────────────

class _FocusCard extends ConsumerWidget {
  const _FocusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusState = ref.watch(focusProvider);
    final theme = Theme.of(context);

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
                      focusState.minutesToday > 0
                          ? '${focusState.minutesToday}m focused today'
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
}

// ── Birthdays (watches birthdayProvider only) ────────────────────────

class _BirthdaysSection extends ConsumerWidget {
  const _BirthdaysSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthdays = ref.watch(birthdayProvider);

    final upcoming = birthdays.maybeWhen(
      data: (list) => list.where((b) => b.daysUntilNext() <= 30).toList(),
      orElse: () => [],
    );

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, '🎂 Birthdays', upcoming.length),
        ...upcoming.take(2).map((b) => ListTile(
              leading: const Icon(Icons.cake_rounded, color: Colors.pink),
              title: Text(b.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(b.daysUntilNext() == 0
                  ? 'Today! 🎉'
                  : b.daysUntilNext() == 1
                      ? 'Tomorrow'
                      : 'In ${b.daysUntilNext()} days'),
            )),
      ],
    );
  }
}

// ── Today tasks (watches todayTasks only) ───────────────────────────

class _TodayTasksSection extends ConsumerWidget {
  const _TodayTasksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayTasks = ref.watch(todayTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Today', todayTasks.length),
        _buildTaskList(todayTasks),
      ],
    );
  }
}

// ── Upcoming tasks (watches upcomingTasks only) ─────────────────────

class _UpcomingTasksSection extends ConsumerWidget {
  const _UpcomingTasksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingTasks = ref.watch(upcomingTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Upcoming', upcomingTasks.length),
        _buildTaskList(upcomingTasks.take(5).toList()),
      ],
    );
  }
}

// ── Shared helpers ──────────────────────────────────────────────────

Widget _buildSectionHeader(BuildContext context, String title, int count) {
  final theme = Theme.of(context);
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
  return ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: tasks.length,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (context, index) => TaskListItem(task: tasks[index]),
  );
}
