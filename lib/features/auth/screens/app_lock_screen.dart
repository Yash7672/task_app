import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../navigation/app_navigation.dart';
import '../../../providers/security_provider.dart';
import '../../../services/security/biometric_service.dart';
import '../widgets/pin_pad.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  String? _errorText;
  bool _authenticating = false;
  IconData _biometricIcon = Icons.fingerprint;

  /// Drives the visible lockout countdown while it is active.
  Timer? _lockoutTicker;
  int _lockoutSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBiometricIcon();
      _syncLockout();
    });
  }

  void _syncLockout() {
    final notifier = ref.read(securityProvider.notifier);
    final seconds = notifier.pinLockoutSecondsLeft;
    if (seconds == _lockoutSecondsLeft) return;
    setState(() => _lockoutSecondsLeft = seconds);
    if (seconds > 0) {
      _lockoutTicker ??=
          Timer.periodic(const Duration(seconds: 1), (_) => _syncLockout());
    } else {
      _lockoutTicker?.cancel();
      _lockoutTicker = null;
      if (_errorText != null && mounted) setState(() => _errorText = null);
    }
  }

  Future<void> _loadBiometricIcon() async {
    final security = ref.read(securityProvider);
    final useFace =
        (security.faceIdEnabled && security.faceIdAvailable) ||
            await BiometricService.prefersFace();
    if (!mounted) return;
    setState(() => _biometricIcon = useFace ? Icons.face : Icons.fingerprint);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockoutTicker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final security = ref.read(securityProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        security.onAppPaused();
      case AppLifecycleState.resumed:
        security.onAppResumed();
        if (ref.read(securityProvider).requiresAuth) {
          setState(() => _errorText = null);
          _loadBiometricIcon();
        }
      default:
        break;
    }
  }

  Future<void> _authenticateWithBiometric() async {
    if (_authenticating) return;
    final notifier = ref.read(securityProvider.notifier);
    // Biometrics are also blocked while the PIN lockout is active, otherwise
    // the throttle could be bypassed with a single fingerprint scan.
    if (notifier.isPinLockedOut) {
      _syncLockout();
      return;
    }
    _authenticating = true;
    final security = ref.read(securityProvider);
    final reason = (security.faceIdEnabled && security.faceIdAvailable)
        ? 'Scan your face to unlock PYLO'
        : 'Unlock PYLO to access your tasks';
    final success = await BiometricService.authenticate(reason: reason);
    _authenticating = false;
    if (!mounted) return;
    if (success) {
      ref.read(securityProvider.notifier).unlock();
      setState(() => _errorText = null);
    } else {
      setState(() => _errorText = 'Biometric failed. Enter PIN.');
    }
  }

  Future<void> _onPinEntered(String pin) async {
    final notifier = ref.read(securityProvider.notifier);
    final valid = await notifier.verifyPinWithThrottle(pin);
    if (!mounted) return;
    if (valid) {
      notifier.unlock();
      setState(() => _errorText = null);
    } else if (notifier.isPinLockedOut) {
      setState(() => _errorText =
          'Too many attempts. Try again in $_lockoutSecondsLeft s.');
      _syncLockout();
    } else {
      final left =
          SecurityNotifier.maxPinAttempts - notifier.pinFailedAttempts;
      setState(() => _errorText = 'Incorrect PIN'
          '${left > 0 && left <= 2 ? ' — $left attempt${left == 1 ? '' : 's'} left' : ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);

    // When async security load completes, update the biometric icon.
    ref.listen<SecurityState>(securityProvider, (previous, next) {
      if ((previous?.isLoading ?? true) && !next.isLoading) {
        _loadBiometricIcon();
      }
    });

    if (security.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FlutterLogo(size: 64),
              SizedBox(height: 24),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    if (!security.requiresAuth) {
      return const AppNavigation();
    }

    final lockedOut = _lockoutSecondsLeft > 0;
    String? errorText = _errorText;
    if (lockedOut) {
      errorText = 'Too many attempts. Try again in $_lockoutSecondsLeft s.';
    }

    return Scaffold(
      body: PinPad(
        title: 'PYLO is locked',
        errorText: errorText,
        onPinCompleted: _onPinEntered,
        showBiometric:
            security.shouldOfferAnyBiometric && !lockedOut,
        onBiometricRequested: _authenticateWithBiometric,
        biometricIcon: _biometricIcon,
        enabled: !lockedOut,
        onInputChanged: errorText == null
            ? null
            : () {
                if (mounted && !lockedOut) {
                  setState(() => _errorText = null);
                }
              },
      ),
    );
  }
}
