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

// Task 5 gates the loyalty and ecommerce tiles on the catalog in
// availablePlans, not on a hardcoded tier, so an empty catalog can no longer
// stand in for "some feature is missing" — cheapestPlanWith([], ...) finds
// nothing to badge and PlanGate hides the upsell rather than naming a plan
// that doesn't exist. This mirrors the real seeded config referenced by Task
// 5 (zakat/loyalty/batch profitability/investments on BUSINESS, ecommerce on
// PREMIUM) so both gated tiles render their real badge: "Бизнес" on loyalty,
// "Премиум" on ecommerce. settings_light.png/settings_dark.png predate this
// — they were captured when the ecommerce badge was still the hardcoded
// literal "PREMIUM" and the loyalty tile had no badge at all, so both now
// mismatch pixel-for-pixel and need a human to regenerate them, same as the
// two SubscriptionPage goldens Task 4 left stale.
const _planCatalogFeatures = {
  'START': SubscriptionFeatures(
    hasReportsAll: false,
    hasExport: false,
    hasTelegram: false,
    hasAllPush: false,
    hasDelivery: false,
    hasInventory: false,
    hasZakat: false,
    hasInvestments: false,
    hasLoyalty: false,
    hasBatchProfitability: false,
    hasEcommerceIntegration: false,
  ),
  'BUSINESS': SubscriptionFeatures(
    hasReportsAll: true,
    hasExport: false,
    hasTelegram: true,
    hasAllPush: false,
    hasDelivery: true,
    hasInventory: true,
    hasZakat: true,
    hasInvestments: true,
    hasLoyalty: true,
    hasBatchProfitability: true,
    hasEcommerceIntegration: false,
  ),
  'PREMIUM': SubscriptionFeatures(
    hasReportsAll: true,
    hasExport: true,
    hasTelegram: true,
    hasAllPush: true,
    hasDelivery: true,
    hasInventory: true,
    hasZakat: true,
    hasInvestments: true,
    hasLoyalty: true,
    hasBatchProfitability: true,
    hasEcommerceIntegration: true,
  ),
};

final _fakeAvailablePlans = [
  SubscriptionPlanOption(
    plan: 'START',
    price: 200,
    listPrice: 200,
    maxProducts: 500,
    maxStaff: 2,
    maxDiscounts: 0,
    features: _planCatalogFeatures['START']!,
  ),
  SubscriptionPlanOption(
    plan: 'BUSINESS',
    price: 400,
    listPrice: 400,
    maxProducts: 2000,
    maxStaff: 10,
    maxDiscounts: 5,
    features: _planCatalogFeatures['BUSINESS']!,
  ),
  SubscriptionPlanOption(
    plan: 'PREMIUM',
    price: 600,
    listPrice: 600,
    maxProducts: -1,
    maxStaff: -1,
    maxDiscounts: -1,
    features: _planCatalogFeatures['PREMIUM']!,
  ),
];

SubscriptionLoaded _fakeNonPremiumSubscription() => SubscriptionLoaded(
  plan: 'BUSINESS',
  status: 'ACTIVE',
  limits: const SubscriptionLimits(
    maxProducts: 2000,
    maxStaff: 10,
    maxDiscounts: 5,
  ),
  // This merchant's OWN grant, deliberately missing loyalty and ecommerce —
  // distinct from _planCatalogFeatures above, which is what EVERY plan
  // offers, used only to resolve the cheapest upsell target.
  features: const SubscriptionFeatures(
    hasReportsAll: true,
    hasExport: false,
    hasTelegram: true,
    hasAllPush: false,
    hasDelivery: true,
    hasInventory: true,
    hasZakat: false,
    hasInvestments: false,
    hasLoyalty: false,
    hasBatchProfitability: false,
    hasEcommerceIntegration: false,
  ),
  payments: const [],
  availablePlans: _fakeAvailablePlans,
);

class _FakeDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async => throw Exception('network unavailable');

  @override
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async => throw Exception('network unavailable');
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
    when(
      () => settingsBloc.state,
    ).thenReturn(SettingsLoaded(fakeUser, themeMode: ThemeMode.light));
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(
      () => subscriptionBloc.state,
    ).thenReturn(_fakeNonPremiumSubscription());

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

    testGoldens(
      'light theme — subscription still loading shows no PREMIUM badge',
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
        await screenMatchesGolden(
          tester,
          'settings_subscription_loading_light',
        );
      },
    );
  });
}
