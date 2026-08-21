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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoBiometric();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          _maybeAutoBiometric();
        }
      default:
        break;
    }
  }

  Future<void> _maybeAutoBiometric() async {
    final state = ref.read(securityProvider);
    if (!state.shouldOfferBiometric || _authenticating) return;
    await _authenticateWithBiometric();
  }

  Future<void> _authenticateWithBiometric() async {
    if (_authenticating) return;
    _authenticating = true;
    final success = await BiometricService.authenticate(
      reason: 'Unlock PYLO to access your tasks',
    );
    _authenticating = false;
    if (!mounted) return;
    if (success) {
      ref.read(securityProvider.notifier).unlock();
    } else {
      setState(() => _errorText = 'Biometric failed. Enter PIN.');
    }
  }

  Future<void> _onPinEntered(String pin) async {
    final valid = await ref.read(securityProvider.notifier).verifyPin(pin);
    if (!mounted) return;
    if (valid) {
      ref.read(securityProvider.notifier).unlock();
      setState(() => _errorText = null);
    } else {
      setState(() => _errorText = 'Incorrect PIN');
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);

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

    return Scaffold(
      body: PinPad(
        title: 'PYLO is locked',
        errorText: _errorText,
        onPinCompleted: _onPinEntered,
        showBiometric: security.shouldOfferBiometric,
        onBiometricRequested: _authenticateWithBiometric,
      ),
    );
  }
}
