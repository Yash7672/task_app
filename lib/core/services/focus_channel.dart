import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FocusChannel {
  static const _channel = MethodChannel('pylo/focus');

  static final bool _isAndroid = !kIsWeb && Platform.isAndroid;

  static StreamController<String>? _callStateController;
  static Stream<String>? _callStateStream;

  static Stream<String> get callStateStream {
    _callStateController ??= StreamController<String>.broadcast();
    _callStateStream ??= _callStateController!.stream;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCallStateChanged') {
        final state = call.arguments as String? ?? '';
        _callStateController?.add(state);
      }
    });

    return _callStateStream!;
  }

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

  static Future<bool> requestPhoneStatePermission() async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestPhoneStatePermission');
      return result ?? false;
    } catch (e) {
      debugPrint('FocusChannel.requestPhoneStatePermission failed: $e');
      return false;
    }
  }
}
