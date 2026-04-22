import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/domain/entities/product.dart';
import 'package:dokonpro/presentation/blocs/category/category_bloc.dart';
import 'package:dokonpro/presentation/blocs/category/category_event.dart';
import 'package:dokonpro/presentation/blocs/category/category_state.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_bloc.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_event.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_state.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/pages/product/product_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockCategoryBloc extends MockBloc<CategoryEvent, CategoryState>
    implements CategoryBloc {}

class MockProductListBloc extends MockBloc<ProductListEvent, ProductListState>
    implements ProductListBloc {}

final _fakeProducts = [
  Product(
    id: 'prod-1',
    storeId: 'test-store-id',
    name: 'Молоко',
    sku: 'SKU-001',
    sellPrice: 12.50,
    costPrice: 8.00,
    quantity: 30,
    minQuantity: 5,
    unit: 'PCS',
    isActive: true,
    createdAt: DateTime(2024, 1, 1),
  ),
  Product(
    id: 'prod-2',
    storeId: 'test-store-id',
    name: 'Хлеб',
    sku: 'SKU-002',
    sellPrice: 5.00,
    costPrice: 3.00,
    quantity: 2,
    minQuantity: 5,
    unit: 'PCS',
    isActive: true,
    createdAt: DateTime(2024, 1, 2),
  ),
];

void main() {
  late MockStoreBloc storeBloc;
  late MockCategoryBloc categoryBloc;
  late MockProductListBloc productListBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    categoryBloc = MockCategoryBloc();
    productListBloc = MockProductListBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => categoryBloc.state).thenReturn(CategoryInitial());
    when(() => productListBloc.state).thenReturn(
      ProductListLoaded(
        products: _fakeProducts,
        total: _fakeProducts.length,
        totalPages: 1,
      ),
    );
  });

  Widget page() => const ProductListPage();

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<CategoryBloc>.value(value: categoryBloc),
          BlocProvider<ProductListBloc>.value(value: productListBloc),
        ],
        child: child,
      );

  group('ProductListPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'product_list_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'product_list_dark');
    });
  });
}
