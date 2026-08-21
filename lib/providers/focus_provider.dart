import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/focus_session_model.dart';
import '../services/focus/focus_service.dart';
import 'database_provider.dart';

final focusServiceProvider = Provider<FocusService>((ref) => FocusService());

class FocusState {
  final ActiveFocus? active;
  final List<FocusSession> history;
  final int minutesToday;
  final bool isLoading;

  const FocusState({
    this.active,
    this.history = const [],
    this.minutesToday = 0,
    this.isLoading = true,
  });

  FocusState copyWith({
    ActiveFocus? active,
    List<FocusSession>? history,
    int? minutesToday,
    bool? isLoading,
  }) {
    return FocusState(
      active: active,
      history: history ?? this.history,
      minutesToday: minutesToday ?? this.minutesToday,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FocusNotifier extends StateNotifier<FocusState> {
  final DatabaseHelper _dbHelper;
  final FocusService _service;
  Timer? _ticker;

  FocusNotifier(this._dbHelper, this._service) : super(const FocusState()) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final active = await _service.loadActiveSession();
      await refreshHistory();
      state = state.copyWith(active: active, isLoading: false);
      if (active != null) _startTicker();
    } catch (e) {
      debugPrint('Focus restore failed: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refreshHistory() async {
    try {
      final sessions = await _dbHelper.getFocusSessions(limit: 50);
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final minutes =
          await _dbHelper.getTotalFocusMinutes(rangeStart: startOfDay);
      state = state.copyWith(history: sessions, minutesToday: minutes);
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

    state = state.copyWith(active: active);
  }

  Future<void> startFocus({
    required String label,
    String? taskId,
    required int minutes,
  }) async {
    if (state.active != null) return;
    final session = await _service.startFocus(
      label: label,
      taskId: taskId,
      minutes: minutes,
    );
    state = state.copyWith(active: session);
    _startTicker();
  }

  Future<void> stopSession() async {
    final active = state.active;
    if (active == null) return;
    _ticker?.cancel();
    await _service.stopFocus(active, completed: false);
    state = state.copyWith(active: null);
    await refreshHistory();
  }

  Future<void> completeSession() async {
    final active = state.active;
    if (active == null) return;
    _ticker?.cancel();
    await _service.stopFocus(active, completed: true);
    state = state.copyWith(active: null);
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
