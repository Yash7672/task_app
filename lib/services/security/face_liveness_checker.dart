import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_id_config.dart';

/// Lightweight liveness state machine for Face ID unlock.
///
/// It is intentionally NOT bank-grade: with a plain RGB camera there is no
/// depth or IR data, so a high-quality photo/video replay can still fool the
/// system. What this provides is a meaningful barrier against holding a
/// static photo of the owner in front of the lens:
///
///  * Primary — blink: the ML Kit eye-open probabilities must transition from
///    "open" back to "clearly closed" at least once.
///  * Fallback — motion: when eye probabilities are absent (e.g. glasses or
///    a distant face), a smooth head-yaw swing of at least a few degrees
///    across consecutive frames counts as the same proof of a live, moving
///    subject.
///
/// Liveness is enforced only for UNLOCK, never during enrollment.
class FaceLivenessTracker {
  bool _blinked = false;
  double? _prevEyeOpenMean;

  final List<double> _recentYaw = <double>[];
  bool _moved = false;

  /// Consume one detected face. Call once per accepted capture.
  void feed(Face face) {
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;

    if (left != null && right != null) {
      final mean = (left + right) / 2;
      if (_prevEyeOpenMean != null) {
        if (_prevEyeOpenMean! >= FaceIdConfig.blinkOpenBoundary &&
            mean < FaceIdConfig.blinkClosedBoundary) {
          _blinked = true;
        }
      }
      _prevEyeOpenMean = mean;
    } else {
      // No eye probabilities — ignore them entirely rather than decay the
      // classic blink signal across mixed frames.
    }

    final yaw = face.headEulerAngleY;
    if (yaw != null) _trackMotion(yaw);
  }

  void _trackMotion(double yaw) {
    _recentYaw.add(yaw);
    if (_recentYaw.length > FaceIdConfig.fallbackMovementFrames) {
      _recentYaw.removeAt(0);
    }
    if (_recentYaw.length == FaceIdConfig.fallbackMovementFrames) {
      final minYaw = _recentYaw.reduce(math.min);
      final maxYaw = _recentYaw.reduce(math.max);
      if (maxYaw - minYaw >= FaceIdConfig.fallbackMovementDegrees) {
        _moved = true;
        _recentYaw.clear();
      }
    }
  }

  /// True once a blink, sustained head motion, or both has been observed.
  bool get verified => _blinked || _moved;

  bool get sawBlink => _blinked;
  bool get sawMotion => _moved;

  void reset() {
    _blinked = false;
    _prevEyeOpenMean = null;
    _recentYaw.clear();
    _moved = false;
  }
}