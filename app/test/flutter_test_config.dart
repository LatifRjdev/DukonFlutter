// app/test/flutter_test_config.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

/// Wraps [LocalFileComparator] with a small pixel-difference tolerance so
/// Impeller's non-deterministic rendering (~0.03–0.10% drift between runs
/// even without code changes) does not spuriously fail golden tests.
///
/// Threshold (0.2%) catches real regressions — typical intentional visual
/// changes register 3%+ — while absorbing the Impeller noise observed in
/// Sprints 5B/6.
class _ToleranceFileComparator extends LocalFileComparator {
  _ToleranceFileComparator(super.testFile, {required this.toleranceFraction});

  final double toleranceFraction;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) return true;
    if (result.diffPercent <= toleranceFraction) {
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final previousComparator = goldenFileComparator;
  if (previousComparator is LocalFileComparator) {
    goldenFileComparator = _ToleranceFileComparator(
      Uri.parse('${previousComparator.basedir}test.dart'),
      toleranceFraction: 0.002, // 0.2%
    );
  }

  return GoldenToolkit.runWithConfiguration(
    () async {
      await loadAppFonts();
      await testMain();
    },
    config: GoldenToolkitConfiguration(
      enableRealShadows: true,
      defaultDevices: const [Device.iphone11],
    ),
  );
}
