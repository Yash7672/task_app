import 'dart:typed_data';
import 'dart:math' as math;

import 'face_id_config.dart';
import 'face_template_store.dart';

/// Result of comparing a probe embedding against a stored template.
class FaceMatchResult {
  /// Best cosine similarity across all enrolled poses (-1 .. 1).
  final double score;

  /// True when [score] meets [FaceIdConfig.similarityThreshold].
  final bool matched;

  const FaceMatchResult({required this.score, required this.matched});

  const FaceMatchResult.noMatch() : score = -1.0, matched = false;
}

/// Embedding math for face verification. All operations are plain Dart on
/// float arrays — no cloud, no platform channels, purely numeric.
class FaceMatchingService {
  /// Cosine similarity between two 192-d normalized embeddings.
  static double cosineSimilarity(Float32List a, Float32List b) {
    final len = math.min(a.length, b.length);
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    for (var i = 0; i < len; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    final denom = math.sqrt(na) * math.sqrt(nb);
    if (denom < 1e-9) return -1.0;
    return dot / denom;
  }

  /// Best similarity of [probe] against all enrolled poses in [template].
  static FaceMatchResult bestMatch(Float32List probe, FaceTemplate template) {
    var best = -1.0;
    for (final enrolled in template.embeddings) {
      final score = cosineSimilarity(probe, enrolled);
      if (score > best) best = score;
    }
    if (best < FaceIdConfig.similarityThreshold) {
      return FaceMatchResult(score: best, matched: false);
    }
    return FaceMatchResult(score: best, matched: true);
  }
}