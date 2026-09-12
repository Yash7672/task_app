import 'package:flutter/foundation.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart' show InputImage;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Thin wrapper around the ML Kit face detector.
///
/// IMPORTANT: ML Kit only finds faces — a detection is NEVER treated as a
/// successful unlock. Identity comes from the MobileFaceNet embedding +
/// cosine threshold in [FaceMatchingService], and liveness from
/// [FaceLivenessTracker].
class FaceDetectionService {
  FaceDetector? _detector;

  /// The detector instance for this service (created lazily).
  FaceDetector get detector =>
      _detector ??= FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableLandmarks: true,
          enableClassification: true,
        ),
      );

  Future<List<Face>> detectFromImage(InputImage image) async {
    try {
      return await detector.processImage(image);
    } catch (e) {
      debugPrint('ML Kit face detection failed: $e');
      return [];
    }
  }

  /// Releases the native detector. Call from the screen's dispose.
  Future<void> dispose() async {
    try {
      await _detector?.close();
    } catch (e) {
      debugPrint('Face detector close failed: $e');
    }
    _detector = null;
  }
}