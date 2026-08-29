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
import 'package:dukonpro/presentation/blocs/subscription/subscription_bloc.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_event.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_state.dart';
import 'package:dukonpro/presentation/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _MockSubscriptionBloc
    extends MockBloc<SubscriptionEvent, SubscriptionState>
    implements SubscriptionBloc {}

SubscriptionLoaded _fakeNonPremiumSubscription() => SubscriptionLoaded(
      plan: 'BUSINESS',
      status: 'ACTIVE',
      limits: const SubscriptionLimits(
        maxStores: 3,
        maxProducts: 2000,
        maxStaff: 10,
        maxDiscounts: 5,
      ),
      features: const SubscriptionFeatures(
        hasReportsAll: true,
        hasExport: false,
        hasTelegram: true,
        hasAllPush: false,
        hasDelivery: true,
        hasInventory: true,
        hasEcommerceIntegration: false,
      ),
      payments: const [],
    );

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
  late _MockSubscriptionBloc subscriptionBloc;

  final fakeUser = User(
    id: 'test-user-id',
    phone: '+992900000000',
    name: 'Test User',
    isActive: true,
    createdAt: DateTime(2024, 1, 1),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authBloc = _MockAuthBloc();
    settingsBloc = _MockSettingsBloc();
    storeBloc = MockStoreBloc();
    subscriptionBloc = _MockSubscriptionBloc();

    when(() => authBloc.state).thenReturn(AuthInitial());
    when(() => settingsBloc.state).thenReturn(
      SettingsLoaded(fakeUser, themeMode: ThemeMode.light),
    );
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => subscriptionBloc.state)
        .thenReturn(_fakeNonPremiumSubscription());

    if (!sl.isRegistered<DioClient>()) {
      sl.registerSingleton<DioClient>(_FakeDioClient());
    }
  });

  tearDown(() {
    authBloc.close();
    settingsBloc.close();
    storeBloc.close();
    subscriptionBloc.close();
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<SubscriptionBloc>.value(value: subscriptionBloc),
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

    testGoldens('light theme — subscription still loading shows no PREMIUM badge',
        (tester) async {
      when(() => subscriptionBloc.state).thenReturn(SubscriptionInitial());
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'settings_subscription_loading_light');
    });
  });
}
