// Regression coverage for SPEC.md #31: tapping delete on a discount used to
// delete it immediately with no confirmation step — a single accidental tap
// permanently destroyed data. This exercises the fix: a confirmation dialog
// (matching the shape already used for category deletion in
// categories_page.dart and product deletion in product_detail_page.dart)
// now gates the DELETE request.
import 'package:dio/dio.dart' show Options, Response, RequestOptions;
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/pages/settings/discounts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDioClient extends Fake implements DioClient {
  _FakeDioClient(this.discounts);

  final List<Map<String, dynamic>> discounts;
  int deleteCallCount = 0;
  String? lastDeletedPath;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: discounts as T,
    );
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Options? options,
  }) async {
    deleteCallCount++;
    lastDeletedPath = path;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }
}

void main() {
  late _FakeDioClient dioClient;

  final discount = {
    'id': 'disc-1',
    'name': 'Летняя скидка',
    'type': 'percent',
    'value': 10,
    'isActive': true,
  };

  setUp(() {
    dioClient = _FakeDioClient([discount]);
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
    sl.registerSingleton<DioClient>(dioClient);
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: const DiscountsPage(storeId: 'test-store-id'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'does not call DELETE until the confirm dialog\'s destructive button '
      'is tapped (SPEC.md #31)', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Удалить скидку?'), findsOneWidget);
    expect(dioClient.deleteCallCount, 0);
  });

  testWidgets(
      'calls DELETE with the right discount after the destructive button '
      'is tapped (SPEC.md #31)', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(dioClient.deleteCallCount, 1);
    expect(dioClient.lastDeletedPath, '/stores/test-store-id/discounts/disc-1');
  });

  testWidgets(
      'cancelling the confirm dialog closes it without calling DELETE '
      '(SPEC.md #31)', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(dioClient.deleteCallCount, 0);
  });
}
