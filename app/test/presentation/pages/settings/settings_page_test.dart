// Behavioral coverage for SPEC.md #13 — the settings hub used to render 5
// fields (role, Telegram status, language, sync status, subscription plan)
// as hardcoded strings regardless of the actual logged-in user/store state.
// These tests assert the real mocked-bloc values render instead, for the two
// fields with the clearest, easiest-to-mock data sources: role and
// subscription plan. See settings_page_golden_test.dart for the existing
// visual-regression coverage of this page.
import 'package:dio/dio.dart' show Options, Response;
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/domain/entities/store.dart';
import 'package:dukonpro/domain/entities/user.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_bloc.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_event.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_state.dart';
import 'package:dukonpro/presentation/blocs/settings/settings_bloc.dart';
import 'package:dukonpro/presentation/blocs/settings/settings_event.dart';
import 'package:dukonpro/presentation/blocs/settings/settings_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/blocs/store/store_event.dart';
import 'package:dukonpro/presentation/blocs/store/store_state.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_bloc.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_event.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_state.dart';
import 'package:dukonpro/presentation/pages/settings/settings_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _MockStoreBloc extends MockBloc<StoreEvent, StoreState>
    implements StoreBloc {}

class _MockSubscriptionBloc
    extends MockBloc<SubscriptionEvent, SubscriptionState>
    implements SubscriptionBloc {}

// Always throws — deterministic "network unavailable" fallback for the
// Telegram-bot-status and sync-status GET calls, same as the existing
// settings_page_golden_test.dart / telegram_bot_settings_page_golden_test.dart.
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

Store _store({required String ownerId}) => Store(
      id: 'store-1',
      ownerId: ownerId,
      name: 'Test Store',
      category: 'retail',
      currency: 'TJS',
      createdAt: DateTime(2024, 1, 1),
    );

SubscriptionLoaded _subscriptionLoaded({
  required String plan,
  DateTime? expiresAt,
}) =>
    SubscriptionLoaded(
      plan: plan,
      status: 'ACTIVE',
      expiresAt: expiresAt,
      limits: SubscriptionLimits.defaults(),
      features: SubscriptionFeatures.defaults(),
      payments: const [],
    );

void main() {
  late _MockAuthBloc authBloc;
  late _MockSettingsBloc settingsBloc;
  late _MockStoreBloc storeBloc;
  late _MockSubscriptionBloc subscriptionBloc;

  final user = User(
    id: 'user-1',
    phone: '+992900000001',
    name: 'Test User',
    isActive: true,
    createdAt: DateTime(2024, 1, 1),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authBloc = _MockAuthBloc();
    settingsBloc = _MockSettingsBloc();
    storeBloc = _MockStoreBloc();
    subscriptionBloc = _MockSubscriptionBloc();

    when(() => authBloc.state).thenReturn(AuthInitial());
    // SettingsPage's role lookup (#13 step 1) is triggered from a
    // BlocListener<SettingsBloc,...> reacting to a *stream* emission of
    // SettingsLoaded, not merely the bloc's already-current `.state`
    // (BlocListener never fires for a state that was already current when
    // the widget mounted). whenListen gives MockBloc a real stream so the
    // listener actually runs, matching how the real SettingsBloc transitions
    // from SettingsInitial -> SettingsLoading -> SettingsLoaded.
    final loadedSettings = SettingsLoaded(user, themeMode: ThemeMode.light);
    whenListen<SettingsState>(
      settingsBloc,
      Stream.value(loadedSettings),
      initialState: loadedSettings,
    );

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

  group('SettingsPage — role badge (#13 step 1)', () {
    testWidgets('shows the real owner label when the user owns the store',
        (tester) async {
      when(() => storeBloc.state).thenReturn(
        StoreLoaded(
          stores: [_store(ownerId: user.id)],
          selectedStore: _store(ownerId: user.id),
        ),
      );
      when(() => subscriptionBloc.state).thenReturn(SubscriptionInitial());

      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );

      expect(find.text('Владелец'), findsOneWidget);
    });

    testWidgets(
        'hides the badge instead of falsely showing the old hardcoded '
        'owner label for a non-owner whose role cannot be resolved',
        (tester) async {
      // Current user is NOT the store owner, and no StaffRepository is
      // registered in this test's service locator, so the staff-lookup
      // fallback in SettingsPage can't resolve a role either. The old
      // implementation always rendered "Владелец" regardless — this proves
      // the badge is now driven by real data, not a hardcoded string.
      when(() => storeBloc.state).thenReturn(
        StoreLoaded(
          stores: [_store(ownerId: 'someone-else')],
          selectedStore: _store(ownerId: 'someone-else'),
        ),
      );
      when(() => subscriptionBloc.state).thenReturn(SubscriptionInitial());

      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );

      expect(find.text('Владелец'), findsNothing);
    });
  });

  group('SettingsPage — subscription plan (#13 step 5)', () {
    testWidgets(
        'shows the real plan name and expiry date from SubscriptionBloc, '
        'not the hardcoded БИЗНЕС до 30.03.2026 string', (tester) async {
      when(() => storeBloc.state).thenReturn(
        StoreLoaded(
          stores: [_store(ownerId: user.id)],
          selectedStore: _store(ownerId: user.id),
        ),
      );
      when(() => subscriptionBloc.state).thenReturn(
        _subscriptionLoaded(plan: 'PREMIUM', expiresAt: DateTime(2027, 5, 10)),
      );

      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );

      // The subscription section sits below the fold — scroll the page's
      // ListView so it's actually built before asserting on its text.
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(find.text('Премиум до 10.05.2027'), findsOneWidget);
      expect(find.text('БИЗНЕС до 30.03.2026'), findsNothing);
    });
  });
}
