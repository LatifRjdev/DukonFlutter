import '../../core/errors/app_message.dart';
import '../../l10n/app_localizations.dart';

/// Turns an [AppMessage] into text, where a `BuildContext` exists.
///
/// This lives under `presentation/` on purpose: it depends on
/// `AppLocalizations`, and the enum it extends must stay importable from blocs,
/// which must not reach for a context.
///
/// The switch has **no `default`**. That is the enforcement: add a member to
/// [AppMessage] without a case here and the app does not compile, so a message
/// cannot ship with no string behind it.
extension AppMessageL10n on AppMessage {
  String resolve(AppLocalizations l10n) => switch (this) {
        // Errors. `offline` reuses the banner's key rather than minting a
        // second one for an identical string.
        AppMessage.offline => l10n.offlineBannerNoConnection,
        AppMessage.sessionExpired => l10n.errorSessionExpired,
        AppMessage.badRequest => l10n.errorBadRequest,
        AppMessage.forbidden => l10n.errorForbidden,
        AppMessage.notFound => l10n.errorNotFound,
        AppMessage.conflict => l10n.errorConflict,
        AppMessage.tooManyRequests => l10n.errorTooManyRequests,
        AppMessage.serverError => l10n.errorServer,
        AppMessage.cacheError => l10n.errorCache,
        AppMessage.unknownError => l10n.errorUnknown,

        // Successes. Six of these keys already existed; `passwordChanged`
        // reads "Пароль успешно изменён", one word longer than the literal the
        // bloc used to emit — reused rather than duplicated, per the l10n rule
        // that an existing key for the same meaning wins.
        AppMessage.profileUpdated => l10n.profileUpdated,
        AppMessage.passwordChanged => l10n.passwordChanged,
        AppMessage.expenseAdded => l10n.expenseAdded,
        AppMessage.expenseUpdated => l10n.expenseUpdated,
        AppMessage.expenseDeleted => l10n.expenseDeleted,
        AppMessage.paymentRecorded => l10n.paymentRecorded,
        AppMessage.paymentAccepted => l10n.paymentAccepted,
        AppMessage.zakatPaymentRecorded => l10n.zakatPaymentRecorded,
        AppMessage.zakatSettingsSaved => l10n.zakatSettingsSaved,
        AppMessage.subscriptionRequestSent => l10n.subscriptionRequestSent,
        AppMessage.investmentCreated => l10n.investmentCreated,
        AppMessage.investmentUpdated => l10n.investmentUpdated,
        AppMessage.investmentDeleted => l10n.investmentDeleted,
      };
}
