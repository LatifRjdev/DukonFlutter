import 'package:dio/dio.dart' show Options, RequestOptions, Response;
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/pages/inventory/inventory_count_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../../../helpers/golden_pump_helper.dart';

// ── Fake DioClient — always throws so page renders initial/error state ────────

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
      throw Exception('network unavailable');
}

// ── Fake DioClient — returns success responses so the cubit reaches the
//    counting/results states (used by the loaded-state content test below).

class _SuccessDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path.endsWith('/apply')) {
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
      );
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {'id': 'count-1'} as T,
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'items': [
          {'id': 'p1', 'name': 'Молоко 1л', 'expectedQty': 10},
          {'id': 'p2', 'name': 'Хлеб', 'expectedQty': 5},
        ],
      } as T,
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    if (!sl.isRegistered<DioClient>()) {
      sl.registerSingleton<DioClient>(_FakeDioClient());
    }
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  Widget page() => const InventoryCountPage(storeId: 'test-store-id');

  group('InventoryCountPage goldens', () {
    testGoldens('light theme – initial state', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'inventory_count_light');
    });

    testGoldens('dark theme – initial state', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'inventory_count_dark');
    });
  });

  // ── Non-golden content test ──────────────────────────────────────────────
  //
  // The goldens above only ever render the initial (_InvInitial) state, via
  // a DioClient stub that always throws, so they never render a loaded
  // count/results screen and can't catch an l10n key wired to the wrong call
  // site. This test drives the real cubit through start() then save() using
  // a DioClient stub that returns success responses, then asserts on several
  // of the extracted-string key decisions (both new and reused keys).
  //
  // Intentionally NOT calling tester.takeException() here (unlike the golden
  // tests above) — that call swallows exceptions thrown during pump, which
  // would let this test stay green even if the loaded states crashed.
  testWidgets('renders localized strings for a loaded inventory count',
      (tester) async {
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
    sl.registerSingleton<DioClient>(_SuccessDioClient());

    await pumpPageWithTheme(
      tester,
      page(),
      brightness: Brightness.light,
    );

    // Step 1 -> Step 2: start the count.
    await tester.tap(find.text('Начать инвентаризацию'));
    await tester.pumpAndSettle();

    expect(find.text('Подсчёт'), findsOneWidget); // new inventoryCountingTitle
    expect(find.text('Нажмите на строку для редактирования'),
        findsOneWidget); // new inventoryCountEditHint
    expect(find.text('Ожидается: 10'), findsOneWidget); // new inventoryExpectedLine
    expect(find.text('Сохранить'), findsOneWidget); // reused save

    // Step 2 -> Step 3: save the count.
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Результаты'), findsOneWidget); // new inventoryResultsTitle
    expect(find.text('Применить'), findsOneWidget); // new apply
  });
}
