import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/core/errors/app_message.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/l10n/app_message_l10n.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  // The resolver's exhaustive switch already makes a MISSING case a compile
  // error. These cover what the compiler cannot see: a member wired to the
  // wrong key, or to one that resolves to nothing.
  test('should resolve every AppMessage member to a non-empty string', () {
    for (final message in AppMessage.values) {
      expect(message.resolve(l10n), isNotEmpty,
          reason: 'no localized string behind $message');
    }
  });

  test('should resolve every member to the string it is meant to carry', () {
    // This table is the contract, and it is the coverage the old
    // error_messages_test.dart used to provide before it was retargeted to
    // assert members instead of strings. Without it, swapping two arms of the
    // resolver — forbidden => errorNotFound — compiles, resolves non-empty,
    // and passes every other test in the suite.
    const expected = <AppMessage, String>{
      AppMessage.offline: 'Нет подключения к интернету',
      AppMessage.sessionExpired: 'Сессия истекла. Войдите снова.',
      AppMessage.badRequest: 'Некорректные данные',
      AppMessage.forbidden: 'Недостаточно прав',
      AppMessage.notFound: 'Объект не найден',
      AppMessage.conflict: 'Конфликт — объект уже существует',
      AppMessage.tooManyRequests: 'Слишком много попыток — попробуйте позже',
      AppMessage.serverError: 'Ошибка сервера — попробуйте позже',
      AppMessage.cacheError: 'Ошибка локального хранилища',
      AppMessage.unknownError: 'Не удалось выполнить операцию',
      AppMessage.profileUpdated: 'Профиль обновлён',
      AppMessage.passwordChanged: 'Пароль успешно изменён',
      AppMessage.expenseAdded: 'Расход добавлен',
      AppMessage.expenseUpdated: 'Расход обновлён',
      AppMessage.expenseDeleted: 'Расход удалён',
      AppMessage.paymentRecorded: 'Оплата записана',
      AppMessage.paymentAccepted: 'Оплата принята',
      AppMessage.zakatPaymentRecorded: 'Выплата закята записана',
      AppMessage.zakatSettingsSaved: 'Настройки закята сохранены',
      AppMessage.subscriptionRequestSent:
          'Заявка отправлена, ожидайте подтверждения',
      AppMessage.investmentCreated: 'Вложение добавлено',
      AppMessage.investmentUpdated: 'Вложение обновлено',
      AppMessage.investmentDeleted: 'Вложение удалено',
    };

    // Covering every member, so a new one cannot be added without a row here.
    expect(expected.keys.toSet(), AppMessage.values.toSet());

    for (final entry in expected.entries) {
      expect(entry.key.resolve(l10n), entry.value, reason: '${entry.key}');
    }
  });

  test('should give each error member a distinct string', () {
    // Two error codes resolving to the same text means the user cannot tell a
    // permissions problem from a missing object. The generic fallback is the
    // only deliberate catch-all and has a key of its own.
    const errors = [
      AppMessage.offline,
      AppMessage.sessionExpired,
      AppMessage.badRequest,
      AppMessage.forbidden,
      AppMessage.notFound,
      AppMessage.conflict,
      AppMessage.tooManyRequests,
      AppMessage.serverError,
      AppMessage.cacheError,
      AppMessage.unknownError,
    ];

    final strings = errors.map((m) => m.resolve(l10n)).toList();
    expect(strings.toSet().length, strings.length,
        reason: 'two error codes resolve to the same text: $strings');
  });
}
