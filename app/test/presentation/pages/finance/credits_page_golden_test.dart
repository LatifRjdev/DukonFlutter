import 'package:dio/dio.dart' show Options, RequestOptions, Response;
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/finance/credits_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

// ── Fake DioClient — always throws so page renders deterministic error state ──

class _FakeDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      throw Exception('network unavailable');
}

// ── Fake DioClient — returns a fixed credits-summary payload ────────────────

class _FakeDioClientWithData extends Fake implements DioClient {
  final Map<String, dynamic> data;
  _FakeDioClientWithData(this.data);

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      Response<T>(
        data: data as T,
        requestOptions: RequestOptions(path: path),
      );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockStoreBloc storeBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());

    if (!sl.isRegistered<DioClient>()) {
      sl.registerSingleton<DioClient>(_FakeDioClient());
    }
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  Widget page() => const CreditsPage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) => BlocProvider<StoreBloc>.value(
        value: storeBloc,
        child: child,
      );

  group('CreditsPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'credits_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'credits_dark');
    });
  });

  // ── Non-golden content test ──────────────────────────────────────────────
  //
  // The goldens above only ever render the error state (the DioClient always
  // throws), so they never render the actual receivables/payables list and
  // can't catch an l10n key wired to the wrong call site. This test swaps in
  // a DioClient that returns a real credits-summary payload and asserts on
  // several of the extracted-string key decisions (both new and reused
  // keys).
  testWidgets('renders localized strings for a loaded credits summary',
      (tester) async {
    if (sl.isRegistered<DioClient>()) sl.unregister<DioClient>();
    sl.registerSingleton<DioClient>(_FakeDioClientWithData({
      'receivables': {
        'total': 1500,
        'count': 3,
        'items': [
          {
            'id': 'c1',
            'name': 'Иван Иванов',
            'phone': '+992900000001',
            'debt': 500,
            'lastPayment': '2026-01-15',
          },
        ],
      },
      'payables': {
        'total': 800,
        'count': 2,
        'items': <Map<String, dynamic>>[],
      },
    }));

    await pumpPageWithTheme(
      tester,
      page(),
      brightness: Brightness.light,
      wrap: wrapWithBlocs,
    );

    expect(find.text('Кредиты'), findsOneWidget); // new credits
    expect(find.text('Нам должны'), findsOneWidget); // reused theyOwe
    expect(find.text('Мы должны'), findsOneWidget); // reused weOwe
    expect(find.text('Общий долг нам'),
        findsOneWidget); // new creditsTotalReceivableLabel
    expect(find.text('3 чел.'), findsOneWidget); // new creditsPersonCountLabel
    expect(find.text('посл. 15.01.2026'),
        findsOneWidget); // new creditsLastPaymentLabel
  });
}
