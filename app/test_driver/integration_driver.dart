// app/test_driver/integration_driver.dart
//
// Driver entry point for `flutter drive --target=integration_test/...`.
//
// Persists each screenshot taken via `binding.takeScreenshot(name)` to
//   integration_test/screenshots/<device-slug>/<name>.png
//
// The device slug is read from `--dart-define=DEVICE_SLUG=...`. If unset,
// it falls back to `Platform.operatingSystem` (e.g. "ios", "android"), so
// the directory layout is at least one folder deep.

import 'dart:async';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  // Resolve output directory once, up front. We use the integration_test
  // dir relative to CWD when `flutter drive` is invoked from the app root.
  final deviceSlug = Platform.environment['DEVICE_SLUG'] ??
      const String.fromEnvironment('DEVICE_SLUG',
          defaultValue: '') ;
  final slug = deviceSlug.isNotEmpty
      ? deviceSlug
      : Platform.operatingSystem; // 'ios' | 'android' | 'macos'

  final outDir = Directory('integration_test/screenshots/$slug');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes,
        [Map<String, Object?>? args]) async {
      try {
        final file = File('${outDir.path}/$screenshotName.png');
        await file.writeAsBytes(screenshotBytes, flush: true);
        // ignore: avoid_print
        print('  saved screenshot: ${file.path}');
        return true;
      } catch (e) {
        // ignore: avoid_print
        print('  FAILED to save $screenshotName: $e');
        return false;
      }
    },
  );
}
