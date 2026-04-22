import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/domain/entities/sale.dart';
import 'package:dokonpro/presentation/blocs/sales/sales_history_bloc.dart';
import 'package:dokonpro/presentation/blocs/sales/sales_history_event.dart';
import 'package:dokonpro/presentation/blocs/sales/sales_history_state.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/pages/sales/refund_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockSalesHistoryBloc
    extends MockBloc<SalesHistoryEvent, SalesHistoryState>
    implements SalesHistoryBloc {}

Sale _fakeSale() => Sale(
      id: 'test-sale-id',
      storeId: 'test-store-id',
      receiptNo: '#0001',
      subtotal: 100.0,
      total: 100.0,
      paymentType: 'CASH',
      paidAmount: 100.0,
      status: 'COMPLETED',
      createdAt: DateTime(2026, 1, 15, 10, 30),
    );

void main() {
  late MockStoreBloc storeBloc;
  late MockSalesHistoryBloc salesHistoryBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    salesHistoryBloc = MockSalesHistoryBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => salesHistoryBloc.state).thenReturn(SalesHistoryInitial());
  });

  Widget page() => RefundPage(sale: _fakeSale());

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<SalesHistoryBloc>.value(value: salesHistoryBloc),
        ],
        child: child,
      );

  group('RefundPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'refund_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'refund_dark');
    });
  });
}
