// Regression coverage for SPEC.md #12: a failed refund used to reset
// isRefunding and leave the cashier staring at a screen that gave no
// indication anything went wrong (no error, no pop, nothing). This exercises
// the fix: a failed refund now surfaces AppSnackbar.error(...) and leaves the
// RefundPage on screen, while a successful refund still shows the success
// snackbar and pops — proving the two paths are distinguishable.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/sale.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/sales/sales_history_bloc.dart';
import 'package:dukonpro/presentation/blocs/sales/sales_history_event.dart';
import 'package:dukonpro/presentation/blocs/sales/sales_history_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/sales/refund_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

class MockSalesHistoryBloc extends MockBloc<SalesHistoryEvent, SalesHistoryState>
    implements SalesHistoryBloc {}

Sale _fakeSale({String status = 'COMPLETED'}) => Sale(
      id: 'test-sale-id',
      storeId: 'test-store-id',
      receiptNo: '#0001',
      subtotal: 100.0,
      total: 100.0,
      paymentType: 'CASH',
      paidAmount: 100.0,
      status: status,
      createdAt: DateTime(2026, 1, 15, 10, 30),
    );

void main() {
  late MockStoreBloc storeBloc;
  late MockSalesHistoryBloc salesHistoryBloc;
  late StreamController<SalesHistoryState> stateController;

  setUp(() {
    storeBloc = MockStoreBloc();
    salesHistoryBloc = MockSalesHistoryBloc();
    stateController = StreamController<SalesHistoryState>.broadcast();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
  });

  tearDown(() async {
    await stateController.close();
    await salesHistoryBloc.close();
  });

  Future<void> pumpApp(WidgetTester tester, Sale sale) async {
    final router = GoRouter(
      initialLocation: '/sales',
      routes: [
        GoRoute(
          path: '/sales',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Sales history')),
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.push('/sales/refund'),
                child: const Text('Open refund'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/sales/refund',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<StoreBloc>.value(value: storeBloc),
              BlocProvider<SalesHistoryBloc>.value(value: salesHistoryBloc),
            ],
            child: RefundPage(sale: sale),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open refund'));
    await tester.pumpAndSettle();
    expect(find.byType(RefundPage), findsOneWidget);
  }

  testWidgets(
      'shows AppSnackbar.error and does NOT pop the screen when a refund '
      'fails (SPEC.md #12)', (tester) async {
    final sale = _fakeSale();
    final loaded = SalesHistoryLoaded(sales: [sale], total: 1, totalPages: 1);
    whenListen<SalesHistoryState>(
      salesHistoryBloc,
      stateController.stream,
      initialState: loaded,
    );

    await pumpApp(tester, sale);

    // Simulate the bloc's own isRefunding:true -> failure transition, as
    // _onRefundSale now does on a repository error.
    stateController.add(loaded.copyWith(isRefunding: true, clearRefundError: true));
    await tester.pump();
    stateController.add(loaded.copyWith(
      isRefunding: false,
      refundError: 'Нет подключения к интернету',
    ));
    await tester.pump();

    expect(find.text('Нет подключения к интернету'), findsOneWidget);
    // The failure path must NOT pop: RefundPage is still the visible screen.
    expect(find.byType(RefundPage), findsOneWidget);
    expect(find.text('Open refund'), findsNothing);
  });

  testWidgets(
      'shows the success snackbar and pops the screen when a refund '
      'succeeds', (tester) async {
    final sale = _fakeSale();
    final loaded = SalesHistoryLoaded(sales: [sale], total: 1, totalPages: 1);
    whenListen<SalesHistoryState>(
      salesHistoryBloc,
      stateController.stream,
      initialState: loaded,
    );

    await pumpApp(tester, sale);

    final refundedSale = Sale(
      id: sale.id,
      storeId: sale.storeId,
      receiptNo: sale.receiptNo,
      subtotal: sale.subtotal,
      total: 0,
      paymentType: sale.paymentType,
      paidAmount: sale.paidAmount,
      status: 'RETURNED',
      createdAt: sale.createdAt,
    );

    stateController.add(loaded.copyWith(isRefunding: true, clearRefundError: true));
    await tester.pump();
    stateController.add(loaded.copyWith(
      sales: [refundedSale],
      isRefunding: false,
      clearRefundError: true,
    ));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.text('Open refund')))!;
    expect(find.text(l10n.snackRefundSuccess), findsOneWidget);
    // The success path pops back to the previous screen.
    expect(find.byType(RefundPage), findsNothing);
    expect(find.text('Open refund'), findsOneWidget);
  });
}
