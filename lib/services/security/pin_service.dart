import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
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

/// PINs are never stored verbatim: a fresh PIN is saved as
/// `v1:<salt>:<sha256(salt|pin)>`. Legacy plaintext entries (from earlier
/// versions) are still accepted and transparently upgraded to the hashed
/// form on the first successful verification.
class PinService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
  static const _pinKey = 'pylo_app_lock_pin';

  static String _hash(String salt, String pin) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  static String _encode(String pin) {
    final random = Random.secure();
    final salt = base64UrlEncode(
        List<int>.generate(16, (_) => random.nextInt(256)));
    return 'v1:$salt:${_hash(salt, pin)}';
  }

  /// Returns true when [stored] matches [pin], handling both the hashed and
  /// the legacy plaintext format.
  static bool _matches(String stored, String pin) {
    if (stored.startsWith('v1:')) {
      final parts = stored.split(':');
      if (parts.length != 3) return false;
      return _hash(parts[1], pin) == parts[2];
    }
    // Legacy plaintext value from an older version.
    return stored == pin;
  }

  /// Rewrites a legacy plaintext entry as a salted hash after a successful
  /// match. Best-effort: failure keeps the old value working.
  static Future<void> _upgradeLegacy(String stored, String pin) async {
    if (stored.startsWith('v1:')) return;
    try {
      await _storage.write(key: _pinKey, value: _encode(pin));
      debugPrint('Upgraded stored PIN to hashed form');
    } catch (e) {
      debugPrint('PIN hash upgrade failed (legacy value kept): $e');
    }
  }

  static Future<void> setPin(String pin) async {
    try {
      await _storage.write(key: _pinKey, value: _encode(pin));
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
    if (stored == null || !_matches(stored, pin)) return false;
    await _upgradeLegacy(stored, pin);
    return true;
  }

  /// Like [verifyPin] but rethrows storage failures so callers can tell a
  /// broken keystore apart from a genuinely wrong PIN (which otherwise looks
  /// like an endless 'incorrect PIN' loop).
  static Future<bool> verifyPinStrict(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    if (stored == null || !_matches(stored, pin)) return false;
    await _upgradeLegacy(stored, pin);
    return true;
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
    } else if (!_matches(stored, oldPin)) {
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
