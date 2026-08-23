import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/focus/focus_service.dart';

class FocusTimer extends StatefulWidget {
  final ActiveFocus session;
  final double size;

  const FocusTimer({super.key, required this.session, this.size = 240});

  @override
  State<FocusTimer> createState() => _FocusTimerState();
}

class _FocusTimerState extends State<FocusTimer> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final safe = d.isNegative ? Duration.zero : d;
    final minutes = safe.inMinutes;
    final seconds = safe.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = widget.session.remaining;
    final progress = widget.session.progress;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation<Color>(
                remaining.inMinutes < 5 && remaining.inSeconds > 0
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.primary,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _format(remaining),
                style: theme.textTheme.displayMedium
                    ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 2),
              ),
              const SizedBox(height: 4),
              Text(
                '🔥 FOCUS MODE',
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
