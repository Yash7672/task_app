import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Three levels of glass surface depth used across the Glass theme.
///
/// Each level pairs a surface color, blur intensity, elevation, border and
/// shadow so surfaces visibly layer: background glass sits behind standard
/// cards, which sit behind floating controls. This creates real visual
/// hierarchy instead of identical transparency everywhere.
enum GlassDepth { level1, level2, level3 }

class GlassDepthConfig {
  final GlassDepth depth;
  final double opacity;
  final double blur;
  final double elevation;
  final Color borderColor;
  final List<BoxShadow> shadows;

  const GlassDepthConfig({
    required this.depth,
    required this.opacity,
    required this.blur,
    required this.elevation,
    required this.borderColor,
    required this.shadows,
  });

  static const level1 = GlassDepthConfig(
    depth: GlassDepth.level1,
    opacity: 0.08,
    blur: 36,
    elevation: 0,
    borderColor: GlassColors.border,
    shadows: [BoxShadow(color: Color(0x08000000), blurRadius: 20)],
  );

  static const level2 = GlassDepthConfig(
    depth: GlassDepth.level2,
    opacity: 0.12,
    blur: 42,
    elevation: 2,
    borderColor: GlassColors.borderMedium,
    shadows: [BoxShadow(color: Color(0x28000000), blurRadius: 24, offset: Offset(0, 6))],
  );

  static const level3 = GlassDepthConfig(
    depth: GlassDepth.level3,
    opacity: 0.18,
    blur: 48,
    elevation: 6,
    borderColor: GlassColors.borderStrong,
    shadows: [
      BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 10)),
      BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  static GlassDepthConfig of(GlassDepth depth) => switch (depth) {
        GlassDepth.level1 => level1,
        GlassDepth.level2 => level2,
        GlassDepth.level3 => level3,
      };
}