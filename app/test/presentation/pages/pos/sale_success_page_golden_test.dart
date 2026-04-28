import 'package:dio/dio.dart' show Options, RequestOptions, Response;
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/core/services/thermal_printer_service.dart';
import 'package:dukonpro/domain/entities/sale.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/pos/sale_success_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

// ── Fakes for sl<ThermalPrinterService> and sl<DioClient> ────────────────────

class _FakeThermalPrinterService extends Fake implements ThermalPrinterService {
  @override
  bool get isConnected => false;
}

class _FakeDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200);
}

// ── Deterministic Sale fixture ─────────────────────────────────────────────────

Sale _fakeSale() => Sale(
      id: 'sale-1',
      storeId: 'test-store-id',
      receiptNo: 'RCP-0001',
      subtotal: 1000,
      total: 1000,
      paymentType: 'CASH',
      paidAmount: 1200,
      change: 200,
      createdAt: DateTime(2024, 1, 1),
    );

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  late MockStoreBloc storeBloc;

  setUp(() {
    if (!sl.isRegistered<ThermalPrinterService>()) {
      sl.registerSingleton<ThermalPrinterService>(_FakeThermalPrinterService());
    }
    if (!sl.isRegistered<DioClient>()) {
      sl.registerSingleton<DioClient>(_FakeDioClient());
    }

    storeBloc = MockStoreBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
  });

  tearDown(() {
    if (sl.isRegistered<ThermalPrinterService>()) {
      sl.unregister<ThermalPrinterService>();
    }
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  Widget page() => SaleSuccessPage(sale: _fakeSale());

  Widget wrapWithBlocs(Widget child) => BlocProvider<StoreBloc>.value(
        value: storeBloc,
        child: child,
      );

  group('SaleSuccessPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'sale_success_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'sale_success_dark');
    });
  });
}
