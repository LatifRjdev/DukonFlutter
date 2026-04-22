import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/l10n/app_localizations.dart';
import 'package:dokonpro/presentation/blocs/pos/cart_bloc.dart';
import 'package:dokonpro/presentation/blocs/pos/cart_event.dart';
import 'package:dokonpro/presentation/blocs/pos/cart_state.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_bloc.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_event.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_state.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/pages/product/product_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

class MockCartBloc extends MockBloc<CartEvent, CartState>
    implements CartBloc {}

class MockProductListBloc extends MockBloc<ProductListEvent, ProductListState>
    implements ProductListBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockCartBloc cartBloc;
  late MockProductListBloc productListBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    cartBloc = MockCartBloc();
    productListBloc = MockProductListBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => cartBloc.state).thenReturn(const CartState());
    when(() => productListBloc.state).thenReturn(ProductListInitial());
  });

  // ProductDetailPage reads GoRouterState.extra. Without a product passed as
  // extra the page renders its "Товар не найден" fallback — a valid golden for
  // regression-testing theme-aware scaffold / appBar colours.
  Future<void> pumpWithRouter(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/products/test-product-id',
      routes: [
        GoRoute(
          path: '/products/:id',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<StoreBloc>.value(value: storeBloc),
              BlocProvider<CartBloc>.value(value: cartBloc),
              BlocProvider<ProductListBloc>.value(value: productListBloc),
            ],
            child: ProductDetailPage(
              productId: state.pathParameters['id']!,
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ProductDetailPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpWithRouter(tester, Brightness.light);
      await screenMatchesGolden(tester, 'product_detail_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWithRouter(tester, Brightness.dark);
      await screenMatchesGolden(tester, 'product_detail_dark');
    });
  });
}
