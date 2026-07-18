import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/data/datasources/local/auth_local_datasource.dart';
import 'package:dukonpro/data/datasources/remote/auth_remote_datasource.dart';
import 'package:dukonpro/data/repositories/auth_repository_impl.dart';
import 'package:dukonpro/domain/entities/user.dart';

class _MockAuthRemoteDatasource extends Mock implements AuthRemoteDatasource {}

class _MockAuthLocalDatasource extends Mock implements AuthLocalDatasource {}

void main() {
  late _MockAuthRemoteDatasource remote;
  late _MockAuthLocalDatasource local;
  late AuthRepositoryImpl repo;

  final testUser = User(
    id: 'u1',
    phone: '+992900000000',
    name: 'Test User',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  final authResult = (
    user: testUser,
    accessToken: 'access-tok',
    refreshToken: 'refresh-tok',
  );

  setUpAll(() {
    registerFallbackValue(testUser);
  });

  setUp(() {
    remote = _MockAuthRemoteDatasource();
    local = _MockAuthLocalDatasource();
    repo = AuthRepositoryImpl(remoteDatasource: remote, localDatasource: local);

    when(() => local.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((_) async {});
    when(() => local.saveUser(any())).thenAnswer((_) async {});
    when(() => local.deleteTokens()).thenAnswer((_) async {});
    when(() => local.deleteUser()).thenAnswer((_) async {});
  });

  group('register', () {
    test('saves tokens and user locally and returns the remote result',
        () async {
      when(() => remote.register(
            phone: any(named: 'phone'),
            password: any(named: 'password'),
            name: any(named: 'name'),
            email: any(named: 'email'),
          )).thenAnswer((_) async => authResult);

      final result = await repo.register(
        phone: '+992900000000',
        password: 'StrongPass99',
        name: 'Test User',
      );

      expect(result, authResult);
      verify(() => local.saveTokens(
            accessToken: 'access-tok',
            refreshToken: 'refresh-tok',
          )).called(1);
      verify(() => local.saveUser(testUser)).called(1);
    });

    test('propagates the remote exception and never touches local storage',
        () async {
      when(() => remote.register(
            phone: any(named: 'phone'),
            password: any(named: 'password'),
            name: any(named: 'name'),
            email: any(named: 'email'),
          )).thenThrow(const ServerException('registration failed'));

      await expectLater(
        () => repo.register(
          phone: '+992900000000',
          password: 'StrongPass99',
          name: 'Test User',
        ),
        throwsA(isA<ServerException>()),
      );

      verifyNever(() => local.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ));
      verifyNever(() => local.saveUser(any()));
    });
  });

  group('login', () {
    test('saves tokens and user locally and returns the remote result',
        () async {
      when(() => remote.login(
            phone: any(named: 'phone'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => authResult);

      final result = await repo.login(
        phone: '+992900000000',
        password: 'StrongPass99',
      );

      expect(result, authResult);
      verify(() => local.saveTokens(
            accessToken: 'access-tok',
            refreshToken: 'refresh-tok',
          )).called(1);
      verify(() => local.saveUser(testUser)).called(1);
    });

    test('propagates UnauthorizedException without saving anything locally',
        () async {
      when(() => remote.login(
            phone: any(named: 'phone'),
            password: any(named: 'password'),
          )).thenThrow(const UnauthorizedException('Invalid credentials'));

      await expectLater(
        () => repo.login(phone: '+992900000000', password: 'wrong'),
        throwsA(isA<UnauthorizedException>()),
      );

      verifyNever(() => local.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ));
      verifyNever(() => local.saveUser(any()));
    });

    test('propagates NetworkException when offline', () async {
      when(() => remote.login(
            phone: any(named: 'phone'),
            password: any(named: 'password'),
          )).thenThrow(const NetworkException());

      expect(
        () => repo.login(phone: '+992900000000', password: 'StrongPass99'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('refreshToken', () {
    test('saves the new tokens locally (but not a user) and returns them',
        () async {
      final tokens = (accessToken: 'new-access', refreshToken: 'new-refresh');
      when(() => remote.refreshToken(any())).thenAnswer((_) async => tokens);

      final result = await repo.refreshToken('old-refresh');

      expect(result, tokens);
      verify(() => local.saveTokens(
            accessToken: 'new-access',
            refreshToken: 'new-refresh',
          )).called(1);
      verifyNever(() => local.saveUser(any()));
    });

    test('forwards the given token to the remote datasource', () async {
      when(() => remote.refreshToken(any())).thenAnswer(
        (_) async => (accessToken: 'a', refreshToken: 'r'),
      );

      await repo.refreshToken('the-refresh-token');

      verify(() => remote.refreshToken('the-refresh-token')).called(1);
    });

    test('propagates UnauthorizedException when the refresh token is dead',
        () async {
      when(() => remote.refreshToken(any()))
          .thenThrow(const UnauthorizedException('Refresh token expired'));

      expect(
        () => repo.refreshToken('dead-token'),
        throwsA(isA<UnauthorizedException>()),
      );
      verifyNever(() => local.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ));
    });
  });

  group('logout', () {
    test('clears local tokens and user after a successful remote logout',
        () async {
      when(() => remote.logout()).thenAnswer((_) async {});

      await repo.logout();

      verify(() => remote.logout()).called(1);
      verify(() => local.deleteTokens()).called(1);
      verify(() => local.deleteUser()).called(1);
    });

    test('still clears local state when the remote logout call fails',
        () async {
      when(() => remote.logout()).thenThrow(const NetworkException());

      await repo.logout();

      verify(() => local.deleteTokens()).called(1);
      verify(() => local.deleteUser()).called(1);
    });

    test('does not rethrow when the remote logout call fails', () async {
      when(() => remote.logout()).thenThrow(const ServerException('boom'));

      await expectLater(repo.logout(), completes);
    });
  });

  group('isAuthenticated', () {
    test('delegates to local.hasTokens', () async {
      when(() => local.hasTokens()).thenAnswer((_) async => true);

      expect(await repo.isAuthenticated(), isTrue);
      verify(() => local.hasTokens()).called(1);
    });

    test('returns false when no tokens are cached', () async {
      when(() => local.hasTokens()).thenAnswer((_) async => false);

      expect(await repo.isAuthenticated(), isFalse);
    });
  });

  group('getAccessToken', () {
    test('delegates to local.getAccessToken', () async {
      when(() => local.getAccessToken()).thenAnswer((_) async => 'cached-token');

      expect(await repo.getAccessToken(), 'cached-token');
    });

    test('returns null when nothing is cached', () async {
      when(() => local.getAccessToken()).thenAnswer((_) async => null);

      expect(await repo.getAccessToken(), isNull);
    });
  });

  group('getCurrentUser', () {
    test('delegates to local.getUser', () async {
      when(() => local.getUser()).thenAnswer((_) async => testUser);

      expect(await repo.getCurrentUser(), testUser);
    });

    test('returns null when no user is cached', () async {
      when(() => local.getUser()).thenAnswer((_) async => null);

      expect(await repo.getCurrentUser(), isNull);
    });
  });

  group('verifyToken', () {
    test('refreshes the cached user and returns it on success', () async {
      when(() => remote.verifyToken()).thenAnswer((_) async => testUser);

      final result = await repo.verifyToken();

      expect(result, testUser);
      verify(() => local.saveUser(testUser)).called(1);
    });

    test('does not touch the local cache when the server rejects the token',
        () async {
      when(() => remote.verifyToken())
          .thenThrow(const UnauthorizedException('token revoked'));

      await expectLater(
        () => repo.verifyToken(),
        throwsA(isA<UnauthorizedException>()),
      );

      verifyNever(() => local.saveUser(any()));
    });
  });

  group('sendOtp', () {
    test('delegates to remote.sendOtp with the given phone', () async {
      when(() => remote.sendOtp(any())).thenAnswer((_) async {});

      await repo.sendOtp('+992900000000');

      verify(() => remote.sendOtp('+992900000000')).called(1);
    });

    test('propagates errors from the remote datasource', () async {
      when(() => remote.sendOtp(any()))
          .thenThrow(const ServerException('rate limited', statusCode: 429));

      expect(
        () => repo.sendOtp('+992900000000'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('verifyOtp', () {
    test('saves tokens and user locally and returns the remote result',
        () async {
      when(() => remote.verifyOtp(any(), any()))
          .thenAnswer((_) async => authResult);

      final result = await repo.verifyOtp('+992900000000', '123456');

      expect(result, authResult);
      verify(() => local.saveTokens(
            accessToken: 'access-tok',
            refreshToken: 'refresh-tok',
          )).called(1);
      verify(() => local.saveUser(testUser)).called(1);
    });

    test('propagates the failure and saves nothing on an invalid code',
        () async {
      when(() => remote.verifyOtp(any(), any()))
          .thenThrow(const ServerException('Invalid or expired code'));

      await expectLater(
        () => repo.verifyOtp('+992900000000', '000000'),
        throwsA(isA<ServerException>()),
      );

      verifyNever(() => local.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ));
      verifyNever(() => local.saveUser(any()));
    });
  });

  group('forgotPassword', () {
    test('delegates to remote.forgotPassword with the given phone', () async {
      when(() => remote.forgotPassword(any())).thenAnswer((_) async {});

      await repo.forgotPassword('+992900000000');

      verify(() => remote.forgotPassword('+992900000000')).called(1);
    });
  });

  group('resetPassword', () {
    test('delegates to remote.resetPassword with phone, code and new password',
        () async {
      when(() => remote.resetPassword(any(), any(), any()))
          .thenAnswer((_) async {});

      await repo.resetPassword('+992900000000', '123456', 'NewStrongPass1');

      verify(() => remote.resetPassword(
            '+992900000000',
            '123456',
            'NewStrongPass1',
          )).called(1);
    });

    test('propagates errors for an invalid reset code', () async {
      when(() => remote.resetPassword(any(), any(), any()))
          .thenThrow(const ServerException('Invalid code'));

      expect(
        () => repo.resetPassword('+992900000000', 'bad', 'NewStrongPass1'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
