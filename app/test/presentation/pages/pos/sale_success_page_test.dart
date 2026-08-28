// Regression coverage for #2: CartCleared is a defined CartBloc event that
// was never dispatched anywhere, so the cart retained its prior contents
// indefinitely after a successful sale (risking accidental resubmission).
// SaleSuccessPage now dispatches CartCleared once, as soon as the sale
// success screen is reached — every payment path (cash, card, credit)
// routes through this page on success, so a single fix point covers all
// three.
import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart' show Options, RequestOptions, Response;
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/core/services/thermal_printer_service.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/domain/entities/product.dart';
import 'package:dukonpro/domain/entities/sale.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_bloc.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_event.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/pos/sale_success_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

class MockCartBloc extends MockBloc<CartEvent, CartState> implements CartBloc {}

class _FakeThermalPrinterService extends Fake implements ThermalPrinterService {
  @override
  bool get isConnected => false;
}

class _FakeDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200);
}

Sale _fakeSale() => Sale(
      id: 'sale-1',
      storeId: 'test-store-id',
      receiptNo: 'RCP-0001',
      subtotal: 1000,
      total: 1000,
      paymentType: 'CASH',
      paidAmount: 1200,
      change: 200,
      createdAt: DateTime(2024, 1, 1),
    );

Product _fakeProduct() => Product(
      id: 'prod-1',
      storeId: 'test-store-id',
      name: 'Test Product',
      sellPrice: 500,
      // CartBloc clamps CartItemAdded's quantity to Product.quantity
      // (SPEC.md #6) — Product defaults to 0 stock, which would silently
      // clamp this fixture's 3-unit pre-population to nothing. Give it
      // enough stock headroom to actually populate the cart.
      quantity: 10,
      createdAt: DateTime(2024, 1, 1),
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(CartCleared());
  });

  setUp(() {
    if (!sl.isRegistered<ThermalPrinterService>()) {
      sl.registerSingleton<ThermalPrinterService>(_FakeThermalPrinterService());
    }
    if (!sl.isRegistered<DioClient>()) {
      sl.registerSingleton<DioClient>(_FakeDioClient());
    }
  });

  tearDown(() {
    if (sl.isRegistered<ThermalPrinterService>()) {
      sl.unregister<ThermalPrinterService>();
    }
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  group('SaleSuccessPage dispatches CartCleared (mocked bloc) (#2)', () {
    late MockStoreBloc storeBloc;
    late MockCartBloc cartBloc;

    setUp(() {
      storeBloc = MockStoreBloc();
      cartBloc = MockCartBloc();
      when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
      when(() => cartBloc.state).thenReturn(const CartState());
    });

    Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
          providers: [
            BlocProvider<StoreBloc>.value(value: storeBloc),
            BlocProvider<CartBloc>.value(value: cartBloc),
          ],
          child: child,
        );

    testWidgets('dispatches CartCleared exactly once when the success screen '
        'is reached', (tester) async {
      await _pump(tester, wrapWithBlocs(SaleSuccessPage(sale: _fakeSale())));

      // pumpAndSettle above drives several build() calls while the
      // elasticOut checkmark animation plays; a called(1) here proves the
      // dispatch happened once (in initState), not on every rebuild.
      verify(() => cartBloc.add(any(that: isA<CartCleared>()))).called(1);
    });
  });

  group('SaleSuccessPage empties a populated cart end-to-end (real bloc) '
      '(#2)', () {
    late MockStoreBloc storeBloc;
    late CartBloc cartBloc;

    setUp(() {
      storeBloc = MockStoreBloc();
      when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
      cartBloc = CartBloc();
    });

    tearDown(() => cartBloc.close());

    Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
          providers: [
            BlocProvider<StoreBloc>.value(value: storeBloc),
            BlocProvider<CartBloc>.value(value: cartBloc),
          ],
          child: child,
        );

    testWidgets('cart is empty after the sale-success page settles',
        (tester) async {
      cartBloc.add(CartItemAdded(product: _fakeProduct(), quantity: 3));
      // AutomatedTestWidgetsFlutterBinding needs real async work bridged via
      // runAsync() before the first pumpWidget() call — awaiting the bloc's
      // stream directly here (or any bare Future) leaves the binding unable
      // to resolve the pumpWidget below.
      await tester.runAsync(
        () => cartBloc.stream.firstWhere((state) => !state.isEmpty),
      );
      expect(cartBloc.state.isEmpty, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: wrapWithBlocs(SaleSuccessPage(sale: _fakeSale())),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // Two more pumps to fully drive the 600ms elasticOut checkmark
      // animation to completion.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(cartBloc.state.isEmpty, isTrue);
      expect(cartBloc.state.items, isEmpty);
    });
  });
}
