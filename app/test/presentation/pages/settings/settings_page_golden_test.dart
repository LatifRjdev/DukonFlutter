import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart' show Options, Response;
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/domain/entities/user.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_bloc.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_event.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_state.dart';
import 'package:dukonpro/presentation/blocs/settings/settings_bloc.dart';
import 'package:dukonpro/presentation/blocs/settings/settings_event.dart';
import 'package:dukonpro/presentation/blocs/settings/settings_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _FakeDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      throw Exception('network unavailable');

  @override
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      throw Exception('network unavailable');
}

void main() {
  late _MockAuthBloc authBloc;
  late _MockSettingsBloc settingsBloc;
  late MockStoreBloc storeBloc;

  final fakeUser = User(
    id: 'test-user-id',
    phone: '+992900000000',
    name: 'Test User',
    isActive: true,
    createdAt: DateTime(2024, 1, 1),
  );

  setUp(() {
    authBloc = _MockAuthBloc();
    settingsBloc = _MockSettingsBloc();
    storeBloc = MockStoreBloc();

    when(() => authBloc.state).thenReturn(AuthInitial());
    when(() => settingsBloc.state).thenReturn(
      SettingsLoaded(fakeUser, themeMode: ThemeMode.light),
    );
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());

    if (!sl.isRegistered<DioClient>()) {
      sl.registerSingleton<DioClient>(_FakeDioClient());
    }
  });

  tearDown(() {
    authBloc.close();
    settingsBloc.close();
    storeBloc.close();
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<StoreBloc>.value(value: storeBloc),
        ],
        child: child,
      );

  Widget page() => const SettingsPage();

  group('SettingsPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'settings_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'settings_dark');
    });
  });
}
