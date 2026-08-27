import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/focus_session_model.dart';
import '../../../providers/focus_provider.dart';
import '../widgets/focus_timer.dart';
import 'focus_pin_dialog.dart';

class FocusActiveScreen extends ConsumerStatefulWidget {
  const FocusActiveScreen({super.key});

  @override
  ConsumerState<FocusActiveScreen> createState() => _FocusActiveScreenState();
}

class _FocusActiveScreenState extends ConsumerState<FocusActiveScreen> {
  bool _navigatedBack = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _navigateBack() {
    if (_navigatedBack || !mounted) return;
    _navigatedBack = true;
    Navigator.of(context).pop();
  }

  Future<bool> _onWillPop() async {
    final focus = ref.read(focusProvider);
    if (focus.active == null) return true;

    final isStrict = focus.active?.mode == FocusMode.strict;
    if (isStrict) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Focus is active. Use End Focus to stop.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    return _showExitConfirmation();
  }

  Future<bool> _showExitConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Focus?'),
        content: const Text(
            'Your focus session is still running. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _endFocus() async {
    final focus = ref.read(focusProvider);
    final active = focus.active;
    if (active == null) return;

    final isStrict = active.mode == FocusMode.strict;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Focus?'),
        content:
            const Text('Are you sure you want to end this focus session early?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Focus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    if (isStrict) {
      final pinValid = await FocusPinDialog.show(context);
      if (pinValid != true || !mounted) return;
      await ref.read(focusProvider.notifier).stopSession();
    } else {
      await ref.read(focusProvider.notifier).stopSession();
    }

    _navigateBack();
  }

  @override
  Widget build(BuildContext context) {
    final focus = ref.watch(focusProvider);
    final active = focus.active;
    final theme = Theme.of(context);

    if (active == null && !_navigatedBack) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateBack();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (active == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isStrict = active.mode == FocusMode.strict;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isStrict ? Icons.lock_outline_rounded : Icons.psychology,
                    size: 48,
                    color: isStrict
                        ? theme.colorScheme.primary
                        : theme.colorScheme.tertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isStrict ? 'STRICT FOCUS' : 'FOCUS MODE',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isStrict
                          ? theme.colorScheme.primary
                          : theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FocusTimer(session: active),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      active.label,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stay focused.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _endFocus,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text(
                        'END FOCUS',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (isStrict) ...[
                    const SizedBox(height: 12),
                    Text(
                      'PIN required to end early',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
