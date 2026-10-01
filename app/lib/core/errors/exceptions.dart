/// Exception types thrown by the data layer.
///
/// **The `message` field on every type below is diagnostic-only — it is never
/// shown to a user.** Three facts are worth knowing before you render it, log
/// it, or delete it as dead:
///
/// 1. `mapErrorToUserMessage` (lib/core/errors/error_messages.dart) is the only
///    thing that turns these into user-facing text, and it dispatches purely on
///    runtime type and [ServerException.statusCode]. It never reads `message`.
/// 2. The field is written at 108 construction sites and read at none. **38** of
///    those receive a genuine server-derived string — the 16 remote datasources
///    each decode one and feed it to both a `ServerException` and an
///    `UnauthorizedException`, plus a few inline sites; the specific
///    `e.response?.data?['message']` expression appears at 2 of them. So the
///    field is capturing real diagnostic detail, which is why it is kept rather
///    than deleted.
/// 3. There is no logger consuming it. The app has no logging infrastructure at
///    all, so today the field is write-only. Introducing one is tracked
///    separately and has its own PII constraints (see .claude/rules/security.md,
///    which forbids logging tokens and PII).
///
/// Consequence for i18n: text in this field must NOT be translated, and must
/// not be treated as deferred UI copy. English is correct here.
class ServerException implements Exception {
  final String message;
  final int? statusCode;
  const ServerException(this.message, {this.statusCode});
}

class CacheException implements Exception {
  final String message;
  const CacheException(this.message);
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'No internet connection']);
}

class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'Unauthorized']);
}
