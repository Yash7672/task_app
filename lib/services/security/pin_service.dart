import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WrongPinException implements Exception {
  final String message;
  WrongPinException(this.message);
  @override
  String toString() => message;
}

class PinStorageException implements Exception {
  final String message;
  PinStorageException(this.message);
  @override
  String toString() => message;
}

class PinService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
  static const _pinKey = 'pylo_app_lock_pin';

  static Future<void> setPin(String pin) async {
    try {
      await _storage.write(key: _pinKey, value: pin);
    } catch (e) {
      debugPrint('Pin write failed: $e');
      throw PinStorageException('Could not save PIN securely');
    }
  }

  static Future<String?> getPin() async {
    try {
      return await _storage.read(key: _pinKey);
    } catch (e) {
      debugPrint('Pin read failed: $e');
      return null;
    }
  }

  static Future<bool> verifyPin(String pin) async {
    final stored = await getPin();
    return stored != null && stored == pin;
  }

  static Future<bool> hasPin() async {
    final stored = await getPin();
    return stored != null && stored.isNotEmpty;
  }

  static Future<void> changePin(String oldPin, String newPin) async {
    String? stored;
    try {
      stored = await _storage.read(key: _pinKey);
    } catch (e) {
      debugPrint('Pin read failed during change: $e');
      throw PinStorageException('Could not read the saved PIN');
    }

    if (stored == null || stored.isEmpty) {
      // Stored PIN was lost (e.g. OS keystore reset / storage migration).
      // Allow setting a fresh one instead of locking the user out.
      debugPrint('Stored PIN missing — allowing fresh PIN setup');
    } else if (stored != oldPin) {
      throw WrongPinException('Current PIN is incorrect');
    }

    await setPin(newPin);
  }

  static Future<void> clearPin() async {
    try {
      await _storage.delete(key: _pinKey);
    } catch (e) {
      debugPrint('Pin delete failed: $e');
    }
  }
}
