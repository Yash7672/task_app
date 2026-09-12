import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/focus_channel.dart';
import '../../../core/utils/alarm_sound_service.dart';
import '../../../core/utils/notification_helper.dart';
import '../../../providers/preferences_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme/app_theme.dart';

/// Full-screen alarm UI shown while an alarm is ringing.
///
/// Rendered as a `fullscreenDialog` route pushed above everything by
/// main.dart whenever an AlarmInfo fires (warm start) or launches the app
/// (cold start). While mounted it keeps the screen on, prevents route
/// re-pushes, and offers Snooze + Slide-to-dismiss.
///
/// Theme-aware: reads the current [AppThemeMode] and renders with matching
/// colours. Glass mode gets a frosted depth-3 surface; Dark/AMOLED get
/// deep radial gradients; Light gets a white-on-accent gradient.
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key, required this.alarm});

  final AlarmInfo alarm;

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  final GlobalKey _thumbKey = GlobalKey();
  double _slideProgress = 0.0;

  /// Audio player that loops the configured alarm sound while ringing.
  AudioPlayer? _alarmPlayer;

  /// True once the user has acted on the alarm (snoozed or dismissed). Guards
  /// against double-pops (drag-to-dismiss racing the snooze tap) which would
  /// otherwise pop the router twice and crash with "!_debugLocked".
  bool _dismissed = false;

  String get _taskTitle => widget.alarm.taskTitle;

  @override
  void initState() {
    super.initState();
    NotificationHelper.isAlarmOpen = true;
    unawaited(FocusChannel.setKeepScreenOn(true));
    _setImmersive();
    // No 1-second setState here — the clock ticks in its own repaint-isolated
    // child (_ClockDisplay), so the rest of the screen never repaints per sec.
    _slideController = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() {}));
    _startAlarmSound();
    // The alarm notification is only a (silent) trigger — cancel it now so it
    // cannot linger in the shade or re-open a stale alarm later.
    unawaited(
        NotificationHelper.cancel(NotificationId.taskAlarm(widget.alarm.taskId)));
  }

  @override
  void dispose() {
    NotificationHelper.isAlarmOpen = false;
    unawaited(FocusChannel.setKeepScreenOn(false));
    _slideController.dispose();
    _stopAlarmSound();
    super.dispose();
  }

  void _setImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  /// Starts playing the configured alarm sound on loop.  Prefers the per-task
  /// sound baked into the alarm payload (Task A can ring a different song than
  /// Task B); falls back to the global Settings sound, then to the built-in
  /// classic if the custom file is missing.
  Future<void> _startAlarmSound() async {
    if (kIsWeb) return;
    try {
      final prefs = ref.read(settingsPreferencesProvider);
      final soundId = widget.alarm.soundId ?? prefs.alarmSoundId;
      final customUri = widget.alarm.customUri ?? prefs.customAlarmUri;

      final player = await AlarmSoundService.startAlarmPlayback(
        soundId: soundId,
        customUri: customUri,
      );
      if (player == null) return;
      if (!mounted) {
        await player.stop();
        await player.dispose();
        return;
      }
      _alarmPlayer = player;
    } catch (e) {
      debugPrint('AlarmScreen._startAlarmSound failed: $e');
    }
  }

  Future<void> _stopAlarmSound() async {
    try {
      await _alarmPlayer?.stop();
      await _alarmPlayer?.dispose();
    } catch (_) {}
    _alarmPlayer = null;
  }

  Future<void> _snooze() async {
    if (_dismissed) return;
    _dismissed = true;
    final snoozeMinutes =
        ref.read(settingsPreferencesProvider).alarmSnoozeMinutes.clamp(1, 60);
    try {
      await NotificationHelper.snoozeTaskAlarm(
        taskId: widget.alarm.taskId,
        taskTitle: _taskTitle,
        duration: Duration(minutes: snoozeMinutes),
      );
    } catch (e) {
      debugPrint('Snooze failed: $e');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Snoozed for $snoozeMinutes min'),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    await _stopAlarmSound();
    try {
      await NotificationHelper.cancel(
          NotificationId.taskAlarm(widget.alarm.taskId));
    } catch (e) {
      debugPrint('Dismiss cancel failed: $e');
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _slideProgress += details.delta.dx / 280;
      _slideProgress = _slideProgress.clamp(0.0, 1.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_slideProgress >= 0.6) {
      _dismiss();
      return;
    }
    _animateProgressTo(0);
  }

  Future<void> _animateProgressTo(double target) async {
    await _slideController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
    if (mounted) setState(() => _slideProgress = target.clamp(0.0, 1.0));
  }

  // ---------------------------------------------------------------------------
  // Theme-aware colours
  // ---------------------------------------------------------------------------

  _AlarmColors _colorsForMode(AppThemeMode mode) {
    const white = Colors.white;
    switch (mode) {
      case AppThemeMode.glass:
        return const _AlarmColors(
          bgStart: Color(0xFF07070F),
          bgEnd: Color(0xFF0D0D18),
          surfaceBorder: GlassColors.border,
          surfaceBg: GlassColors.surfaceOpaqueDark,
          clockColor: white,
          dateColor: GlassColors.textSecondary,
          slideBarBg: GlassColors.level2,
          slideBarBorder: GlassColors.borderMedium,
          slideThumbStart: GlassColors.deepAccent,
          slideThumbEnd: GlassColors.deepAccentStrong,
          slideThumbGlow: GlassColors.deepAccentGlow,
          slideLabelColor: GlassColors.textMuted,
          snoozeBg: GlassColors.level2,
          snoozeBorder: GlassColors.borderMedium,
          snoozeFg: white,
          taskPillBg: GlassColors.surfaceOpaqueDark,
          taskPillBorder: GlassColors.borderMedium,
          taskPillIcon: GlassColors.deepAccent,
          taskPillText: white,
        );
      case AppThemeMode.amoled:
        return _AlarmColors(
          bgStart: const Color(0xFF1A1530),
          bgEnd: Colors.black,
          surfaceBorder: white.withValues(alpha: 0.12),
          surfaceBg: white.withValues(alpha: 0.06),
          clockColor: white,
          dateColor: white.withValues(alpha: 0.54),
          slideBarBg: white.withValues(alpha: 0.10),
          slideBarBorder: white.withValues(alpha: 0.18),
          slideThumbStart: const Color(0xFF6D5BD0),
          slideThumbEnd: const Color(0xFF4F42A8),
          slideThumbGlow:
              const Color(0xFFD0BCFF).withValues(alpha: 0.5),
          slideLabelColor: white.withValues(alpha: 0.70),
          snoozeBg: white.withValues(alpha: 0.10),
          snoozeBorder: white.withValues(alpha: 0.18),
          snoozeFg: white,
          taskPillBg: white.withValues(alpha: 0.10),
          taskPillBorder: white.withValues(alpha: 0.14),
          taskPillIcon: const Color(0xFFD0BCFF),
          taskPillText: white,
        );
      case AppThemeMode.dark:
        return _AlarmColors(
          bgStart: const Color(0xFF2A2540),
          bgEnd: const Color(0xFF0B0B10),
          surfaceBorder: white.withValues(alpha: 0.12),
          surfaceBg: white.withValues(alpha: 0.08),
          clockColor: white,
          dateColor: white.withValues(alpha: 0.54),
          slideBarBg: white.withValues(alpha: 0.10),
          slideBarBorder: white.withValues(alpha: 0.16),
          slideThumbStart: const Color(0xFF6D5BD0),
          slideThumbEnd: const Color(0xFF4F42A8),
          slideThumbGlow:
              const Color(0xFFD0BCFF).withValues(alpha: 0.5),
          slideLabelColor: white.withValues(alpha: 0.70),
          snoozeBg: white.withValues(alpha: 0.10),
          snoozeBorder: white.withValues(alpha: 0.18),
          snoozeFg: white,
          taskPillBg: white.withValues(alpha: 0.10),
          taskPillBorder: white.withValues(alpha: 0.14),
          taskPillIcon: const Color(0xFFD0BCFF),
          taskPillText: white,
        );
      case AppThemeMode.light:
        return _AlarmColors(
          bgStart: const Color(0xFFE8E0F5),
          bgEnd: const Color(0xFFF5F0FF),
          surfaceBorder: Colors.black12,
          surfaceBg: white.withValues(alpha: 0.85),
          clockColor: const Color(0xFF1A1035),
          dateColor: const Color(0xFF6B5B8A),
          slideBarBg: Colors.black.withValues(alpha: 0.06),
          slideBarBorder: Colors.black.withValues(alpha: 0.12),
          slideThumbStart: const Color(0xFF6D5BD0),
          slideThumbEnd: const Color(0xFF4F42A8),
          slideThumbGlow:
              const Color(0xFF6D5BD0).withValues(alpha: 0.3),
          slideLabelColor: const Color(0xFF6B5B8A),
          snoozeBg: Colors.black.withValues(alpha: 0.06),
          snoozeBorder: Colors.black.withValues(alpha: 0.12),
          snoozeFg: const Color(0xFF1A1035),
          taskPillBg: white.withValues(alpha: 0.8),
          taskPillBorder: Colors.black.withValues(alpha: 0.10),
          taskPillIcon: const Color(0xFF6D5BD0),
          taskPillText: const Color(0xFF1A1035),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider);
    final c = _colorsForMode(themeMode);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(0, -1),
            end: const Alignment(0, 1),
            colors: [c.bgStart, c.bgEnd],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // Task pill.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.taskPillBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: c.taskPillBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alarm, color: c.taskPillIcon, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _taskTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.taskPillText,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Big clock + date. Wrapped in a RepaintBoundary and owns its
                // own ticker, so the per-minute repaint is bounded to this
                // small subtree instead of the whole screen.
                RepaintBoundary(
                  child: _ClockDisplay(
                    clockColor: c.clockColor,
                    dateColor: c.dateColor,
                  ),
                ),
                const Spacer(flex: 3),

                // Slide-to-dismiss.
                _SlideDismissBar(
                  thumbKey: _thumbKey,
                  progress: _slideProgress,
                  colors: c,
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                ),
                const SizedBox(height: 24),

                // Snooze.
                _SnoozeButton(
                  snoozeMinutes:
                      ref.read(settingsPreferencesProvider).alarmSnoozeMinutes,
                  colors: c,
                  onPressed: _snooze,
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clock — repaint-isolated ticking clock (see RepaintBoundary in build above).
// ---------------------------------------------------------------------------

class _ClockDisplay extends StatefulWidget {
  const _ClockDisplay({
    required this.clockColor,
    required this.dateColor,
  });

  final Color clockColor;
  final Color dateColor;

  @override
  State<_ClockDisplay> createState() => _ClockDisplayState();
}

class _ClockDisplayState extends State<_ClockDisplay> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      // Only repaint when a shown value actually changes (minute rollover or
      // date change) — the display is minute-resolution, so rebuilding 60x/min
      // would be wasted work.
      if (now.minute != _now.minute || now.day != _now.day) {
        setState(() => _now = now);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String get _nowHourMinute => '${_two(_now.hour)}:${_two(_now.minute)}';

  String get _todayLabel {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${weekdays[_now.weekday - 1]}, '
        '${months[_now.month - 1]} ${_now.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _nowHourMinute,
          style: TextStyle(
            color: widget.clockColor,
            fontSize: 96,
            fontWeight: FontWeight.w200,
            height: 1.0,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _todayLabel,
          style: TextStyle(
            color: widget.dateColor,
            fontSize: 15,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Colour bundle so child widgets stay theme-aware without import duplication.
// ---------------------------------------------------------------------------

class _AlarmColors {
  const _AlarmColors({
    required this.bgStart,
    required this.bgEnd,
    required this.surfaceBorder,
    required this.surfaceBg,
    required this.clockColor,
    required this.dateColor,
    required this.slideBarBg,
    required this.slideBarBorder,
    required this.slideThumbStart,
    required this.slideThumbEnd,
    required this.slideThumbGlow,
    required this.slideLabelColor,
    required this.snoozeBg,
    required this.snoozeBorder,
    required this.snoozeFg,
    required this.taskPillBg,
    required this.taskPillBorder,
    required this.taskPillIcon,
    required this.taskPillText,
  });

  final Color bgStart, bgEnd;
  final Color surfaceBorder, surfaceBg;
  final Color clockColor, dateColor;
  final Color slideBarBg, slideBarBorder;
  final Color slideThumbStart, slideThumbEnd, slideThumbGlow, slideLabelColor;
  final Color snoozeBg, snoozeBorder, snoozeFg;
  final Color taskPillBg, taskPillBorder, taskPillIcon, taskPillText;
}

class _SlideDismissBar extends StatelessWidget {
  const _SlideDismissBar({
    required this.thumbKey,
    required this.progress,
    required this.colors,
    required this.onHorizontalDragUpdate,
    required this.onHorizontalDragEnd,
  });

  final GlobalKey thumbKey;
  final double progress;
  final _AlarmColors colors;
  final GestureDragUpdateCallback onHorizontalDragUpdate;
  final GestureDragEndCallback onHorizontalDragEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: onHorizontalDragUpdate,
      onHorizontalDragEnd: onHorizontalDragEnd,
      child: Container(
        height: 68,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.slideBarBg,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: colors.slideBarBorder),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Fill highlighting the covered fraction.
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            // Thumb.
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 6 + progress * 240,
                ),
                child: Container(
                  key: thumbKey,
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [colors.slideThumbStart, colors.slideThumbEnd],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.slideThumbGlow,
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.power_settings_new,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
            // Label sits behind the thumb — fades out once progress passes ~0.35.
            AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: progress < 0.35 ? 1.0 : 0.2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chevron_right,
                      color: colors.slideLabelColor, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    'Slide to dismiss',
                    style: TextStyle(
                      color: colors.slideLabelColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnoozeButton extends StatelessWidget {
  const _SnoozeButton({
    required this.snoozeMinutes,
    required this.colors,
    required this.onPressed,
  });

  final int snoozeMinutes;
  final _AlarmColors colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: colors.snoozeFg,
        backgroundColor: colors.snoozeBg,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: colors.snoozeBorder),
        ),
      ),
      icon: const Icon(Icons.bedtime, size: 20),
      label: Text(
        'Snooze $snoozeMinutes min',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}
