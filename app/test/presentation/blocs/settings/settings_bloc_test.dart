import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/domain/entities/user.dart';
import 'package:dukonpro/presentation/blocs/settings/settings_bloc.dart';
import 'package:dukonpro/presentation/blocs/settings/settings_event.dart';
import 'package:dukonpro/presentation/blocs/settings/settings_state.dart';

class MockDioClient extends Mock implements DioClient {}

final _seedUser = User(
  id: 'u1',
  phone: '+992900000000',
  name: 'Alice',
  email: 'alice@example.com',
  createdAt: DateTime(2026, 1, 1),
);

Map<String, dynamic> _userJson({
  String id = 'u1',
  String phone = '+992900000000',
  String name = 'Alice',
  String? email = 'alice@example.com',
}) {
  return {
    'id': id,
    'phone': phone,
    'name': name,
    'email': email,
    'avatar': null,
    'isActive': true,
    'createdAt': '2026-01-01T00:00:00.000Z',
  };
}

Response<dynamic> _response(Map<String, dynamic> data, {String path = ''}) {
  return Response<dynamic>(
    data: data,
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
  );
}

void main() {
  late MockDioClient dioClient;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    dioClient = MockDioClient();
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsBloc', () {
    test('initial state is SettingsInitial', () {
      final bloc = SettingsBloc(dioClient: dioClient);
      expect(bloc.state, isA<SettingsInitial>());
    });

    group('SettingsProfileRequested', () {
      blocTest<SettingsBloc, SettingsState>(
        'emits [Loading, Loaded] with default (system) theme when no theme is persisted',
        setUp: () {
          when(() => dioClient.get(any()))
              .thenAnswer((_) async => _response(_userJson()));
        },
        build: () => SettingsBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(SettingsProfileRequested()),
        expect: () => [
          isA<SettingsLoading>(),
          predicate<SettingsState>((s) =>
              s is SettingsLoaded &&
              s.user.id == 'u1' &&
              s.user.name == 'Alice' &&
              s.themeMode == ThemeMode.system),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'emits Loaded with the previously persisted theme mode',
        setUp: () {
          SharedPreferences.setMockInitialValues({
            'theme_mode': ThemeMode.dark.index,
          });
          when(() => dioClient.get(any()))
              .thenAnswer((_) async => _response(_userJson()));
        },
        build: () => SettingsBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(SettingsProfileRequested()),
        expect: () => [
          isA<SettingsLoading>(),
          predicate<SettingsState>(
              (s) => s is SettingsLoaded && s.themeMode == ThemeMode.dark),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'emits [Loading, Error] with mapped message on NetworkException',
        setUp: () {
          when(() => dioClient.get(any())).thenThrow(const NetworkException());
        },
        build: () => SettingsBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(SettingsProfileRequested()),
        expect: () => [
          isA<SettingsLoading>(),
          const SettingsError('Нет подключения к интернету'),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'never leaks raw exception text into the error state',
        setUp: () {
          when(() => dioClient.get(any())).thenThrow(
            Exception('DioException [bad response]: http://10.0.2.2:4455/users/me'),
          );
        },
        build: () => SettingsBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(SettingsProfileRequested()),
        expect: () => [
          isA<SettingsLoading>(),
          predicate<SettingsState>((s) {
            if (s is! SettingsError) return false;
            return !s.message.contains('10.0.2.2') &&
                !s.message.contains('DioException') &&
                s.message.isNotEmpty;
          }),
        ],
      );
    });

    group('SettingsProfileUpdated', () {
      blocTest<SettingsBloc, SettingsState>(
        'emits [Loading, ActionSuccess, Loaded] with the updated user on success',
        setUp: () {
          when(() => dioClient.put(any(), data: any(named: 'data')))
              .thenAnswer((_) async => _response(_userJson(name: 'Bob')));
        },
        build: () => SettingsBloc(dioClient: dioClient),
        act: (bloc) =>
            bloc.add(const SettingsProfileUpdated(name: 'Bob')),
        expect: () => [
          isA<SettingsLoading>(),
          const SettingsActionSuccess('Профиль обновлён'),
          predicate<SettingsState>(
              (s) => s is SettingsLoaded && s.user.name == 'Bob'),
        ],
        verify: (_) {
          final captured = verify(
            () => dioClient.put(any(), data: captureAny(named: 'data')),
          ).captured;
          final payload = captured.single as Map<String, dynamic>;
          expect(payload['name'], 'Bob');
          expect(payload.containsKey('email'), isFalse);
        },
      );

      blocTest<SettingsBloc, SettingsState>(
        'emits [Loading, Error] on failure and does not emit ActionSuccess or Loaded',
        setUp: () {
          when(() => dioClient.put(any(), data: any(named: 'data')))
              .thenThrow(const ServerException('boom', statusCode: 500));
        },
        build: () => SettingsBloc(dioClient: dioClient),
        act: (bloc) =>
            bloc.add(const SettingsProfileUpdated(name: 'Bob')),
        expect: () => [
          isA<SettingsLoading>(),
          const SettingsError('Ошибка сервера — попробуйте позже'),
        ],
      );
    });

    group('SettingsPasswordChanged', () {
      blocTest<SettingsBloc, SettingsState>(
        'emits [Loading, ActionSuccess] on success',
        setUp: () {
          when(() => dioClient.put(any(), data: any(named: 'data')))
              .thenAnswer((_) async => _response(const {}));
        },
        build: () => SettingsBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SettingsPasswordChanged(
          currentPassword: 'old123',
          newPassword: 'new123',
        )),
        expect: () => [
          isA<SettingsLoading>(),
          const SettingsActionSuccess('Пароль изменён'),
        ],
        verify: (_) {
          final captured = verify(
            () => dioClient.put(any(), data: captureAny(named: 'data')),
          ).captured;
          final payload = captured.single as Map<String, dynamic>;
          expect(payload['currentPassword'], 'old123');
          expect(payload['newPassword'], 'new123');
        },
      );

      blocTest<SettingsBloc, SettingsState>(
        'emits [Loading, Error] with mapped message when the current password is rejected',
        setUp: () {
          when(() => dioClient.put(any(), data: any(named: 'data')))
              .thenThrow(const ServerException('bad', statusCode: 400));
        },
        build: () => SettingsBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SettingsPasswordChanged(
          currentPassword: 'wrong',
          newPassword: 'new123',
        )),
        expect: () => [
          isA<SettingsLoading>(),
          const SettingsError('Некорректные данные'),
        ],
      );
    });

    group('SettingsThemeChanged', () {
      blocTest<SettingsBloc, SettingsState>(
        'persists the theme and emits an updated Loaded state when a profile is already loaded',
        build: () => SettingsBloc(dioClient: dioClient),
        seed: () => SettingsLoaded(
          _seedUser,
          themeMode: ThemeMode.system,
        ),
        act: (bloc) => bloc.add(const SettingsThemeChanged(ThemeMode.dark)),
        expect: () => [
          predicate<SettingsState>(
              (s) => s is SettingsLoaded && s.themeMode == ThemeMode.dark),
        ],
        verify: (_) async {
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getInt('theme_mode'), ThemeMode.dark.index);
        },
      );

      blocTest<SettingsBloc, SettingsState>(
        'persists the theme but emits nothing when no profile is loaded yet',
        build: () => SettingsBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SettingsThemeChanged(ThemeMode.light)),
        expect: () => <SettingsState>[],
        verify: (_) async {
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getInt('theme_mode'), ThemeMode.light.index);
        },
      );
    });
  });
}
