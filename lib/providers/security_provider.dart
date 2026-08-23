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
  final bool faceIdEnabled;
  final bool faceIdAvailable;
  final bool hasPin;
  final LockTimeout lockTimeout;
  final bool isLocked;

  const SecurityState({
    this.isLoading = true,
    this.appLockEnabled = false,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.faceIdEnabled = false,
    this.faceIdAvailable = false,
    this.hasPin = false,
    this.lockTimeout = LockTimeout.immediately,
    this.isLocked = true,
  });

  bool get requiresAuth =>
      !isLoading && appLockEnabled && hasPin && isLocked;

  bool get shouldOfferBiometric =>
      requiresAuth && biometricEnabled && biometricAvailable;

  bool get shouldOfferFaceId => requiresAuth && faceIdEnabled && faceIdAvailable;

  bool get shouldOfferAnyBiometric =>
      shouldOfferBiometric || shouldOfferFaceId;

  SecurityState copyWith({
    bool? isLoading,
    bool? appLockEnabled,
    bool? biometricEnabled,
    bool? biometricAvailable,
    bool? faceIdEnabled,
    bool? faceIdAvailable,
    bool? hasPin,
    LockTimeout? lockTimeout,
    bool? isLocked,
  }) {
    return SecurityState(
      isLoading: isLoading ?? this.isLoading,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      faceIdEnabled: faceIdEnabled ?? this.faceIdEnabled,
      faceIdAvailable: faceIdAvailable ?? this.faceIdAvailable,
      hasPin: hasPin ?? this.hasPin,
      lockTimeout: lockTimeout ?? this.lockTimeout,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class SecurityNotifier extends StateNotifier<SecurityState> {
  /// Failed-PIN throttling: after [maxPinAttempts] wrong tries the lock
  /// screen refuses further attempts for a backoff window that doubles with
  /// every extra failure (capped at 15 min) and survives app restarts.
  static const int maxPinAttempts = 5;
  static const Duration _baseLockout = Duration(seconds: 30);
  static const Duration _maxLockout = Duration(minutes: 15);

  SecurityNotifier() : super(const SecurityState()) {
    load();
  }

  DateTime? _pausedAt;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  /// Number of consecutive wrong PINs since the last successful unlock.
  int get pinFailedAttempts => _failedAttempts;

  bool get isPinLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  /// Seconds left in the current lockout window (0 when none).
  int get pinLockoutSecondsLeft {
    if (!isPinLockedOut) return 0;
    return _lockoutUntil!.difference(DateTime.now()).inSeconds + 1;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPin = await PinService.hasPin();
      var appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;

      // Restore brute-force throttling state (survives restarts so killing
      // the app cannot bypass the backoff window).
      _failedAttempts = prefs.getInt('pin_failed_attempts') ?? 0;
      final lockoutMs = prefs.getInt('pin_lockout_until_ms');
      _lockoutUntil =
          lockoutMs != null ? DateTime.fromMillisecondsSinceEpoch(lockoutMs) : null;

      // Self-heal: if the PIN was lost (keystore reset / storage migration)
      // while App Lock was on, turn the lock off so the user can set a
      // fresh PIN instead of being permanently locked out.
      if (appLockEnabled && !hasPin) {
        appLockEnabled = false;
        await prefs.setBool('app_lock_enabled', false);
        await prefs.setBool('biometric_enabled', false);
        await prefs.setBool('face_id_enabled', false);
        debugPrint('App Lock self-healed: stored PIN missing');
      }

      final biometricAvailable = await BiometricService.isAvailable();
      final faceIdAvailable = await BiometricService.hasFace();

      state = state.copyWith(
        isLoading: false,
        appLockEnabled: appLockEnabled && hasPin,
        biometricEnabled: prefs.getBool('biometric_enabled') ?? false,
        biometricAvailable: biometricAvailable,
        faceIdEnabled: prefs.getBool('face_id_enabled') ?? false,
        faceIdAvailable: faceIdAvailable,
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

  /// Re-reads preference-backed fields (e.g. after a backup import) while
  /// KEEPING the current lock state — a plain [load] would re-lock an
  /// unlocked session out of nowhere.
  Future<void> reloadAfterRestore() async {
    final wasLocked = state.isLocked;
    await load();
    if (!mounted) return;
    if (!wasLocked) {
      state = state.copyWith(isLocked: false);
    }
  }

  Future<bool> enableAppLock(String pin) async {
    await PinService.setPin(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', true);
    state = state.copyWith(
      appLockEnabled: true,
      hasPin: true,
      // Do NOT lock right away: the user just proved they know this PIN by
      // setting it. Locking here yanks the UI out from under them.
      isLocked: false,
    );
    return true;
  }

  Future<void> disableAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', false);
    await prefs.setBool('biometric_enabled', false);
    await prefs.setBool('face_id_enabled', false);
    await PinService.clearPin();
    state = state.copyWith(
      appLockEnabled: false,
      biometricEnabled: false,
      faceIdEnabled: false,
      hasPin: false,
      isLocked: false,
    );
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
    state = state.copyWith(biometricEnabled: enabled);
  }

  Future<void> setFaceIdEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('face_id_enabled', enabled);
    state = state.copyWith(faceIdEnabled: enabled);
  }

  /// Returns 'ok', 'wrong_pin' or 'error'.
  Future<String> changePin(String oldPin, String newPin) async {
    try {
      await PinService.changePin(oldPin, newPin);
      state = state.copyWith(hasPin: true);
      return 'ok';
    } on WrongPinException {
      return 'wrong_pin';
    } catch (e) {
      debugPrint('Change PIN failed: $e');
      return 'error';
    }
  }

  /// Returns 'ok', 'wrong_pin' or 'error'. Unlike [verifyPin], storage
  /// failures surface as 'error' instead of looking like a wrong PIN.
  Future<String> verifyPinStrict(String pin) async {
    try {
      final ok = await PinService.verifyPinStrict(pin);
      return ok ? 'ok' : 'wrong_pin';
    } catch (e) {
      debugPrint('PIN verify failed: $e');
      return 'error';
    }
  }

  /// Re-checks whether the device has enrolled biometrics without touching
  /// lock state (safe to call from Settings at any time).
  Future<void> refreshBiometrics() async {
    try {
      final available = await BiometricService.isAvailable();
      final faceAvailable = await BiometricService.hasFace();
      if (state.biometricAvailable != available ||
          state.faceIdAvailable != faceAvailable) {
        state = state.copyWith(
          biometricAvailable: available,
          faceIdAvailable: faceAvailable,
        );
      }
    } catch (e) {
      debugPrint('Biometric refresh failed: $e');
    }
  }

  /// True when face recognition is the primary enrolled biometric.
  Future<bool> prefersFaceBiometric() => BiometricService.prefersFace();

  Future<bool> verifyPin(String pin) async {
    return PinService.verifyPin(pin);
  }

  /// [verifyPin] plus brute-force throttling. Returns false both for a wrong
  /// PIN and while locked out — callers should check [isPinLockedOut] to
  /// tell the user which happened.
  Future<bool> verifyPinWithThrottle(String pin) async {
    if (isPinLockedOut) return false;
    final prefs = await SharedPreferences.getInstance();
    final ok = await PinService.verifyPin(pin);
    if (ok) {
      _failedAttempts = 0;
      _lockoutUntil = null;
      await prefs.remove('pin_failed_attempts');
      await prefs.remove('pin_lockout_until_ms');
      return true;
    }
    _failedAttempts += 1;
    await prefs.setInt('pin_failed_attempts', _failedAttempts);
    if (_failedAttempts >= maxPinAttempts) {
      final extraFailures = _failedAttempts - maxPinAttempts;
      var lockout = _baseLockout * (1 << extraFailures.clamp(0, 8));
      if (lockout > _maxLockout) lockout = _maxLockout;
      _lockoutUntil = DateTime.now().add(lockout);
      await prefs.setInt(
          'pin_lockout_until_ms', _lockoutUntil!.millisecondsSinceEpoch);
    }
    return false;
  }

  Future<void> setLockTimeout(LockTimeout timeout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lock_timeout', timeout.name);
    state = state.copyWith(lockTimeout: timeout);
  }

  void unlock() {
    state = state.copyWith(isLocked: false);
    _pausedAt = null;
    // A successful unlock (PIN or biometric) resets the throttle.
    if (_failedAttempts > 0 || _lockoutUntil != null) {
      _failedAttempts = 0;
      _lockoutUntil = null;
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('pin_failed_attempts');
        prefs.remove('pin_lockout_until_ms');
      });
    }
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
