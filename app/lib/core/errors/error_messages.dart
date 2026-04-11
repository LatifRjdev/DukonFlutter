import 'exceptions.dart';

/// Map an arbitrary exception to a user-facing message.
///
/// Blocs used to emit \`e.toString()\` directly, which leaked the backend host,
/// Dio stack fragments, Prisma column names, and other internals to the UI
/// (FE-P1-002). This helper collapses every known exception type into one of
/// a small set of stable, localized user-facing messages.
///
/// The returned strings are deliberately Russian-only for now — see the
/// i18n sweep tracked by #29 for the full tg/uz migration.
String mapErrorToUserMessage(Object error) {
  if (error is NetworkException) {
    return 'Нет подключения к интернету';
  }
  if (error is UnauthorizedException) {
    // Unauthorized is often re-thrown from the token refresh path; show a
    // short "sign in again" message rather than the raw upstream text.
    return 'Сессия истекла. Войдите снова.';
  }
  if (error is ServerException) {
    // ServerException can carry a status code from the backend. Map the
    // common ones to friendly text; fall through to the generic message
    // otherwise (and never leak server-side stack text).
    final code = error.statusCode ?? 0;
    if (code == 400) return 'Некорректные данные';
    if (code == 403) return 'Недостаточно прав';
    if (code == 404) return 'Объект не найден';
    if (code == 409) return 'Конфликт — объект уже существует';
    if (code == 429) return 'Слишком много попыток — попробуйте позже';
    if (code >= 500) return 'Ошибка сервера — попробуйте позже';
    return 'Не удалось выполнить операцию';
  }
  if (error is CacheException) {
    return 'Ошибка локального хранилища';
  }
  // Unknown exception type — never dump raw toString() to the UI. Log it
  // via the bloc's logger if the caller needs forensic detail.
  return 'Не удалось выполнить операцию';
}
