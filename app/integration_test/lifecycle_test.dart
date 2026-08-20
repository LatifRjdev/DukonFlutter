// app/integration_test/lifecycle_test.dart
//
// App lifecycle integration tests. Replaces the brittle adb-tap
// scenarios in qa/2026-05-12-app-lifecycle/run.sh (Scenarios 1 & 2,
// inconclusive due to coordinate drift) with deterministic widget
// tests that simulate cold start with a pre-populated cart-persistence
// layer.
//
// What we are NOT doing here:
//   - Literally killing the OS process (not reachable from a Flutter
//     test harness).
//   - Exercising the full router + auth interceptor stack for the
//     token-revoke Scenario 6 — that path is better tested at the
//     AuthBloc layer. A skipped placeholder documents that.
//   - The 5-min background of Scenario 5 — that stays in run.sh.
//
// What we ARE doing:
//   - Seeding SharedPreferences with a cart payload that the real
//     CartLocalDatasource.load() will recognise (item count > 0;
//     the production `load()` returns null on empty carts).
//   - Registering a real CartLocalDatasource in the GetIt service
//     locator backed by that mocked prefs.
//   - Calling `CartRestorePrompt.showIfNeeded(context)` and verifying
//     the dialog appears with the expected Russian text + minute-ago
//     stamp; verifying "Очистить" clears persistence; verifying
//     "Восстановить" closes the dialog without leaving stray state.
//   - Verifying the negative case (no saved cart → no dialog).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dukonpro/data/datasources/local/cart_local_datasource.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_bloc.dart';
import 'package:dukonpro/presentation/pages/dashboard/cart_restore_prompt.dart';

/// Builds the JSON payload that production code wrote on save() so the
/// real CartLocalDatasource.load() will deserialise it. Mirrors the
/// shape in `app/lib/data/datasources/local/cart_local_datasource.dart`.
Map<String, dynamic> _cartPayload({int itemCount = 2}) {
  return {
    'items': List.generate(
      itemCount,
      (i) => {
        'productId': 'prod-$i',
        'productName': 'Товар $i',
        'unitPrice': 10.0,
        'costPrice': 5.0,
        'quantity': 1,
        'discount': 0.0,
        'unit': 'PCS',
      },
    ),
    'discount': 0.0,
    'discountType': 'FIXED',
    'customerId': null,
    'customerName': null,
  };
}

Future<void> _seedSavedCart({
  required int itemCount,
  Duration savedAgo = const Duration(minutes: 3),
}) async {
  SharedPreferences.setMockInitialValues({
    'pos.cart.v1': jsonEncode(_cartPayload(itemCount: itemCount)),
    'pos.cart.savedAt.v1':
        DateTime.now().subtract(savedAgo).millisecondsSinceEpoch,
  });
}

Future<void> _seedEmptyPrefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
}

Future<void> _registerCartDs() async {
  final prefs = await SharedPreferences.getInstance();
  final sl = GetIt.instance;
  if (sl.isRegistered<CartLocalDatasource>()) {
    sl.unregister<CartLocalDatasource>();
  }
  sl.registerSingleton<CartLocalDatasource>(CartLocalDatasource(prefs));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CartRestorePrompt — D.1 Scenarios 1 & 2 migrated from adb-tap', () {
    late CartBloc cartBloc;

    setUp(() {
      CartRestorePrompt.resetForTest();
      cartBloc = CartBloc();
    });

    tearDown(() async {
      await cartBloc.close();
    });

    testWidgets(
        'Scenario 1: kill mid-cart — restore prompt appears with item count',
        (tester) async {
      await _seedSavedCart(itemCount: 2);
      await _registerCartDs();

      await tester.pumpWidget(_TestApp(cartBloc: cartBloc));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(_TestHomeStub));
      // ignore: unawaited_futures
      CartRestorePrompt.showIfNeeded(ctx);
      await tester.pumpAndSettle();

      expect(find.text('Восстановить корзину?'), findsOneWidget);
      expect(find.textContaining('2 товаров'), findsOneWidget);
      // savedAgo = 3 minutes → "3 мин назад"
      expect(find.textContaining('мин назад'), findsOneWidget);
    });

    testWidgets(
        'Scenario 2: kill mid-checkout — same prompt appears regardless of '
        'where in the flow the kill happened',
        (tester) async {
      // The prompt logic does not care WHERE the kill happened. What
      // matters: a non-empty saved cart exists at cold start. We seed
      // a 1-item cart (production refuses to persist empty carts, so
      // anything < 1 is unreachable in practice).
      await _seedSavedCart(itemCount: 1, savedAgo: Duration.zero);
      await _registerCartDs();

      await tester.pumpWidget(_TestApp(cartBloc: cartBloc));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(_TestHomeStub));
      // ignore: unawaited_futures
      CartRestorePrompt.showIfNeeded(ctx);
      await tester.pumpAndSettle();

      expect(find.text('Восстановить корзину?'), findsOneWidget);
      expect(find.textContaining('1 товаров'), findsOneWidget);
      // savedAgo = 0 → "только что"
      expect(find.textContaining('только что'), findsOneWidget);
    });

    testWidgets('No saved cart → prompt does NOT appear (negative case)',
        (tester) async {
      await _seedEmptyPrefs();
      await _registerCartDs();

      await tester.pumpWidget(_TestApp(cartBloc: cartBloc));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(_TestHomeStub));
      await CartRestorePrompt.showIfNeeded(ctx);
      await tester.pumpAndSettle();

      expect(find.text('Восстановить корзину?'), findsNothing);
    });

    testWidgets('Decline ("Очистить") clears the saved cart',
        (tester) async {
      await _seedSavedCart(itemCount: 2);
      await _registerCartDs();

      await tester.pumpWidget(_TestApp(cartBloc: cartBloc));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(_TestHomeStub));
      // ignore: unawaited_futures
      CartRestorePrompt.showIfNeeded(ctx);
      await tester.pumpAndSettle();

      expect(find.text('Восстановить корзину?'), findsOneWidget);

      await tester.tap(find.text('Очистить'));
      await tester.pumpAndSettle();

      // Dialog dismissed.
      expect(find.text('Восстановить корзину?'), findsNothing);
      // Persistence cleared — a subsequent cold start would see no
      // saved cart and therefore no prompt.
      final ds = GetIt.instance<CartLocalDatasource>();
      expect(ds.load(), isNull);
    });

    testWidgets(
        'Accept ("Восстановить") dispatches CartRestored and dismisses dialog',
        (tester) async {
      await _seedSavedCart(itemCount: 2);
      await _registerCartDs();

      await tester.pumpWidget(_TestApp(cartBloc: cartBloc));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(_TestHomeStub));
      // ignore: unawaited_futures
      CartRestorePrompt.showIfNeeded(ctx);
      await tester.pumpAndSettle();

      expect(find.text('Восстановить корзину?'), findsOneWidget);

      await tester.tap(find.text('Восстановить'));
      await tester.pumpAndSettle();

      // Dialog dismissed without throwing — CartRestored event flowed
      // through to the bloc. The bloc state now mirrors the persisted
      // cart (2 items, productId prod-0/prod-1).
      expect(find.text('Восстановить корзину?'), findsNothing);
      expect(cartBloc.state.items.length, 2);
      expect(cartBloc.state.items.first.productId, 'prod-0');
    });
  });

  // Scenario 6 (token revoked) needs the full router + Dio + auth
  // interceptor stack. Doing it at the integration_test layer is
  // brittle — it is better tested as a focused AuthBloc unit test
  // ("emits Unauthenticated on 401" + "router redirects on auth
  // state change"). Marking as pending so it shows up in test output.
  group('Token revoked → login redirect — D.1 Scenario 6', () {
    // Skipped: see app/test/presentation/blocs/auth_bloc_test.dart for
    // 401 → redirect coverage. Wiring the full router + Dio +
    // interceptor stack here would be brittle.
    testWidgets('placeholder — see auth_bloc_test.dart', (tester) async {
      // Intentionally empty.
    }, skip: true);
  });
}

/// Minimal host widget so the prompt has a BuildContext above a
/// Navigator (showDialog requires one) and a CartBloc to dispatch
/// CartRestored into.
class _TestApp extends StatelessWidget {
  const _TestApp({required this.cartBloc});
  final CartBloc cartBloc;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: BlocProvider<CartBloc>.value(
        value: cartBloc,
        child: const _TestHomeStub(),
      ),
    );
  }
}

class _TestHomeStub extends StatelessWidget {
  const _TestHomeStub();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.expand());
  }
}
