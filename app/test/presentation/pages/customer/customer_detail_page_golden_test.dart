import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/customer_detail/customer_detail_bloc.dart';
import 'package:dukonpro/presentation/blocs/customer_detail/customer_detail_event.dart';
import 'package:dukonpro/presentation/blocs/customer_detail/customer_detail_state.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_bloc.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_event.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_state.dart';
import 'package:dukonpro/presentation/pages/customer/customer_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class MockCustomerDetailBloc
    extends MockBloc<CustomerDetailEvent, CustomerDetailState>
    implements CustomerDetailBloc {}

class MockCartBloc extends MockBloc<CartEvent, CartState>
    implements CartBloc {}

void main() {
  late MockCustomerDetailBloc customerDetailBloc;
  late MockCartBloc cartBloc;

  setUp(() {
    customerDetailBloc = MockCustomerDetailBloc();
    cartBloc = MockCartBloc();
    when(() => customerDetailBloc.state).thenReturn(CustomerDetailInitial());
    when(() => cartBloc.state).thenReturn(const CartState());
  });

  Widget page() => const CustomerDetailPage(
        customerId: 'test-customer-id',
        storeId: 'test-store-id',
      );

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<CustomerDetailBloc>.value(value: customerDetailBloc),
          BlocProvider<CartBloc>.value(value: cartBloc),
        ],
        child: child,
      );

  group('CustomerDetailPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'customer_detail_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'customer_detail_dark');
    });
  });
}
