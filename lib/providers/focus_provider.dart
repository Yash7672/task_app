import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/focus_session_model.dart';
import '../services/focus/focus_service.dart';
import '../services/home_widget_service.dart';
import '../services/security/pin_service.dart';
import '../core/services/focus_channel.dart';
import 'database_provider.dart';

final focusServiceProvider = Provider<FocusService>((ref) => FocusService());

class FocusState {
  static const _clearActive = Object();

  final ActiveFocus? active;
  final List<FocusSession> history;
  final int minutesToday;
  final bool isLoading;
  final bool isStrictMode;
  final bool isPaused;

  /// True when a strict session is active but Android Lock Task could not be
  /// entered (device/owner restrictions). Shown as a warning so the user is
  /// not misled into believing the phone is pinned.
  final bool lockTaskUnavailable;

  const FocusState({
    this.active,
    this.history = const [],
    this.minutesToday = 0,
    this.isLoading = true,
    this.isStrictMode = false,
    this.isPaused = false,
    this.lockTaskUnavailable = false,
  });

  /// Whether the currently active focus session is in strict mode.
  bool get isStrictActive =>
      active != null && active!.mode == FocusMode.strict;

  FocusState copyWithState({
    Object? active = _clearActive,
    List<FocusSession>? history,
    int? minutesToday,
    bool? isLoading,
    bool? isStrictMode,
    bool? isPaused,
    bool? lockTaskUnavailable,
  }) {
    return FocusState(
      active: active == _clearActive ? this.active : active as ActiveFocus?,
      history: history ?? this.history,
      minutesToday: minutesToday ?? this.minutesToday,
      isLoading: isLoading ?? this.isLoading,
      isStrictMode: isStrictMode ?? this.isStrictMode,
      isPaused: isPaused ?? this.isPaused,
      lockTaskUnavailable: lockTaskUnavailable ?? this.lockTaskUnavailable,
    );
  }
}

class FocusNotifier extends StateNotifier<FocusState> {
  final DatabaseHelper _dbHelper;
  final FocusService _service;
  Timer? _ticker;
  bool _starting = false;
  int _widgetUpdateCounter = 0;

  FocusNotifier(this._dbHelper, this._service) : super(const FocusState()) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final active = await _service.loadActiveSession();
      final strictPref = await _service.isStrictMode();
      await refreshHistory();
      state = state.copyWithState(
        active: active,
        isStrictMode: strictPref,
        isLoading: false,
      );
      if (active != null) _startTicker();
      await checkLockTaskAvailability();
    } catch (e) {
      debugPrint('Focus restore failed: $e');
      state = state.copyWithState(isLoading: false);
    }
  }

  /// Re-evaluates whether Android Lock Task is actually holding the device
  /// during a strict session and surfaces a warning when it is not.
  Future<void> checkLockTaskAvailability() async {
    final active = state.active;
    if (active == null || active.mode != FocusMode.strict) {
      if (state.lockTaskUnavailable) {
        state = state.copyWithState(lockTaskUnavailable: false);
      }
      return;
    }
    final ok = await FocusChannel.isLockTaskActive();
    state = state.copyWithState(lockTaskUnavailable: !ok);
  }

  Future<void> refreshHistory() async {
    try {
      final sessions = await _dbHelper.getFocusSessions(limit: 50);
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final minutes =
          await _dbHelper.getTotalFocusMinutes(rangeStart: startOfDay);
      state = state.copyWithState(history: sessions, minutesToday: minutes);
    } catch (e) {
      debugPrint('Focus history load failed: $e');
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final active = state.active;
    if (active == null) {
      _ticker?.cancel();
      return;
    }

    if (active.isExpired) {
      completeSession();
      return;
    }

    // Only rebuild state when the remaining time display changes
    // (every minute boundary or on expiry) to avoid rebuilding all
    // watching widgets every single second.
    final remaining = active.remaining;
    final newMinutes = remaining.isNegative ? 0 : remaining.inMinutes;
    final oldMinutes = state.active?.remaining.isNegative == true
        ? 0
        : (state.active?.remaining.inMinutes ?? 0);
    if (newMinutes != oldMinutes) {
      state = state.copyWithState(active: active);
    }

    // Update widget every 30 seconds to avoid excessive overhead
    _widgetUpdateCounter++;
    if (_widgetUpdateCounter >= 30) {
      _widgetUpdateCounter = 0;
      _updateFocusWidget();
    }
  }

  void _updateFocusWidget() {
    final active = state.active;
    if (active == null) {
      HomeWidgetService.refreshFocus(
        isActive: false,
        label: '',
        remainingMinutes: 0,
        remainingSeconds: 0,
        isStrict: false,
      );
      return;
    }
    final remaining = active.remaining;
    final mins = remaining.isNegative ? 0 : remaining.inMinutes;
    final secs = remaining.isNegative ? 0 : remaining.inSeconds % 60;
    HomeWidgetService.refreshFocus(
      isActive: true,
      label: active.label,
      remainingMinutes: mins,
      remainingSeconds: secs,
      isStrict: active.mode == FocusMode.strict,
    );
  }

  Future<void> setStrictMode(bool value) async {
    await _service.setStrictMode(value);
    state = state.copyWithState(isStrictMode: value);
  }

  Future<void> startFocus({
    required String label,
    String? taskId,
    required int minutes,
    required FocusMode mode,
  }) async {
    if (state.active != null || _starting) return;
    _starting = true;
    try {
      final session = await _service.startFocus(
        label: label,
        taskId: taskId,
        minutes: minutes,
        mode: mode,
      );
      state = state.copyWithState(
        active: session,
        isStrictMode: mode == FocusMode.strict,
        isPaused: false,
      );
      _startTicker();
      _updateFocusWidget();
      await checkLockTaskAvailability();
    } finally {
      _starting = false;
    }
  }

  Future<bool> verifyPinForExit(String pin) async {
    return PinService.verifyPin(pin);
  }

  Future<void> stopSession() async {
    final active = state.active;
    if (active == null) return;
    _ticker?.cancel();
    await _service.stopFocus(active, completed: false);
    state =
        state.copyWithState(active: null, isPaused: false, lockTaskUnavailable: false);
    _updateFocusWidget();
    await refreshHistory();
  }

  Future<void> completeSession() async {
    final active = state.active;
    if (active == null) return;
    _ticker?.cancel();
    await _service.stopFocus(active, completed: true);
    state =
        state.copyWithState(active: null, isPaused: false, lockTaskUnavailable: false);
    _updateFocusWidget();
    await refreshHistory();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final focusProvider =
    StateNotifierProvider<FocusNotifier, FocusState>((ref) {
  final dbHelper = ref.watch(databaseProvider);
  final service = ref.watch(focusServiceProvider);
  return FocusNotifier(dbHelper, service);
});
