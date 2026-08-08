import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/habit_model.dart';
import '../../../providers/task_provider.dart';
import '../widgets/habit_card.dart';
import '../../settings/screens/settings_screen.dart';

class StreaksScreen extends ConsumerStatefulWidget {
  const StreaksScreen({super.key});

  @override
  ConsumerState createState() => _StreaksScreenState();
}

class _StreaksScreenState extends ConsumerState<StreaksScreen> {
  @override
  Widget build(BuildContext context) {
    final habitsState = ref.watch(habitsProvider);
    final summary = ref.watch(streakSummaryProvider);
    final today = DateTime.now().toIso8601String();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔥 Streaks'),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        actions: [
          IconButton(
            icon: const Icon(Icons.stacked_bar_chart_outlined),
            onPressed: _showStatsDialog,
            tooltip: 'Statistics',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: habitsState.when(
        data: (habits) {
          if (habits.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_fire_department, size: 56),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No streaks yet',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stay consistent every day. Create your first streak.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () async {
                        final createdHabit = await _showHabitDialog(context);
                        if (createdHabit != null) {
                          await ref
                              .read(habitsProvider.notifier)
                              .addHabit(createdHabit);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Streak'),
                    ),
                  ],
                ),
              ),
            );
          }

          final sortedHabits = List<Habit>.from(habits);
          sortedHabits
              .sort((a, b) => b.currentStreak.compareTo(a.currentStreak));

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🔥 Active Streaks',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('${summary['activeStreaks']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                Text(
                                    '🏆 Longest ${summary['longestStreak']} Days',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(16)),
                            child: Text('${summary['completedToday']}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final habit = sortedHabits[index];
                      return HabitCard(habit: habit, today: today);
                    },
                    childCount: sortedHabits.length,
                  ),
                ),
              ),
            ],
          );
        },
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final _ = ref.refresh(habitsProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your streaks...'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final createdHabit = await _showHabitDialog(context);
          if (createdHabit != null) {
            await ref.read(habitsProvider.notifier).addHabit(createdHabit);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Streak'),
      ),
    );
  }

  Future<Habit?> _showHabitDialog(BuildContext context, {Habit? habit}) async {
    final nameController = TextEditingController(text: habit?.name ?? '');
    final descriptionController =
        TextEditingController(text: habit?.description ?? '');

    return showDialog<Habit>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(habit == null ? 'Add Streak' : 'Edit Streak'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Streak Name',
                prefixIcon: Icon(Icons.local_fire_department),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(
                  context,
                  Habit(
                    id: habit?.id,
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    currentStreak: habit?.currentStreak ?? 0,
                    bestStreak: habit?.bestStreak ?? 0,
                    lastCompletedDate: habit?.lastCompletedDate,
                    createdAt: habit?.createdAt,
                    updatedAt: habit?.updatedAt,
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showStatsDialog() async {
    final stats = await ref.read(overallStatsProvider.future);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.stacked_bar_chart, color: Colors.blue),
            SizedBox(width: 8),
            Text('Streak Statistics'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Total Streaks', stats['totalStreaks'] ?? 0,
                Icons.local_fire_department),
            _buildStatRow('Longest Streak', stats['longestStreak'] ?? 0,
                Icons.emoji_events),
            _buildStatRow(
                'Average Streak',
                (stats['averageStreak'] ?? 0).toStringAsFixed(1),
                Icons.show_chart),
            _buildStatRow('Today\'s Completed', stats['completedToday'] ?? 0,
                Icons.check_circle),
            _buildStatRow('Best Streak Ever', stats['bestStreakEver'] ?? 0,
                Icons.emoji_events_outlined),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
