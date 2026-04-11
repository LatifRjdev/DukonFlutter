import 'package:flutter_test/flutter_test.dart';

import 'package:dokonpro/core/errors/error_messages.dart';
import 'package:dokonpro/core/errors/exceptions.dart';

// Covers the full decision table for mapErrorToUserMessage so future
// refactors of the sealed-error layer cannot silently leak raw exception
// text to the UI (FE-P1-002 regression guard, FE-P0-002 seed coverage).

void main() {
  group('mapErrorToUserMessage', () {
    test('NetworkException → "Нет подключения к интернету"', () {
      expect(
        mapErrorToUserMessage(const NetworkException()),
        'Нет подключения к интернету',
      );
    });

    test('UnauthorizedException → session-expired message', () {
      expect(
        mapErrorToUserMessage(const UnauthorizedException()),
        'Сессия истекла. Войдите снова.',
      );
    });

    test('CacheException → local-storage message', () {
      expect(
        mapErrorToUserMessage(const CacheException('whatever')),
        'Ошибка локального хранилища',
      );
    });

    group('ServerException', () {
      const cases = <int, String>{
        400: 'Некорректные данные',
        403: 'Недостаточно прав',
        404: 'Объект не найден',
        409: 'Конфликт — объект уже существует',
        429: 'Слишком много попыток — попробуйте позже',
        500: 'Ошибка сервера — попробуйте позже',
        502: 'Ошибка сервера — попробуйте позже',
        503: 'Ошибка сервера — попробуйте позже',
      };

      for (final entry in cases.entries) {
        test('HTTP ${entry.key} → "${entry.value}"', () {
          expect(
            mapErrorToUserMessage(
              ServerException('anything', statusCode: entry.key),
            ),
            entry.value,
          );
        });
      }

      test('HTTP 418 (unmapped 4xx) → generic failure message', () {
        expect(
          mapErrorToUserMessage(
            ServerException('teapot', statusCode: 418),
          ),
          'Не удалось выполнить операцию',
        );
      });

      test('no status code → generic failure message', () {
        expect(
          mapErrorToUserMessage(const ServerException('boom')),
          'Не удалось выполнить операцию',
        );
      });

      test('never returns the raw message, even with a long body', () {
        const leakyMessage =
            'PostgresError: column "users.secret_internal_field" does not exist';
        final result = mapErrorToUserMessage(
          ServerException(leakyMessage, statusCode: 500),
        );
        expect(result.contains('PostgresError'), isFalse);
        expect(result.contains('secret_internal_field'), isFalse);
      });
    });

    group('unknown errors', () {
      test('plain Exception → generic failure (no raw text)', () {
        final err = Exception('http://10.0.2.2:4455/internal-host-leak');
        final result = mapErrorToUserMessage(err);
        expect(result, 'Не удалось выполнить операцию');
        expect(result.contains('10.0.2.2'), isFalse);
      });

      test('StateError → generic failure', () {
        expect(
          mapErrorToUserMessage(StateError('bad state')),
          'Не удалось выполнить операцию',
        );
      });

      test('String thrown as error → generic failure', () {
        expect(
          mapErrorToUserMessage('just a string'),
          'Не удалось выполнить операцию',
        );
      });
    });
  });
}
