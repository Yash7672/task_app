import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../navigation/app_navigation.dart';
import '../../../providers/preferences_provider.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  final TextEditingController _pinController = TextEditingController();
  bool _authenticated = false;
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _authenticate(String pin, String expectedPin) {
    if (pin == expectedPin) {
      setState(() {
        _authenticated = true;
        _errorText = null;
      });
    } else {
      setState(() {
        _errorText = 'Incorrect PIN';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsPreferencesProvider);
    if (!settings.appLockEnabled ||
        settings.appLockPin.isEmpty ||
        _authenticated) {
      return const AppNavigation();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Enter PIN')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'App Lock is enabled.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter your 4-digit PIN to continue.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      errorText: _errorText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _authenticate(
                          _pinController.text.trim(), settings.appLockPin),
                      child: const Text('Unlock'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
