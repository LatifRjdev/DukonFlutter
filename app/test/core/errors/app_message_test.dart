import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/core/errors/app_message.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/l10n/app_message_l10n.dart';

void main() {
  // Iterating AppMessage.values is the point. The resolver's exhaustive switch
  // already makes a missing case a compile error; this catches the other half —
  // a member wired to a key that resolves to nothing — and keeps holding even
  // if someone later weakens the switch with a `default`.
  test('should resolve every AppMessage member to a non-empty string in ru',
      () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

    for (final message in AppMessage.values) {
      expect(message.resolve(l10n), isNotEmpty,
          reason: 'no localized string behind $message');
    }
  });

  test('should give each error member its own distinct string', () {
    // Not a style check: two error codes sharing a string means the user
    // cannot tell a permissions problem from a missing object. The only
    // deliberate overlap is the generic fallback, which has one key.
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

    expect(errors.toSet().length, errors.length);
  });
}
