// Regression coverage for #24: navigating to stock-intake from a product's
// detail page passes the product via GoRouterState.extra. StockIntakePage
// previously ignored it, always starting at the search step even when the
// caller already knew which product to receive stock for.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/product.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_event.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_state.dart';
import 'package:dukonpro/presentation/blocs/stock/stock_intake_bloc.dart';
import 'package:dukonpro/presentation/blocs/stock/stock_intake_event.dart';
import 'package:dukonpro/presentation/blocs/stock/stock_intake_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/stock/stock_intake_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockStockIntakeBloc extends MockBloc<StockIntakeEvent, StockIntakeState>
    implements StockIntakeBloc {}

class MockProductListBloc extends MockBloc<ProductListEvent, ProductListState>
    implements ProductListBloc {}

void main() {
  Product mkProduct({String id = 'prod-1'}) => Product(
        id: id,
        storeId: 'store-1',
        name: 'Preselected Product',
        costPrice: 7.5,
        sellPrice: 15,
        quantity: 4,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  setUpAll(() {
    registerFallbackValue(StockIntakeReset());
  });

  late MockStoreBloc storeBloc;
  late MockStockIntakeBloc stockBloc;
  late MockProductListBloc productListBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    stockBloc = MockStockIntakeBloc();
    productListBloc = MockProductListBloc();

    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => productListBloc.state).thenReturn(ProductListInitial());
  });

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<StockIntakeBloc>.value(value: stockBloc),
          BlocProvider<ProductListBloc>.value(value: productListBloc),
        ],
        child: child,
      );

  group('StockIntakePage product preselection (#24)', () {
    testWidgets(
        'dispatches StockIntakeSelectProduct on init when a product is '
        'passed via the constructor', (tester) async {
      final product = mkProduct();
      when(() => stockBloc.state).thenReturn(const StockIntakeState());

      await pumpPageWithTheme(
        tester,
        StockIntakePage(product: product),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );

      final captured = verify(() => stockBloc.add(captureAny(
            that: isA<StockIntakeSelectProduct>(),
          ))).captured;
      expect(captured, hasLength(1));
      final event = captured.single as StockIntakeSelectProduct;
      expect(event.product.id, product.id);
    });

    testWidgets(
        'renders the intake form immediately (skipping search) when the '
        'bloc already holds the preselected product', (tester) async {
      final product = mkProduct();
      when(() => stockBloc.state).thenReturn(
        StockIntakeState(selectedProduct: product, unitCost: product.costPrice ?? 0),
      );

      await pumpPageWithTheme(
        tester,
        StockIntakePage(product: product),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );

      // Intake form is visible for the preselected product...
      expect(find.text(product.name), findsOneWidget);
      expect(find.text('Количество'), findsOneWidget);
      // ...and the search-first empty state never shows.
      expect(find.text('Найдите товар для оформления прихода'), findsNothing);

      // The unit-cost field is pre-filled from the passed-in product, same
      // as when a product is picked via search (see _buildProductItem).
      final unitCostField = tester.widget<TextField>(find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Введите себестоимость',
      ));
      expect(unitCostField.controller?.text, product.costPrice.toString());
    });

    testWidgets(
        'does not dispatch StockIntakeSelectProduct and stays on the search '
        'step when no product is passed (e.g. from the supplier screen)',
        (tester) async {
      when(() => stockBloc.state).thenReturn(const StockIntakeState());

      await pumpPageWithTheme(
        tester,
        const StockIntakePage(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );

      verifyNever(() => stockBloc.add(any(that: isA<StockIntakeSelectProduct>())));
      expect(find.text('Найдите товар для оформления прихода'), findsOneWidget);
    });
  });
}
