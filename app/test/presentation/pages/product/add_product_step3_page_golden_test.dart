import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/product/product_form_bloc.dart';
import 'package:dokonpro/presentation/blocs/product/product_form_event.dart';
import 'package:dokonpro/presentation/blocs/product/product_form_state.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_bloc.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_event.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_state.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/blocs/supplier/supplier_list_bloc.dart';
import 'package:dokonpro/presentation/blocs/supplier/supplier_list_event.dart';
import 'package:dokonpro/presentation/blocs/supplier/supplier_list_state.dart';
import 'package:dokonpro/presentation/pages/product/add_product_step3_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockProductFormBloc extends MockBloc<ProductFormEvent, ProductFormState>
    implements ProductFormBloc {}

class MockProductListBloc extends MockBloc<ProductListEvent, ProductListState>
    implements ProductListBloc {}

class MockSupplierListBloc
    extends MockBloc<SupplierListEvent, SupplierListState>
    implements SupplierListBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockProductFormBloc productFormBloc;
  late MockProductListBloc productListBloc;
  late MockSupplierListBloc supplierListBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    productFormBloc = MockProductFormBloc();
    productListBloc = MockProductListBloc();
    supplierListBloc = MockSupplierListBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => productFormBloc.state).thenReturn(const ProductFormState());
    when(() => productListBloc.state).thenReturn(ProductListInitial());
    when(() => supplierListBloc.state).thenReturn(SupplierListInitial());
  });

  Widget page() => const AddProductStep3Page();

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<ProductFormBloc>.value(value: productFormBloc),
          BlocProvider<ProductListBloc>.value(value: productListBloc),
          BlocProvider<SupplierListBloc>.value(value: supplierListBloc),
        ],
        child: child,
      );

  group('AddProductStep3Page goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'add_product_step3_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'add_product_step3_dark');
    });
  });
}
