import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/focus_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../services/focus/focus_service.dart';
import '../widgets/focus_timer.dart';

class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  static const presetDurations = [25, 45, 60, 90];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(focusProvider);
    final theme = Theme.of(context);

    if (focus.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Focus Mode')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final active = focus.active;
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Focus Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => _showHistory(context, ref),
          ),
        ],
      ),
      body: active != null
          ? _ActiveSession(session: active)
          : _SetupView(theme: theme),
    );
  }

  void _showHistory(BuildContext context, WidgetRef ref) {
    final focus = ref.read(focusProvider);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final sessions = focus.history;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text('Focus History',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Today: ${_formatMinutes(focus.minutesToday)} focused',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 12),
              if (sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('No sessions yet.',
                        style: TextStyle(color: Colors.grey[600])),
                  ),
                )
              else
                ...sessions.take(20).map((s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        s.completed
                            ? Icons.check_circle
                            : Icons.stop_circle_outlined,
                        color:
                            s.completed ? Colors.green : Colors.grey,
                      ),
                      title: Text(s.label.isEmpty ? 'Focus session' : s.label),
                      subtitle: Text(
                          '${_formatMinutes(s.actualMinutes)} • ${s.startTime.day}/${s.startTime.month} '
                          '${s.startTime.hour.toString().padLeft(2, '0')}:${s.startTime.minute.toString().padLeft(2, '0')}'),
                    )),
            ],
          ),
        );
      },
    );
  }

  static String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _SetupView extends ConsumerStatefulWidget {
  final ThemeData theme;

  const _SetupView({required this.theme});

  @override
  ConsumerState<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends ConsumerState<_SetupView> {
  int _selectedMinutes = 25;
  String? _selectedTaskId;
  late TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayTasks = ref.watch(todayTasksProvider);
    final pendingTasks =
        todayTasks.where((t) => !t.isCompleted).toList();

    // If the selected task disappeared (completed/archived elsewhere), clear
    // the selection AND the prefilled label in a post-frame callback so the
    // UI can never show a task that is about to be submitted as null.
    final selectedStillExists =
        pendingTasks.any((t) => t.id == _selectedTaskId);
    if (!selectedStillExists && _selectedTaskId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedTaskId = null;
          _labelController.clear();
        });
      });
    }
    final selectedTask = pendingTasks
        .where((t) => t.id == _selectedTaskId)
        .firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Duration',
                      style: widget.theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: FocusScreen.presetDurations
                        .map((m) => ChoiceChip(
                              label: Text('$m min'),
                              selected: _selectedMinutes == m,
                              onSelected: (_) =>
                                  setState(() => _selectedMinutes = m),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _selectedMinutes.toDouble(),
                          min: 5,
                          max: 120,
                          divisions: 23,
                          label: '$_selectedMinutes min',
                          onChanged: (value) =>
                              setState(() => _selectedMinutes = value.round()),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text('$_selectedMinutes min',
                            textAlign: TextAlign.end,
                            style: widget.theme.textTheme.titleSmall),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What are you focusing on?',
                      style: widget.theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedTaskId),
                    initialValue: _selectedTaskId,
                    decoration: const InputDecoration(
                        labelText: 'Pick a task (optional)',
                        border: OutlineInputBorder()),
                    items: pendingTasks
                        .map((t) =>
                            DropdownMenuItem(value: t.id, child: Text(t.title)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTaskId = value;
                        if (value != null) {
                          final task = pendingTasks
                              .where((t) => t.id == value)
                              .firstOrNull;
                          if (task != null) {
                            _labelController.text = task.title;
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _labelController,
                    decoration: const InputDecoration(
                        labelText: 'Or type a label', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _startFocus(selectedTask?.title),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: Colors.deepPurple,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: const Text('START FOCUS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Calls and notifications still arrive.\nPYLO just helps you stay on one thing.',
              textAlign: TextAlign.center,
              style: widget.theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startFocus(String? taskTitle) async {
    final label = taskTitle ??
        (_labelController.text.trim().isNotEmpty
            ? _labelController.text.trim()
            : 'Focus session');
    await ref.read(focusProvider.notifier).startFocus(
          label: label,
          taskId: _selectedTaskId,
          minutes: _selectedMinutes,
        );
  }
}

class _ActiveSession extends ConsumerWidget {
  final ActiveFocus session;

  const _ActiveSession({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            FocusTimer(session: session),
            const SizedBox(height: 32),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                session.label,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(focusProvider.notifier).stopSession(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('STOP'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(focusProvider.notifier).completeSession(),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('DONE'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
