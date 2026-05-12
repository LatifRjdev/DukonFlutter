import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/data/datasources/local/cart_local_datasource.dart';
import 'package:dukonpro/data/sync/sync_engine.dart';
import 'package:dukonpro/data/sync/sync_queue.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/category/category_bloc.dart';
import 'package:dukonpro/presentation/blocs/category/category_event.dart';
import 'package:dukonpro/presentation/blocs/category/category_state.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_event.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_state.dart';
import 'package:dukonpro/presentation/blocs/dashboard/dashboard_bloc.dart';
import 'package:dukonpro/presentation/blocs/dashboard/dashboard_event.dart';
import 'package:dukonpro/presentation/blocs/dashboard/dashboard_state.dart';
import 'package:dukonpro/presentation/blocs/finance/finance_bloc.dart';
import 'package:dukonpro/presentation/blocs/finance/finance_event.dart';
import 'package:dukonpro/presentation/blocs/finance/finance_state.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_bloc.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_event.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_state.dart';
import 'package:dukonpro/presentation/blocs/pos/checkout_bloc.dart';
import 'package:dukonpro/presentation/blocs/pos/checkout_event.dart';
import 'package:dukonpro/presentation/blocs/pos/checkout_state.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_event.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/dashboard/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

// ── Bloc mocks ────────────────────────────────────────────────────────────────

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

class MockProductListBloc extends MockBloc<ProductListEvent, ProductListState>
    implements ProductListBloc {}

class MockCategoryBloc extends MockBloc<CategoryEvent, CategoryState>
    implements CategoryBloc {}

class MockCartBloc extends MockBloc<CartEvent, CartState>
    implements CartBloc {}

class MockCheckoutBloc extends MockBloc<CheckoutEvent, CheckoutState>
    implements CheckoutBloc {}

class MockFinanceBloc extends MockBloc<FinanceEvent, FinanceState>
    implements FinanceBloc {}

class MockCustomerListBloc
    extends MockBloc<CustomerListEvent, CustomerListState>
    implements CustomerListBloc {}

// ── GetIt fakes for OfflineBanner ─────────────────────────────────────────────

class _FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

class _FakeSyncEngine implements SyncEngine {
  @override
  Stream<SyncStatus> get syncStatus => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSyncQueue implements SyncQueue {
  @override
  Future<int> pendingCount() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake CartLocalDatasource that always reports "nothing saved" so the
/// CartRestorePrompt is a no-op in golden tests. Bypasses the real
/// constructor (which needs SharedPreferences) by extending and
/// overriding only the methods the prompt touches.
class _FakeCartLocalDatasource implements CartLocalDatasource {
  @override
  ({CartState state, DateTime savedAt})? load() => null;

  @override
  Future<void> save(CartState state) async {}

  @override
  Future<void> clear() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockStoreBloc storeBloc;
  late MockDashboardBloc dashboardBloc;
  late MockProductListBloc productListBloc;
  late MockCategoryBloc categoryBloc;
  late MockCartBloc cartBloc;
  late MockCheckoutBloc checkoutBloc;
  late MockFinanceBloc financeBloc;
  late MockCustomerListBloc customerListBloc;

  setUp(() {
    // Register GetIt fakes so OfflineBanner doesn't throw.
    if (!sl.isRegistered<NetworkInfo>()) {
      sl.registerSingleton<NetworkInfo>(_FakeNetworkInfo());
    }
    if (!sl.isRegistered<SyncEngine>()) {
      sl.registerSingleton<SyncEngine>(_FakeSyncEngine());
    }
    if (!sl.isRegistered<SyncQueue>()) {
      sl.registerSingleton<SyncQueue>(_FakeSyncQueue());
    }
    if (!sl.isRegistered<CartLocalDatasource>()) {
      sl.registerSingleton<CartLocalDatasource>(_FakeCartLocalDatasource());
    }

    storeBloc = MockStoreBloc();
    dashboardBloc = MockDashboardBloc();
    productListBloc = MockProductListBloc();
    categoryBloc = MockCategoryBloc();
    cartBloc = MockCartBloc();
    checkoutBloc = MockCheckoutBloc();
    financeBloc = MockFinanceBloc();
    customerListBloc = MockCustomerListBloc();

    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => dashboardBloc.state).thenReturn(DashboardInitial());
    when(() => productListBloc.state).thenReturn(ProductListInitial());
    when(() => categoryBloc.state).thenReturn(CategoryInitial());
    when(() => cartBloc.state).thenReturn(const CartState());
    when(() => checkoutBloc.state).thenReturn(const CheckoutState());
    when(() => financeBloc.state).thenReturn(FinanceInitial());
    when(() => customerListBloc.state).thenReturn(CustomerListInitial());
  });

  tearDown(() {
    if (sl.isRegistered<NetworkInfo>()) sl.unregister<NetworkInfo>();
    if (sl.isRegistered<SyncEngine>()) sl.unregister<SyncEngine>();
    if (sl.isRegistered<SyncQueue>()) sl.unregister<SyncQueue>();
    if (sl.isRegistered<CartLocalDatasource>()) {
      sl.unregister<CartLocalDatasource>();
    }
  });

  const page = HomePage();

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<DashboardBloc>.value(value: dashboardBloc),
          BlocProvider<ProductListBloc>.value(value: productListBloc),
          BlocProvider<CategoryBloc>.value(value: categoryBloc),
          BlocProvider<CartBloc>.value(value: cartBloc),
          BlocProvider<CheckoutBloc>.value(value: checkoutBloc),
          BlocProvider<FinanceBloc>.value(value: financeBloc),
          BlocProvider<CustomerListBloc>.value(value: customerListBloc),
        ],
        child: child,
      );

  Future<void> pumpHomePage(
    WidgetTester tester, {
    required Brightness brightness,
  }) async {
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: wrapWithBlocs(page),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('HomePage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpHomePage(tester, brightness: Brightness.light);
      await screenMatchesGolden(tester, 'home_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpHomePage(tester, brightness: Brightness.dark);
      await screenMatchesGolden(tester, 'home_dark');
    });
  });
}
