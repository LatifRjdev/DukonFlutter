import 'package:dio/dio.dart' show Options, RequestOptions, Response;
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/finance/reports_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

// ── Fake DioClient — always throws so page renders deterministic error/loading state ──
//
// ReportsPage assigns `sl<DioClient>()` as a field in _ReportsPageState,
// so the fake MUST be registered before the widget is built.

class _FakeDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      throw Exception('network unavailable');

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200);
}

// ── Fake DioClient — returns a realistic GET /reports/sales response body ──
//
// Used by the non-golden content test below to prove _loadSales() actually
// parses the real backend response shape (byDate/topProducts/channelBreakdown)
// and that the parsed data reaches the rendered widget tree. The golden tests
// above intentionally never exercise this path since they always throw.

class _FakeSuccessDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path.contains('/reports/sales')) {
      final body = {
        'byDate': [
          {'date': '2026-08-01', 'count': 5, 'revenue': 1500, 'avgCheck': 300},
        ],
        'topProducts': [
          {
            'productId': 'p1',
            'productName': 'Хлеб',
            'totalQty': 10,
            'totalRevenue': 900,
          },
        ],
        'channelBreakdown': [
          {'channel': 'IN_STORE', 'revenue': 1800, 'count': 6},
          {'channel': 'ONLINE', 'revenue': 600, 'count': 2},
        ],
      };
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: body as T,
      );
    }
    return Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200);
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockStoreBloc storeBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());

    // Must register before widget creation because ReportsPage reads sl<DioClient>
    // at field-initialisation time inside _ReportsPageState.
    if (!sl.isRegistered<DioClient>()) {
      sl.registerSingleton<DioClient>(_FakeDioClient());
    }
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  Widget page() => const ReportsPage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) => BlocProvider<StoreBloc>.value(
        value: storeBloc,
        child: child,
      );

  group('ReportsPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'reports_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'reports_dark');
    });
  });

  // ── Non-golden content test ──────────────────────────────────────────────
  //
  // Regression coverage for the _loadSales() key-mismatch bug (it used to
  // read body['rows']/body['top5'], which the backend never sends — see
  // ReportsService.getSalesReport(), which returns byDate/topProducts/
  // channelBreakdown). The golden tests above always hit a throwing fake
  // DioClient by design, so they can never catch a regression back to that
  // bug or to the "В магазине"/"Онлайн" channel-split row. This test swaps
  // in a fake that returns the real response shape and asserts the parsed
  // values actually render.
  testWidgets(
    'sales tab renders real byDate/topProducts/channelBreakdown data',
    (tester) async {
      sl.unregister<DioClient>();
      sl.registerSingleton<DioClient>(_FakeSuccessDioClient());

      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();

      // Sales table row parsed from byDate.
      expect(find.textContaining('2026-08-01'), findsOneWidget);

      // Top-5 product name parsed from topProducts[].productName.
      expect(find.textContaining('Хлеб'), findsOneWidget);

      // Channel-split row: labels appear twice (once in the channel filter
      // chips, once in the new _KpiCard row) once real data is loaded.
      expect(find.text('В магазине'), findsNWidgets(2));
      expect(find.text('Онлайн'), findsNWidgets(2));

      // Values formatted with the same fmtPrice logic the page uses
      // (NumberFormat('#,##0', 'ru') + ' TJS'), computed here rather than
      // hard-coded so the assertion doesn't depend on guessing the exact
      // thousands-separator character the 'ru' locale renders.
      String fmtPrice(num v) => '${NumberFormat('#,##0', 'ru').format(v)} TJS';
      expect(find.text(fmtPrice(1800)), findsOneWidget);
      expect(find.text(fmtPrice(600)), findsOneWidget);
    },
  );
}
