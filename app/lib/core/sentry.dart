import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Initializes Sentry and runs [appRunner] inside the Sentry zone so
/// uncaught zone errors are captured.
///
/// DSN comes from `--dart-define=SENTRY_DSN_MOBILE=...`. When the DSN is
/// empty in release mode, this throws — release builds without crash
/// reporting are a regression.
Future<void> initSentryAndRun(Future<void> Function() appRunner) async {
  const dsn = String.fromEnvironment('SENTRY_DSN_MOBILE');

  if (dsn.isEmpty) {
    if (kReleaseMode) {
      throw StateError(
        'SENTRY_DSN_MOBILE must be set in release builds. '
        'Pass --dart-define=SENTRY_DSN_MOBILE=... at build time.',
      );
    }
    await appRunner();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = dsn;
      options.environment = kReleaseMode ? 'production' : 'debug';
      options.tracesSampleRate = kReleaseMode ? 0.1 : 0.0;
      options.attachStacktrace = true;
      options.sendDefaultPii = false;
    },
    appRunner: appRunner,
  );
}
