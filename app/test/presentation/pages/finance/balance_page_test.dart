import 'package:dio/dio.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/finance/balance_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

// Regression test for the 2026-09-21 manual QA finding: "Текущий баланс"
// always showed 0 TJS even with a positive "Прибыль" on the same screen,
// and "Транзакций нет" contradicted a non-empty "Динамика" chart.
// Root cause: FinancesService.getBalance() (api/) returns
// {currentBalance, recentTransactions: [{type: 'SALE'|'EXPENSE', label,
// ...}]}, but _BalanceData.fromJson read the non-existent 'balance' and
// 'transactions' keys (silently defaulting to 0 / []), and
// _Transaction.fromJson read a non-existent 'description' key instead of
// 'label' and compared the uppercase backend `type` against a lowercase
// literal. This test uses the real backend response shape end-to-end.
class _FakeRealisticDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final body = {
      'currentBalance': 240,
      'income': 240,
      'expenses': 0,
      'profit': 240,
      'chartData': [
        {'date': '2026-09-07', 'income': 160, 'expenses': 0},
        {'date': '2026-09-15', 'income': 80, 'expenses': 0},
      ],
      'recentTransactions': [
        {
          'type': 'SALE',
          'id': 'sale-1',
          'amount': 80,
          'label': 'Sale #R-000002',
          'date': '2026-09-15T00:00:00.000Z',
        },
      ],
    };
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: body as T,
    );
  }
}

void main() {
  late MockStoreBloc storeBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());

    if (sl.isRegistered<DioClient>()) sl.unregister<DioClient>();
    sl.registerSingleton<DioClient>(_FakeRealisticDioClient());
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) sl.unregister<DioClient>();
  });

  Widget page() => const BalancePage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) =>
      BlocProvider<StoreBloc>.value(value: storeBloc, child: child);

  testWidgets(
      'renders currentBalance and recentTransactions from the real API '
      'response shape, not 0 / empty', (tester) async {
    await pumpPageWithTheme(
      tester,
      page(),
      brightness: Brightness.light,
      wrap: wrapWithBlocs,
    );
    tester.takeException();

    // "Текущий баланс" reads currentBalance, not the non-existent
    // 'balance' key — was always "0 TJS" before the fix.
    expect(find.text('240 TJS'), findsWidgets);

    // recentTransactions rendered, not "Транзакций нет".
    expect(find.text('Sale #R-000002'), findsOneWidget);
    expect(find.text('Транзакций нет'), findsNothing);
  });
}
