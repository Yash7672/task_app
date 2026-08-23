import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isDeviceSupported) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      debugPrint('PYLO biometrics reported by device: '
          '${enrolled.map((b) => b.name).toList()}');
      return enrolled.isNotEmpty;
    } catch (e) {
      debugPrint('Biometric availability check failed: $e');
      return false;
    }
  }

  static Future<bool> hasEnrolledBiometrics() async {
    if (kIsWeb) return false;
    try {
      return await _auth.getAvailableBiometrics().then((list) => list.isNotEmpty);
    } catch (e) {
      debugPrint('Enrolled biometrics check failed: $e');
      return false;
    }
  }

  /// True when a face-recognition biometric (e.g. Face ID) is enrolled on
  /// this device, regardless of what else is enrolled.
  static Future<bool> hasFace() async {
    if (kIsWeb) return false;
    try {
      final list = await _auth.getAvailableBiometrics();
      return list.contains(BiometricType.face);
    } catch (e) {
      debugPrint('Face biometric check failed: $e');
      return false;
    }
  }

  /// True when face recognition is the enrolled biometric (e.g. Face ID),
  /// used to pick the right icon on the lock screen.
  static Future<bool> prefersFace() async {
    if (kIsWeb) return false;
    try {
      final list = await _auth.getAvailableBiometrics();
      final hasFace = list.contains(BiometricType.face);
      final hasFingerprint = list.contains(BiometricType.fingerprint);
      return hasFace && !hasFingerprint;
    } catch (e) {
      debugPrint('Biometric type check failed: $e');
      return false;
    }
  }

  static Future<bool> authenticate({required String reason}) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('Biometric auth failed: $e');
      return false;
    }
  }
}
