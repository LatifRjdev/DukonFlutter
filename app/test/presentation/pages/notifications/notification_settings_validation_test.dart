// Behavioral coverage for SPEC.md #36 — the "days without sale" and
// "remaining %" threshold fields used to parse with int.tryParse and
// silently fall back to a default (30 / 50) on invalid input, so garbage
// text (or an empty field) never blocked Save — it just quietly saved a
// value the user never chose. These tests prove invalid input now blocks
// the save request entirely and shows a visible inline error.
import 'package:dio/dio.dart' show Options, RequestOptions, Response;
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/pages/notifications/notification_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/golden_pump_helper.dart';

class _FakeDioClient extends Fake implements DioClient {
  int putCallCount = 0;
  Map<String, dynamic>? lastPutData;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      throw Exception('network unavailable');

  @override
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    putCallCount++;
    lastPutData = data as Map<String, dynamic>?;
    return Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200);
  }
}

void main() {
  late _FakeDioClient fakeDio;

  setUp(() {
    fakeDio = _FakeDioClient();
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
    sl.registerSingleton<DioClient>(fakeDio);
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  Widget page() => const NotificationSettingsPage(storeId: 'test-store-id');

  Future<void> pumpLoaded(WidgetTester tester) async {
    // The GET always throws, so the page settles into its loaded-with-
    // in-memory-defaults state (catch block sets _loading = false) without
    // needing to mock a successful load response. The page body is a
    // scrollable ListView; a tall surface keeps every field AND the Save
    // button simultaneously mounted, so scrolling the button into view
    // never unmounts the threshold fields (and their error text) above it.
    await pumpPageWithTheme(
      tester,
      page(),
      brightness: Brightness.light,
      size: const Size(390, 1600),
    );
  }

  Future<void> tapSave(WidgetTester tester) async {
    final saveButton = find.widgetWithText(ElevatedButton, 'Сохранить');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
  }

  // The load call always fails in these tests, so both threshold fields
  // start out genuinely empty (the catch path never populates the
  // controllers) rather than pre-filled with the 30/50 in-memory defaults.
  // Seed both with valid values first so a test that then overrides just
  // one field for an invalid case doesn't also trip the *other* field's
  // "empty" validation error alongside it.
  Future<void> seedValidBaseline(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Дней без продаж'), '30');
    await tester.enterText(find.widgetWithText(TextFormField, 'Остаток, % от партии'), '50');
  }

  group('NotificationSettingsPage numeric threshold validation (SPEC.md #36)', () {
    testWidgets('non-numeric text in the days field blocks save and shows an error',
        (tester) async {
      await pumpLoaded(tester);
      await seedValidBaseline(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Дней без продаж'), 'abc');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text('Неверный формат'), findsOneWidget);
      expect(fakeDio.putCallCount, 0);
    });

    testWidgets('a percent value over 100 blocks save and shows a range error',
        (tester) async {
      await pumpLoaded(tester);
      await seedValidBaseline(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Остаток, % от партии'), '150');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text('От 0 до 100'), findsOneWidget);
      expect(fakeDio.putCallCount, 0);
    });

    testWidgets('an empty days field blocks save (threshold is required, unlike loyalty\'s optional fields)',
        (tester) async {
      await pumpLoaded(tester);
      await seedValidBaseline(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Дней без продаж'), '');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text('Неверный формат'), findsOneWidget);
      expect(fakeDio.putCallCount, 0);
    });

    testWidgets('a zero days-threshold value blocks save (backend requires >= 1)',
        (tester) async {
      await pumpLoaded(tester);
      await seedValidBaseline(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Дней без продаж'), '0');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text('Некорректное значение'), findsOneWidget);
      expect(fakeDio.putCallCount, 0);
    });

    testWidgets('a zero percent-threshold value blocks save (backend requires >= 1)',
        (tester) async {
      await pumpLoaded(tester);
      await seedValidBaseline(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Остаток, % от партии'), '0');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text('От 0 до 100'), findsOneWidget);
      expect(fakeDio.putCallCount, 0);
    });

    testWidgets('valid numeric input for both fields is saved and reaches the PUT payload',
        (tester) async {
      await pumpLoaded(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Дней без продаж'), '45');
      await tester.enterText(find.widgetWithText(TextFormField, 'Остаток, % от партии'), '60');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(fakeDio.putCallCount, 1);
      expect(fakeDio.lastPutData?['daysWithoutSaleThreshold'], 45);
      expect(fakeDio.lastPutData?['remainingPercentThreshold'], 60);
    });
  });
}
