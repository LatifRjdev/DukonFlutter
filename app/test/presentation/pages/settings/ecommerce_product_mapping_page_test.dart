import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/pages/settings/ecommerce_product_mapping_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dioClient;

  Response<T> resp<T>(T body) => Response<T>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    dioClient = _MockDioClient();
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

  Widget wrap(Widget child) => MaterialApp(home: child);

  void stubHappyPath() {
    when(() => dioClient.get<dynamic>(
          '/stores/store-1/products',
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer(
      (_) async => resp<dynamic>({
        'data': [
          {'id': 'p1', 'name': 'Товар 1'},
          {'id': 'p2', 'name': 'Товар 2'},
        ],
        'total': 2,
      }),
    );
    when(() => dioClient.get<dynamic>('/stores/store-1/ecommerce/mappings'))
        .thenAnswer(
      (_) async => resp<dynamic>([
        {'productId': 'p1', 'externalProductId': 'ext-1'},
      ]),
    );
  }

  group('EcommerceProductMappingPage', () {
    testWidgets('shows a loading indicator while fetching', (tester) async {
      final completer = Completer<Response<dynamic>>();
      when(() => dioClient.get<dynamic>(
            '/stores/store-1/products',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) => completer.future);
      when(() => dioClient.get<dynamic>('/stores/store-1/ecommerce/mappings'))
          .thenAnswer((_) async => resp<dynamic>(<dynamic>[]));

      await tester.pumpWidget(
          wrap(const EcommerceProductMappingPage(storeId: 'store-1')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(resp<dynamic>({'data': <dynamic>[], 'total': 0}));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
        'lists products and pre-fills the external id from existing mappings',
        (tester) async {
      stubHappyPath();

      await tester.pumpWidget(
          wrap(const EcommerceProductMappingPage(storeId: 'store-1')));
      await tester.pumpAndSettle();

      expect(find.text('Товар 1'), findsOneWidget);
      expect(find.text('Товар 2'), findsOneWidget);
      expect(find.text('ext-1'), findsOneWidget);
    });

    testWidgets('tapping save sends a PUT with the entered external id',
        (tester) async {
      stubHappyPath();
      when(() => dioClient.put<dynamic>(
            '/stores/store-1/ecommerce/mappings/p2',
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp<dynamic>({
            'productId': 'p2',
            'externalProductId': 'ext-2',
          }));

      await tester.pumpWidget(
          wrap(const EcommerceProductMappingPage(storeId: 'store-1')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('mapping-external-id-p2')), 'ext-2');
      await tester.tap(find.byIcon(Icons.check).at(1));
      await tester.pumpAndSettle();

      final captured = verify(() => dioClient.put<dynamic>(
            '/stores/store-1/ecommerce/mappings/p2',
            data: captureAny(named: 'data'),
          )).captured.single as Map<String, dynamic>;
      expect(captured['externalProductId'], 'ext-2');
    });

    testWidgets('a failed save shows an error snackbar', (tester) async {
      stubHappyPath();
      when(() => dioClient.put<dynamic>(
            '/stores/store-1/ecommerce/mappings/p2',
            data: any(named: 'data'),
          )).thenThrow(Exception('network unavailable'));

      await tester.pumpWidget(
          wrap(const EcommerceProductMappingPage(storeId: 'store-1')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('mapping-external-id-p2')), 'ext-2');
      await tester.tap(find.byIcon(Icons.check).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Не удалось выполнить операцию'), findsOneWidget);
    });

    testWidgets('typing in the search field filters the product list by name',
        (tester) async {
      stubHappyPath();

      await tester.pumpWidget(
          wrap(const EcommerceProductMappingPage(storeId: 'store-1')));
      await tester.pumpAndSettle();

      expect(find.text('Товар 1'), findsOneWidget);
      expect(find.text('Товар 2'), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('mapping-search-field')), 'товар 1');
      await tester.pump();

      expect(find.text('Товар 1'), findsOneWidget);
      expect(find.text('Товар 2'), findsNothing);
    });

    testWidgets('clearing the search restores the full list', (tester) async {
      stubHappyPath();

      await tester.pumpWidget(
          wrap(const EcommerceProductMappingPage(storeId: 'store-1')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('mapping-search-field')), 'товар 1');
      await tester.pump();

      expect(find.text('Товар 1'), findsOneWidget);
      expect(find.text('Товар 2'), findsNothing);

      await tester.enterText(find.byKey(const Key('mapping-search-field')), '');
      await tester.pump();

      expect(find.text('Товар 1'), findsOneWidget);
      expect(find.text('Товар 2'), findsOneWidget);
    });

    testWidgets(
        'clear button on the search field restores the full unfiltered list',
        (tester) async {
      stubHappyPath();

      await tester.pumpWidget(
          wrap(const EcommerceProductMappingPage(storeId: 'store-1')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('mapping-search-field')), 'товар 1');
      await tester.pump();

      expect(find.text('Товар 1'), findsOneWidget);
      expect(find.text('Товар 2'), findsNothing);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.text('Товар 1'), findsOneWidget);
      expect(find.text('Товар 2'), findsOneWidget);
    });

    testWidgets('shows the empty search state when nothing matches',
        (tester) async {
      stubHappyPath();

      await tester.pumpWidget(
          wrap(const EcommerceProductMappingPage(storeId: 'store-1')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('mapping-search-field')), 'нет такого товара');
      await tester.pump();

      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(find.text('Товар 1'), findsNothing);
      expect(find.text('Товар 2'), findsNothing);
    });
  });
}
