import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/security/biometric_service.dart';
import '../../services/security/pin_service.dart';

enum LockTimeout { immediately, seconds30, minute1, minutes5 }

extension LockTimeoutX on LockTimeout {
  Duration get duration => switch (this) {
        LockTimeout.immediately => Duration.zero,
        LockTimeout.seconds30 => const Duration(seconds: 30),
        LockTimeout.minute1 => const Duration(minutes: 1),
        LockTimeout.minutes5 => const Duration(minutes: 5),
      };

  String get label => switch (this) {
        LockTimeout.immediately => 'Immediately',
        LockTimeout.seconds30 => 'After 30 seconds',
        LockTimeout.minute1 => 'After 1 minute',
        LockTimeout.minutes5 => 'After 5 minutes',
      };

  static LockTimeout fromName(String? name) => LockTimeout.values
      .firstWhere((v) => v.name == name, orElse: () => LockTimeout.immediately);
}

class SecurityState {
  final bool isLoading;
  final bool appLockEnabled;
  final bool biometricEnabled;
  final bool biometricAvailable;
  final bool hasPin;
  final LockTimeout lockTimeout;
  final bool isLocked;

  const SecurityState({
    this.isLoading = true,
    this.appLockEnabled = false,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.hasPin = false,
    this.lockTimeout = LockTimeout.immediately,
    this.isLocked = true,
  });

  bool get requiresAuth =>
      !isLoading && appLockEnabled && hasPin && isLocked;

  bool get shouldOfferBiometric =>
      requiresAuth && biometricEnabled && biometricAvailable;

  SecurityState copyWith({
    bool? isLoading,
    bool? appLockEnabled,
    bool? biometricEnabled,
    bool? biometricAvailable,
    bool? hasPin,
    LockTimeout? lockTimeout,
    bool? isLocked,
  }) {
    return SecurityState(
      isLoading: isLoading ?? this.isLoading,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      hasPin: hasPin ?? this.hasPin,
      lockTimeout: lockTimeout ?? this.lockTimeout,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class SecurityNotifier extends StateNotifier<SecurityState> {
  SecurityNotifier() : super(const SecurityState()) {
    load();
  }

  DateTime? _pausedAt;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPin = await PinService.hasPin();
      final appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;

      // Self-heal: if the PIN was lost (keystore reset / storage migration)
      // while App Lock was on, turn the lock off so the user can set a
      // fresh PIN instead of being permanently locked out.
      if (appLockEnabled && !hasPin) {
        await prefs.setBool('app_lock_enabled', false);
        await prefs.setBool('biometric_enabled', false);
        debugPrint('App Lock self-healed: stored PIN missing');
      }

      final biometricAvailable = await BiometricService.isAvailable();

      state = state.copyWith(
        isLoading: false,
        appLockEnabled: appLockEnabled && hasPin,
        biometricEnabled: prefs.getBool('biometric_enabled') ?? false,
        biometricAvailable: biometricAvailable,
        hasPin: hasPin,
        lockTimeout:
            LockTimeoutX.fromName(prefs.getString('lock_timeout')),
        isLocked: true,
      );
    } catch (e) {
      debugPrint('Security load failed: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> enableAppLock(String pin) async {
    await PinService.setPin(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', true);
    state = state.copyWith(
      appLockEnabled: true,
      hasPin: true,
      isLocked: true,
    );
    return true;
  }

  Future<void> disableAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', false);
    await prefs.setBool('biometric_enabled', false);
    await PinService.clearPin();
    state = state.copyWith(
      appLockEnabled: false,
      biometricEnabled: false,
      hasPin: false,
      isLocked: false,
    );
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
    state = state.copyWith(biometricEnabled: enabled);
  }

  /// Returns 'ok', 'wrong_pin' or 'error'.
  Future<String> changePin(String oldPin, String newPin) async {
    try {
      await PinService.changePin(oldPin, newPin);
      return 'ok';
    } on WrongPinException {
      return 'wrong_pin';
    } catch (e) {
      debugPrint('Change PIN failed: $e');
      return 'error';
    }
  }

  Future<bool> verifyPin(String pin) async {
    return PinService.verifyPin(pin);
  }

  Future<void> setLockTimeout(LockTimeout timeout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lock_timeout', timeout.name);
    state = state.copyWith(lockTimeout: timeout);
  }

  void unlock() {
    state = state.copyWith(isLocked: false);
    _pausedAt = null;
  }

  void lockNow() {
    if (state.appLockEnabled && state.hasPin) {
      state = state.copyWith(isLocked: true);
    }
  }

  void onAppPaused() {
    _pausedAt = DateTime.now();
  }

  void onAppResumed() {
    if (_pausedAt == null) return;
    final elapsed = DateTime.now().difference(_pausedAt!);
    _pausedAt = null;
    if (state.appLockEnabled &&
        state.hasPin &&
        elapsed >= state.lockTimeout.duration) {
      state = state.copyWith(isLocked: true);
    }
  }
}

final securityProvider =
    StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  return SecurityNotifier();
});
