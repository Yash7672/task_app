import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/glass_components.dart';
import '../../../models/task_model.dart';
import '../../../providers/focus_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/glass_depth.dart';
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
            _FocusCard(),
            _TodayTasksSection(),
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
          _glassWrap(
            context,
            child: Container(
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
      child: GlassSurface(
        borderRadius: 16,
        depth: GlassDepth.level1,
        blur: 0,
        padding: const EdgeInsets.all(16),
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



// ── Focus card (watches focusProvider only) ──────────────────────────

class _FocusCard extends ConsumerWidget {
  const _FocusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusState = ref.watch(focusProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: GlassSurface(
        borderRadius: 16,
        depth: GlassDepth.level2,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isGlassTheme(context)
                    ? GlassColors.accentSubtle
                    : Colors.deepPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.timer_outlined,
                  color: isGlassTheme(context)
                      ? GlassColors.accent
                      : Colors.deepPurple),
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



// ── Shared helpers ──────────────────────────────────────────────────

/// Wrap non-glossy Material containers in frosted glass when the Glass theme
/// is active. In every other theme the child passes through unchanged, so
/// Dark / Light / AMOLED keep their exact existing look. Using this helper on
/// the dashboard's decorative containers keeps the ≤3 BackdropFilter budget
/// per screen (only depth levels 1-2 are used here, all non-interactive).
Widget _glassWrap(BuildContext context, {required Widget child}) {
  if (!isGlassTheme(context)) return child;
  return GlassSurface(
    borderRadius: 16,
    depth: GlassDepth.level1,
    padding: EdgeInsets.zero,
    child: child,
  );
}

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
