import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_bloc.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_event.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_state.dart';
import 'package:dokonpro/presentation/blocs/stock/stock_intake_bloc.dart';
import 'package:dokonpro/presentation/blocs/stock/stock_intake_event.dart';
import 'package:dokonpro/presentation/blocs/stock/stock_intake_state.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/pages/stock/stock_intake_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockStockIntakeBloc extends MockBloc<StockIntakeEvent, StockIntakeState>
    implements StockIntakeBloc {}

class MockProductListBloc
    extends MockBloc<ProductListEvent, ProductListState>
    implements ProductListBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockStockIntakeBloc stockBloc;
  late MockProductListBloc productListBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    stockBloc = MockStockIntakeBloc();
    productListBloc = MockProductListBloc();

    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => stockBloc.state).thenReturn(const StockIntakeState());
    when(() => productListBloc.state).thenReturn(ProductListInitial());
  });

  Widget page() => const StockIntakePage();

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<StockIntakeBloc>.value(value: stockBloc),
          BlocProvider<ProductListBloc>.value(value: productListBloc),
        ],
        child: child,
      );

  group('StockIntakePage goldens', () {
    testGoldens('light theme – empty state', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'stock_intake_light');
    });

    testGoldens('dark theme – empty state', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'stock_intake_dark');
    });
  });
}
