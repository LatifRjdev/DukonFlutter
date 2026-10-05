import 'app_message.dart';
import 'exceptions.dart';

/// Map an arbitrary exception to a user-facing message *code*.
///
/// Blocs used to emit `e.toString()` directly, which leaked the backend host,
/// Dio stack fragments, Prisma column names, and other internals to the UI
/// (FE-P1-002). This helper collapses every known exception type into one of a
/// small, closed set.
///
/// It returns an [AppMessage] rather than a string so the text can be
/// localized: a bloc has no `BuildContext`, so anything it baked in was Russian
/// forever and unreachable from `app_tg.arb` and `app_uz.arb`. The widget calls
/// `.resolve(l10n)`.
///
/// Note what this function does **not** read: the exception's own `message`
/// field. Dispatch is purely on runtime type and [ServerException.statusCode].
/// That field is diagnostic and deliberately English — `exceptions.dart`
/// explains why — and nothing here can surface it.
AppMessage mapErrorToAppMessage(Object error) {
  if (error is NetworkException) {
    return AppMessage.offline;
  }
  if (error is UnauthorizedException) {
    // Unauthorized is often re-thrown from the token refresh path; show a
    // short "sign in again" message rather than the raw upstream text.
    return AppMessage.sessionExpired;
  }
  if (error is ServerException) {
    final code = error.statusCode ?? 0;
    if (code == 400) return AppMessage.badRequest;
    if (code == 403) return AppMessage.forbidden;
    if (code == 404) return AppMessage.notFound;
    if (code == 409) return AppMessage.conflict;
    if (code == 429) return AppMessage.tooManyRequests;
    if (code >= 500) return AppMessage.serverError;
    return AppMessage.unknownError;
  }
  if (error is CacheException) {
    return AppMessage.cacheError;
  }
  // Unknown exception type. Never dump raw toString() to the UI; log it via the
  // bloc's logger if the caller needs forensic detail.
  return AppMessage.unknownError;
}
