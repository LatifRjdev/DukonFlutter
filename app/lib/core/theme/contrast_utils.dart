import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Computes the WCAG 2.1 relative-luminance-based contrast ratio between two
/// colors.
///
/// Returns a value in `[1.0, 21.0]`. WCAG AA thresholds:
/// - Normal text (< 18pt regular or < 14pt bold): ≥ 4.5
/// - Large text (≥ 18pt regular or ≥ 14pt bold): ≥ 3.0
///
/// Reference: https://www.w3.org/TR/WCAG21/#contrast-minimum
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color c) {
  // Flutter 3.27+ Color 4 API: `.r` / `.g` / `.b` return doubles in [0.0, 1.0].
  final r = _channel(c.r);
  final g = _channel(c.g);
  final b = _channel(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _channel(double v) {
  return v <= 0.03928
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}
