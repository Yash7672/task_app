import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FocusChannel {
  static const _channel = MethodChannel('pylo/focus');

  static final bool _isAndroid = !kIsWeb && Platform.isAndroid;

  static Future<bool> enterLockTask() async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('enterLockTask');
      return result ?? false;
    } catch (e) {
      debugPrint('FocusChannel.enterLockTask failed: $e');
      return false;
    }
  }

  static Future<bool> exitLockTask() async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('exitLockTask');
      return result ?? false;
    } catch (e) {
      debugPrint('FocusChannel.exitLockTask failed: $e');
      return false;
    }
  }

  static Future<bool> isLockTaskActive() async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isLockTaskActive');
      return result ?? false;
    } catch (e) {
      debugPrint('FocusChannel.isLockTaskActive failed: $e');
      return false;
    }
  }

  /// Enable or disable lock screen flags (show over lock screen, turn screen on).
  /// Used during strict focus to ensure the focus screen is always visible.
  static Future<bool> setLockScreenFlags(bool enabled) async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'setLockScreenFlags',
        {'enabled': enabled},
      );
      return result ?? false;
    } catch (e) {
      debugPrint('FocusChannel.setLockScreenFlags failed: $e');
      return false;
    }
  }
}
