import 'package:dio/dio.dart' show Options, RequestOptions, Response;
import 'package:dokonpro/core/network/dio_client.dart';
import 'package:dokonpro/injection.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/pages/finance/reports_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
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
}
