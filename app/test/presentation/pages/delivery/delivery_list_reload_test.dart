// Regression test for SPEC.md #30: after successfully creating a new
// delivery, DeliveryListPage did not refresh, so the newly-created delivery
// only appeared after manually navigating away and back. CreateDeliveryPage
// now pops with `true` on success, and DeliveryListPage's FAB awaits the
// push result and reloads the list when it's `true` — mirroring the pattern
// already used by AddInvestmentPage/InvestmentListPage.
import 'package:dio/dio.dart' show Options, Response, RequestOptions;
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/core/router/route_names.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/pages/delivery/create_delivery_page.dart';
import 'package:dukonpro/presentation/pages/delivery/delivery_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ── Fake DioClient ──────────────────────────────────────────────────────────
//
// Tracks how many times the deliveries list is fetched, and returns an empty
// list on the first call, then a single delivery on subsequent calls — so
// tests can tell whether the list cubit reloaded, not just whether the page
// re-rendered.
class _FakeDioClient extends Fake implements DioClient {
  int deliveriesGetCallCount = 0;

  static final _createdDelivery = {
    'id': 'd1',
    'orderNumber': '#1001',
    'customerName': 'Иван Иванов',
    'address': 'ул. Рудаки, 10',
    'amount': 250,
    'status': 'NEW',
    'createdAt': DateTime(2026, 1, 1).toIso8601String(),
  };

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path.endsWith('/deliveries')) {
      deliveriesGetCallCount++;
      final data = deliveriesGetCallCount == 1
          ? <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[_createdDelivery];
      return Response<T>(
        data: data as T,
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
      );
    }
    if (path.endsWith('/sales')) {
      return Response<T>(
        data: <Map<String, dynamic>>[
          {'id': 's1', 'orderNumber': '#S1'},
        ] as T,
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
      );
    }
    if (path.endsWith('/staff')) {
      return Response<T>(
        data: <Map<String, dynamic>>[
          {'id': 'c1', 'firstName': 'Курьер', 'lastName': 'Курьеров'},
        ] as T,
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
      );
    }
    throw Exception('unexpected GET $path');
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path.endsWith('/deliveries')) {
      return Response<T>(
        data: null,
        requestOptions: RequestOptions(path: path),
        statusCode: 201,
      );
    }
    throw Exception('unexpected POST $path');
  }
}

// ── Test setup ──────────────────────────────────────────────────────────────

void main() {
  late _FakeDioClient fakeDioClient;

  setUp(() {
    fakeDioClient = _FakeDioClient();
    if (sl.isRegistered<DioClient>()) sl.unregister<DioClient>();
    sl.registerSingleton<DioClient>(fakeDioClient);
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) sl.unregister<DioClient>();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: RouteNames.deliveryList,
      routes: [
        // Mirrors the real AppRouter builders for these two routes.
        GoRoute(
          path: RouteNames.deliveryList,
          builder: (context, state) =>
              const DeliveryListPage(storeId: 'test-store-id'),
        ),
        GoRoute(
          path: RouteNames.deliveryCreate,
          builder: (context, state) {
            final storeId = state.extra as String? ?? '';
            return CreateDeliveryPage(storeId: storeId);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> createDelivery(WidgetTester tester) async {
    final l10n =
        AppLocalizations.of(tester.element(find.byType(DeliveryListPage)))!;

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.byType(CreateDeliveryPage), findsOneWidget);

    // Address is the only field with a form validator.
    await tester.enterText(
      find.byType(TextFormField).first,
      'ул. Рудаки, 10',
    );

    // Sale dropdown.
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('#S1').last);
    await tester.pumpAndSettle();

    // Courier dropdown.
    await tester.tap(find.byType(DropdownButton<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Курьер Курьеров').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.createDeliveryButton));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'successfully creating a delivery pops with true and the list '
    'reloads to show the new delivery',
    (tester) async {
      await pumpApp(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(DeliveryListPage)),
      )!;
      expect(find.text(l10n.deliveryListEmptyState), findsOneWidget);
      expect(fakeDioClient.deliveriesGetCallCount, 1);

      await createDelivery(tester);

      // Back on the list, and it reloaded rather than showing stale (empty)
      // state.
      expect(find.byType(DeliveryListPage), findsOneWidget);
      expect(find.byType(CreateDeliveryPage), findsNothing);
      expect(fakeDioClient.deliveriesGetCallCount, 2);
      expect(find.text(l10n.deliveryListEmptyState), findsNothing);
      expect(find.text('#1001'), findsOneWidget);
    },
  );

  testWidgets(
    'backing out of create-delivery without submitting does not reload '
    'the list',
    (tester) async {
      await pumpApp(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(DeliveryListPage)),
      )!;
      expect(find.text(l10n.deliveryListEmptyState), findsOneWidget);
      expect(fakeDioClient.deliveriesGetCallCount, 1);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.byType(CreateDeliveryPage), findsOneWidget);

      // Cancel out via the default AppBar back button instead of submitting.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryListPage), findsOneWidget);
      // No second GET was made — the list did not blindly reload on every
      // return from the create screen, only when it popped with `true`.
      expect(fakeDioClient.deliveriesGetCallCount, 1);
      expect(find.text(l10n.deliveryListEmptyState), findsOneWidget);
    },
  );
}
