import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_bloc.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_event.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_state.dart';
import 'package:dukonpro/presentation/blocs/pos/checkout_bloc.dart';
import 'package:dukonpro/presentation/blocs/pos/checkout_event.dart';
import 'package:dukonpro/presentation/blocs/pos/checkout_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/pos/cash_payment_page.dart';
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

void main() {
  late MockStoreBloc storeBloc;
  late MockCartBloc cartBloc;
  late MockCheckoutBloc checkoutBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    cartBloc = MockCartBloc();
    checkoutBloc = MockCheckoutBloc();

    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => cartBloc.state).thenReturn(
      const CartState(
        items: [
          CartItem(
            productId: 'prod-1',
            productName: 'Молоко',
            unitPrice: 12.50,
            quantity: 2,
          ),
        ],
      ),
    );
    when(() => checkoutBloc.state).thenReturn(
      const CheckoutState(total: 25.0, paidAmount: 25.0),
    );
  });

  Widget page() => const CashPaymentPage();

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<CartBloc>.value(value: cartBloc),
          BlocProvider<CheckoutBloc>.value(value: checkoutBloc),
        ],
        child: child,
      );

  group('CashPaymentPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'cash_payment_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'cash_payment_dark');
    });
  });
}
