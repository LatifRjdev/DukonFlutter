import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/customer/customer_list_bloc.dart';
import 'package:dokonpro/presentation/blocs/customer/customer_list_event.dart';
import 'package:dokonpro/presentation/blocs/customer/customer_list_state.dart';
import 'package:dokonpro/presentation/blocs/pos/cart_bloc.dart';
import 'package:dokonpro/presentation/blocs/pos/cart_event.dart';
import 'package:dokonpro/presentation/blocs/pos/cart_state.dart';
import 'package:dokonpro/presentation/blocs/pos/checkout_bloc.dart';
import 'package:dokonpro/presentation/blocs/pos/checkout_event.dart';
import 'package:dokonpro/presentation/blocs/pos/checkout_state.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_bloc.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_event.dart';
import 'package:dokonpro/presentation/blocs/product/product_list_state.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/pages/pos/pos_checkout_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockCartBloc extends MockBloc<CartEvent, CartState> implements CartBloc {}

class MockCheckoutBloc extends MockBloc<CheckoutEvent, CheckoutState>
    implements CheckoutBloc {}

class MockProductListBloc extends MockBloc<ProductListEvent, ProductListState>
    implements ProductListBloc {}

class MockCustomerListBloc
    extends MockBloc<CustomerListEvent, CustomerListState>
    implements CustomerListBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockCartBloc cartBloc;
  late MockCheckoutBloc checkoutBloc;
  late MockProductListBloc productListBloc;
  late MockCustomerListBloc customerListBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    cartBloc = MockCartBloc();
    checkoutBloc = MockCheckoutBloc();
    productListBloc = MockProductListBloc();
    customerListBloc = MockCustomerListBloc();

    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => cartBloc.state).thenReturn(const CartState());
    when(() => checkoutBloc.state).thenReturn(const CheckoutState());
    when(() => productListBloc.state).thenReturn(ProductListInitial());
    when(() => customerListBloc.state).thenReturn(CustomerListInitial());
  });

  Widget page() => const PosCheckoutPage();

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<CartBloc>.value(value: cartBloc),
          BlocProvider<CheckoutBloc>.value(value: checkoutBloc),
          BlocProvider<ProductListBloc>.value(value: productListBloc),
          BlocProvider<CustomerListBloc>.value(value: customerListBloc),
        ],
        child: child,
      );

  group('PosCheckoutPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'pos_checkout_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'pos_checkout_dark');
    });
  });
}
