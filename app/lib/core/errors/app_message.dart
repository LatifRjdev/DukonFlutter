/// A user-facing message, as a value rather than a string.
///
/// Blocs used to put Russian text straight into state objects — the error
/// mapper returned a hardcoded string, and success states were built from
/// inline literals like `SettingsActionSuccess('Профиль обновлён')`. Neither
/// could be translated: `app_tg.arb` and `app_uz.arb` cannot reach a string a
/// bloc baked in, so Tajik and Uzbek users saw Russian for every error and
/// every confirmation.
///
/// A bloc now emits one of these and the widget resolves it through
/// `AppLocalizations` — see `presentation/l10n/app_message_l10n.dart`. The
/// resolver's switch has no `default`, so a member added here without an ARB
/// key will not compile.
///
/// This file must stay free of Flutter imports: blocs depend on it, and
/// `AppLocalizations` is context-bound.
enum AppMessage {
  // ── Errors ───────────────────────────────────────────────────────────────
  // Produced by mapErrorToAppMessage, which dispatches only on the exception's
  // runtime type and ServerException.statusCode.
  offline,
  sessionExpired,
  badRequest,
  forbidden,
  notFound,
  conflict,
  tooManyRequests,
  serverError,
  cacheError,

  /// Two branches share this: an unrecognised exception type, and a
  /// ServerException whose status code has no specific mapping.
  unknownError,

  // ── Successes ────────────────────────────────────────────────────────────
  // One member per distinct string, not per state class: ExpenseActionSuccess
  // alone carries three.
  profileUpdated,
  passwordChanged,
  expenseAdded,
  expenseUpdated,
  expenseDeleted,
  paymentRecorded,
  paymentAccepted,
  zakatPaymentRecorded,
  zakatSettingsSaved,
  subscriptionRequestSent,

  /// Absorbed from the former `InvestmentL10nKey`, which proved this pattern
  /// first but duplicated its resolve switch across two pages.
  investmentCreated,
  investmentUpdated,
  investmentDeleted,
}
