import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/core/errors/app_message.dart';
import 'package:dukonpro/core/errors/error_messages.dart';
import 'package:dukonpro/core/errors/exceptions.dart';

// Covers the full decision table for mapErrorToAppMessage so future refactors
// of the sealed-error layer cannot silently leak raw exception text to the UI
// (FE-P1-002 regression guard, FE-P0-002 seed coverage).
//
// The leak tests below now assert something the TYPE guarantees: the mapper
// returns an enum, so no exception text can reach the UI through it by
// construction. They are kept because they pin the branch each leaky input
// lands on — a future `default` that swallowed everything into one member
// would still be wrong, and these say which member is right.

void main() {
  group('mapErrorToAppMessage', () {
    test('should report offline when the exception is a NetworkException', () {
      expect(mapErrorToAppMessage(const NetworkException()), AppMessage.offline);
    });

    test('should report an expired session when unauthorized', () {
      expect(
        mapErrorToAppMessage(const UnauthorizedException()),
        AppMessage.sessionExpired,
      );
    });

    test('should report a cache error when local storage fails', () {
      expect(
        mapErrorToAppMessage(const CacheException('whatever')),
        AppMessage.cacheError,
      );
    });

    group('ServerException', () {
      const cases = <int, AppMessage>{
        400: AppMessage.badRequest,
        403: AppMessage.forbidden,
        404: AppMessage.notFound,
        409: AppMessage.conflict,
        429: AppMessage.tooManyRequests,
        500: AppMessage.serverError,
        502: AppMessage.serverError,
        503: AppMessage.serverError,
      };

      for (final entry in cases.entries) {
        test('should map HTTP ${entry.key} to ${entry.value}', () {
          expect(
            mapErrorToAppMessage(
              ServerException('anything', statusCode: entry.key),
            ),
            entry.value,
          );
        });
      }

      test('should fall back to unknown when the status is unmapped', () {
        expect(
          mapErrorToAppMessage(ServerException('teapot', statusCode: 418)),
          AppMessage.unknownError,
        );
      });

      test('should fall back to unknown when there is no status code', () {
        expect(
          mapErrorToAppMessage(const ServerException('boom')),
          AppMessage.unknownError,
        );
      });

      test('should ignore the exception body entirely', () {
        // The mapper dispatches on type and status only; it has never read
        // `message`, and now it could not return it even if it did.
        const leaky =
            'PostgresError: column "users.secret_internal_field" does not exist';
        expect(
          mapErrorToAppMessage(ServerException(leaky, statusCode: 500)),
          AppMessage.serverError,
        );
      });
    });

    group('unknown errors', () {
      test('should fall back to unknown for a plain Exception', () {
        final err = Exception('http://10.0.2.2:4455/internal-host-leak');
        expect(mapErrorToAppMessage(err), AppMessage.unknownError);
      });

      test('should fall back to unknown for a StateError', () {
        expect(
          mapErrorToAppMessage(StateError('bad state')),
          AppMessage.unknownError,
        );
      });

      test('should fall back to unknown for a thrown String', () {
        expect(mapErrorToAppMessage('just a string'), AppMessage.unknownError);
      });
    });
  });
}
