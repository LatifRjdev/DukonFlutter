import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_event.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_state.dart';
import 'package:dukonpro/presentation/blocs/customer_detail/customer_detail_bloc.dart';
import 'package:dukonpro/presentation/blocs/customer_detail/customer_detail_event.dart';
import 'package:dukonpro/presentation/blocs/customer_detail/customer_detail_state.dart';
import 'package:dukonpro/presentation/pages/customer/customer_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class MockCustomerListBloc
    extends MockBloc<CustomerListEvent, CustomerListState>
    implements CustomerListBloc {}

class MockCustomerDetailBloc
    extends MockBloc<CustomerDetailEvent, CustomerDetailState>
    implements CustomerDetailBloc {}

void main() {
  late MockCustomerListBloc customerListBloc;
  late MockCustomerDetailBloc customerDetailBloc;

  setUp(() {
    customerListBloc = MockCustomerListBloc();
    customerDetailBloc = MockCustomerDetailBloc();
    when(() => customerListBloc.state).thenReturn(CustomerListInitial());
    when(() => customerDetailBloc.state).thenReturn(CustomerDetailInitial());
  });

  Widget page() => const CustomerFormPage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<CustomerListBloc>.value(value: customerListBloc),
          BlocProvider<CustomerDetailBloc>.value(value: customerDetailBloc),
        ],
        child: child,
      );

  group('CustomerFormPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'customer_form_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'customer_form_dark');
    });
  });
}
