import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dokonpro/core/errors/exceptions.dart';
import 'package:dokonpro/domain/entities/user.dart';
import 'package:dokonpro/domain/repositories/auth_repository.dart';
import 'package:dokonpro/presentation/blocs/auth/auth_bloc.dart';
import 'package:dokonpro/presentation/blocs/auth/auth_event.dart';
import 'package:dokonpro/presentation/blocs/auth/auth_state.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;

  final testUser = User(
    id: 'u1',
    phone: '+992900000000',
    name: 'Test',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  final loginResult = (
    user: testUser,
    accessToken: 'access-tok',
    refreshToken: 'refresh-tok',
  );

  setUp(() {
    repository = _MockAuthRepository();
  });

  group('AuthBloc — extended coverage', () {
    blocTest<AuthBloc, AuthState>(
      'LoginRequested emits Loading -> Authenticated on success',
      setUp: () {
        when(() => repository.login(
              phone: '+992900000001',
              password: 'GoodPass1',
            )).thenAnswer((_) async => loginResult);
      },
      build: () => AuthBloc(authRepository: repository),
      act: (bloc) => bloc.add(const AuthLoginRequested(
        phone: '+992900000001',
        password: 'GoodPass1',
      )),
      expect: () => [AuthLoading(), AuthAuthenticated(testUser)],
      verify: (_) {
        verify(() => repository.login(
              phone: '+992900000001',
              password: 'GoodPass1',
            )).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'LoginRequested emits Loading -> Failure on 401 (UnauthorizedException)',
      setUp: () {
        when(() => repository.login(
              phone: any(named: 'phone'),
              password: any(named: 'password'),
            )).thenThrow(const UnauthorizedException());
      },
      build: () => AuthBloc(authRepository: repository),
      act: (bloc) => bloc.add(const AuthLoginRequested(
        phone: '+992900000001',
        password: 'wrong',
      )),
      expect: () => [
        AuthLoading(),
        const AuthFailure('Сессия истекла. Войдите снова.'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'RegisterRequested emits Loading -> Authenticated on success',
      setUp: () {
        when(() => repository.register(
              phone: '+992900000002',
              password: 'Password1',
              name: 'New User',
              email: null,
            )).thenAnswer((_) async => loginResult);
      },
      build: () => AuthBloc(authRepository: repository),
      act: (bloc) => bloc.add(const AuthRegisterRequested(
        phone: '+992900000002',
        password: 'Password1',
        name: 'New User',
      )),
      expect: () => [AuthLoading(), AuthAuthenticated(testUser)],
    );

    blocTest<AuthBloc, AuthState>(
      'RegisterRequested with duplicate phone emits Loading -> Failure',
      setUp: () {
        when(() => repository.register(
              phone: any(named: 'phone'),
              password: any(named: 'password'),
              name: any(named: 'name'),
              email: any(named: 'email'),
            )).thenThrow(const ServerException('phone already exists', statusCode: 409));
      },
      build: () => AuthBloc(authRepository: repository),
      act: (bloc) => bloc.add(const AuthRegisterRequested(
        phone: '+992900000003',
        password: 'Password1',
        name: 'Dup',
      )),
      expect: () => [
        AuthLoading(),
        // 409 maps to "Конфликт — объект уже существует" via mapErrorToUserMessage.
        const AuthFailure('Конфликт — объект уже существует'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'LogoutRequested emits Unauthenticated and clears tokens via repository',
      setUp: () {
        when(() => repository.logout()).thenAnswer((_) async {});
      },
      build: () => AuthBloc(authRepository: repository),
      act: (bloc) => bloc.add(AuthLogoutRequested()),
      expect: () => [isA<AuthUnauthenticated>()],
      verify: (_) {
        // The repository's logout() is the production path that wipes the
        // secure-storage token / refresh-token pair (FE-P0-002 regression).
        verify(() => repository.logout()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'AppStarted (AuthCheckRequested) emits Authenticated when valid token in secure storage',
      setUp: () {
        when(() => repository.isAuthenticated()).thenAnswer((_) async => true);
        when(() => repository.getCurrentUser()).thenAnswer((_) async => testUser);
      },
      build: () => AuthBloc(authRepository: repository),
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [AuthAuthenticated(testUser)],
    );

    blocTest<AuthBloc, AuthState>(
      'AppStarted (AuthCheckRequested) emits Unauthenticated when no token',
      setUp: () {
        when(() => repository.isAuthenticated()).thenAnswer((_) async => false);
      },
      build: () => AuthBloc(authRepository: repository),
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [isA<AuthUnauthenticated>()],
      verify: (_) {
        // We must NOT reach for the user when not authenticated — that
        // would be a wasted secure-storage / network roundtrip.
        verifyNever(() => repository.getCurrentUser());
      },
    );
  });
}
