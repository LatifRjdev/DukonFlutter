import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dokonpro/core/errors/exceptions.dart';
import 'package:dokonpro/domain/entities/user.dart';
import 'package:dokonpro/domain/repositories/auth_repository.dart';
import 'package:dokonpro/presentation/blocs/auth/auth_bloc.dart';
import 'package:dokonpro/presentation/blocs/auth/auth_event.dart';
import 'package:dokonpro/presentation/blocs/auth/auth_state.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

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
    repository = MockAuthRepository();
  });

  group('AuthBloc', () {
    test('initial state is AuthInitial', () {
      expect(
        AuthBloc(authRepository: repository).state,
        isA<AuthInitial>(),
      );
    });

    group('AuthCheckRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits AuthAuthenticated when repository says authenticated + user loaded',
        setUp: () {
          when(() => repository.isAuthenticated()).thenAnswer((_) async => true);
          when(() => repository.getCurrentUser()).thenAnswer((_) async => testUser);
        },
        build: () => AuthBloc(authRepository: repository),
        act: (bloc) => bloc.add(AuthCheckRequested()),
        expect: () => [AuthAuthenticated(testUser)],
      );

      blocTest<AuthBloc, AuthState>(
        'emits AuthUnauthenticated when isAuthenticated = false',
        setUp: () {
          when(() => repository.isAuthenticated()).thenAnswer((_) async => false);
        },
        build: () => AuthBloc(authRepository: repository),
        act: (bloc) => bloc.add(AuthCheckRequested()),
        expect: () => [isA<AuthUnauthenticated>()],
      );

      blocTest<AuthBloc, AuthState>(
        'emits AuthUnauthenticated when isAuthenticated=true but getCurrentUser=null',
        setUp: () {
          when(() => repository.isAuthenticated()).thenAnswer((_) async => true);
          when(() => repository.getCurrentUser()).thenAnswer((_) async => null);
        },
        build: () => AuthBloc(authRepository: repository),
        act: (bloc) => bloc.add(AuthCheckRequested()),
        expect: () => [isA<AuthUnauthenticated>()],
      );
    });

    group('AuthLoginRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthAuthenticated] on success',
        setUp: () {
          when(() => repository.login(
                phone: '+992900000000',
                password: 'StrongPass99',
              )).thenAnswer((_) async => loginResult);
        },
        build: () => AuthBloc(authRepository: repository),
        act: (bloc) => bloc.add(const AuthLoginRequested(
          phone: '+992900000000',
          password: 'StrongPass99',
        )),
        expect: () => [AuthLoading(), AuthAuthenticated(testUser)],
      );

      blocTest<AuthBloc, AuthState>(
        'emits AuthFailure with session-expired text on UnauthorizedException',
        setUp: () {
          when(() => repository.login(
                phone: any(named: 'phone'),
                password: any(named: 'password'),
              )).thenThrow(const UnauthorizedException());
        },
        build: () => AuthBloc(authRepository: repository),
        act: (bloc) => bloc.add(const AuthLoginRequested(
          phone: '+992900000000',
          password: 'wrong',
        )),
        expect: () => [
          AuthLoading(),
          const AuthFailure('Сессия истекла. Войдите снова.'),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits AuthFailure with offline message on NetworkException',
        setUp: () {
          when(() => repository.login(
                phone: any(named: 'phone'),
                password: any(named: 'password'),
              )).thenThrow(const NetworkException());
        },
        build: () => AuthBloc(authRepository: repository),
        act: (bloc) => bloc.add(const AuthLoginRequested(
          phone: '+992900000000',
          password: 'StrongPass99',
        )),
        expect: () => [
          AuthLoading(),
          const AuthFailure('Нет подключения к интернету'),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'never leaks raw exception text (FE-P1-002 regression)',
        setUp: () {
          when(() => repository.login(
                phone: any(named: 'phone'),
                password: any(named: 'password'),
              )).thenThrow(Exception('http://10.0.2.2:4455/internal-host'));
        },
        build: () => AuthBloc(authRepository: repository),
        act: (bloc) => bloc.add(const AuthLoginRequested(
          phone: '+992900000000',
          password: 'StrongPass99',
        )),
        expect: () => [
          AuthLoading(),
          predicate<AuthState>((s) {
            if (s is! AuthFailure) return false;
            return !s.message.contains('10.0.2.2') &&
                !s.message.contains('http://');
          }, 'AuthFailure without internal host in message'),
        ],
      );
    });

    group('AuthRegisterRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthAuthenticated] on success',
        setUp: () {
          when(() => repository.register(
                phone: any(named: 'phone'),
                password: any(named: 'password'),
                name: any(named: 'name'),
                email: any(named: 'email'),
              )).thenAnswer((_) async => loginResult);
        },
        build: () => AuthBloc(authRepository: repository),
        act: (bloc) => bloc.add(const AuthRegisterRequested(
          phone: '+992900000000',
          password: 'StrongPass99',
          name: 'Test',
        )),
        expect: () => [AuthLoading(), AuthAuthenticated(testUser)],
      );
    });

    group('AuthLogoutRequested', () {
      blocTest<AuthBloc, AuthState>(
        'calls repository.logout and emits AuthUnauthenticated',
        setUp: () {
          when(() => repository.logout()).thenAnswer((_) async {});
        },
        build: () => AuthBloc(authRepository: repository),
        act: (bloc) => bloc.add(AuthLogoutRequested()),
        expect: () => [isA<AuthUnauthenticated>()],
        verify: (_) {
          verify(() => repository.logout()).called(1);
        },
      );
    });
  });
}
