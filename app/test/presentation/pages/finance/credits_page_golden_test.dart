import 'package:dio/dio.dart' show Options, RequestOptions, Response;
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/finance/credits_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:intl/intl.dart';
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
    // Field names mirror /finances/credits-summary exactly. The fixture used
    // to say `total`/`items`, which the endpoint has never sent — so this test
    // passed while the screen itself rendered an empty list against real data.
    sl.registerSingleton<DioClient>(_FakeDioClientWithData({
      'receivables': {
        'totalAmount': 1500,
        'count': 3,
        'customers': [
          {
            'id': 'c1',
            'name': 'Иван Иванов',
            'phone': '+992900000001',
            'debt': 500,
            'lastPayment': '2026-01-15T12:00:00.000Z',
          },
        ],
      },
      'payables': {
        'totalAmount': 800,
        'count': 2,
        'suppliers': <Map<String, dynamic>>[],
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

    // Assert the VALUES, not only the labels. Reading `total` instead of
    // `totalAmount` renders "0 TJS" under an unchanged "Общий долг нам" — half
    // of the reported defect — and a label-only assertion stays green through
    // it, which is exactly how the old fixture hid the bug.
    // Formatted the way the page formats it — the ru locale groups with a
    // non-breaking space, so a literal '1 500' would not match.
    final money = NumberFormat('#,##0', 'ru');
    expect(find.text('${money.format(1500)} TJS'), findsOneWidget,
        reason: 'the receivables total must come from totalAmount');
    // Only the active tab is built, so the payables total is not on screen.
  });
}
