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
      options.beforeSend = (event, hint) => _scrubEventPii(event);
    },
    appRunner: appRunner,
  );
}

/// Keys whose values are stripped from outgoing Sentry payloads.
///
/// Compared case-insensitively against keys in `event.request.data`,
/// `event.request.headers`, and `event.extra`. Matches mirror the
/// backend `scrub-pii` interceptor (commit 1f41d5b) so the two SDKs
/// hide the same fields.
const _kSensitiveKeys = <String>{
  'password',
  'currentpassword',
  'oldpassword',
  'newpassword',
  'phone',
  'token',
  'accesstoken',
  'refreshtoken',
  'authorization',
  'cardnumber',
  'cvv',
  'otp',
  'code',
};

/// Returns a new map with sensitive values replaced by `[Filtered]`.
///
/// Recursively scrubs nested maps. Returns `null` when the input is
/// `null` so callers can pass straight through to copyWith.
Map<String, dynamic>? _scrubMap(Map<String, dynamic>? source) {
  if (source == null) return null;
  final result = <String, dynamic>{};
  source.forEach((key, value) {
    if (_kSensitiveKeys.contains(key.toLowerCase())) {
      result[key] = '[Filtered]';
    } else if (value is Map<String, dynamic>) {
      result[key] = _scrubMap(value);
    } else if (value is Map) {
      // Maps from JSON may come in as Map<dynamic, dynamic>; normalize
      // to Map<String, dynamic> so we can recurse safely.
      result[key] = _scrubMap(value.map((k, v) => MapEntry(k.toString(), v)));
    } else {
      result[key] = value;
    }
  });
  return result;
}

/// Returns a new `Map<String, String>` with sensitive header values
/// replaced by `[Filtered]`. Header values are always strings, so a
/// shallow pass is enough.
Map<String, String>? _scrubHeaders(Map<String, String>? source) {
  if (source == null) return null;
  final result = <String, String>{};
  source.forEach((key, value) {
    result[key] =
        _kSensitiveKeys.contains(key.toLowerCase()) ? '[Filtered]' : value;
  });
  return result;
}

/// Builds a scrubbed copy of [event]. `SentryEvent`, `SentryRequest`,
/// and their nested maps are immutable (the SDK returns `Map.unmodifiable`
/// from getters), so we rebuild via `copyWith` instead of mutating.
SentryEvent _scrubEventPii(SentryEvent event) {
  final request = event.request;
  SentryRequest? scrubbedRequest;
  if (request != null) {
    final rawData = request.data;
    dynamic scrubbedData = rawData;
    if (rawData is Map) {
      scrubbedData = _scrubMap(
        rawData.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    // `headers` getter exposes Map<String, String>; rebuild a mutable copy.
    final scrubbedHeaders = _scrubHeaders(Map<String, String>.from(request.headers));
    scrubbedRequest = request.copyWith(
      data: scrubbedData,
      headers: scrubbedHeaders,
    );
  }

  // ignore: deprecated_member_use
  final scrubbedExtra = _scrubMap(event.extra);

  return event.copyWith(
    request: scrubbedRequest,
    // ignore: deprecated_member_use
    extra: scrubbedExtra,
  );
}
