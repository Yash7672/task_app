import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
  static const _pinKey = 'pylo_app_lock_pin';

  static Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
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
    final valid = await verifyPin(oldPin);
    if (!valid) {
      throw Exception('Incorrect current PIN');
    }
    await setPin(newPin);
  }

  static Future<void> clearPin() async {
    await _storage.delete(key: _pinKey);
  }
}
