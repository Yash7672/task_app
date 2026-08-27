import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/focus_session_model.dart';
import '../services/focus/focus_service.dart';
import '../services/security/pin_service.dart';
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

  const FocusState({
    this.active,
    this.history = const [],
    this.minutesToday = 0,
    this.isLoading = true,
    this.isStrictMode = false,
    this.isPaused = false,
  });

  FocusState copyWithState({
    Object? active = _clearActive,
    List<FocusSession>? history,
    int? minutesToday,
    bool? isLoading,
    bool? isStrictMode,
    bool? isPaused,
  }) {
    return FocusState(
      active: active == _clearActive ? this.active : active as ActiveFocus?,
      history: history ?? this.history,
      minutesToday: minutesToday ?? this.minutesToday,
      isLoading: isLoading ?? this.isLoading,
      isStrictMode: isStrictMode ?? this.isStrictMode,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

class FocusNotifier extends StateNotifier<FocusState> {
  final DatabaseHelper _dbHelper;
  final FocusService _service;
  Timer? _ticker;
  bool _starting = false;

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
    } catch (e) {
      debugPrint('Focus restore failed: $e');
      state = state.copyWithState(isLoading: false);
    }
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

    state = state.copyWithState(active: active);
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
    state = state.copyWithState(active: null, isPaused: false);
    await refreshHistory();
  }

  Future<void> completeSession() async {
    final active = state.active;
    if (active == null) return;
    _ticker?.cancel();
    await _service.stopFocus(active, completed: true);
    state = state.copyWithState(active: null, isPaused: false);
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
