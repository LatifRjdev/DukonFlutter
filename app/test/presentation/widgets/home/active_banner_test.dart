import 'package:dio/dio.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/widgets/home/active_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dioClient;

  Response<T> resp<T>(T body) => Response<T>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  setUp(() {
    dioClient = _MockDioClient();
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
    sl.registerSingleton<DioClient>(dioClient);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('ActiveBanner', () {
    testWidgets('shows the banner when the API returns one', (tester) async {
      when(() => dioClient.get<dynamic>('/stores/store-1/banners/active'))
          .thenAnswer(
        (_) async => resp<dynamic>({
          'id': 'banner-1',
          'title': 'Скидка 20%',
          'body': 'Только для PREMIUM',
        }),
      );

      await tester.pumpWidget(wrap(const ActiveBanner(storeId: 'store-1')));
      await tester.pumpAndSettle();

      expect(find.text('Скидка 20%'), findsOneWidget);
      expect(find.text('Только для PREMIUM'), findsOneWidget);
    });

    testWidgets('shows nothing when the API returns null', (tester) async {
      when(() => dioClient.get<dynamic>('/stores/store-1/banners/active'))
          .thenAnswer((_) async => resp<dynamic>(null));

      await tester.pumpWidget(wrap(const ActiveBanner(storeId: 'store-1')));
      await tester.pumpAndSettle();

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('shows nothing when the request fails', (tester) async {
      when(() => dioClient.get<dynamic>('/stores/store-1/banners/active'))
          .thenThrow(Exception('network unavailable'));

      await tester.pumpWidget(wrap(const ActiveBanner(storeId: 'store-1')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('hides a banner whose id is already in the dismissed list',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'dismissed_banner_ids': ['banner-1'],
      });
      when(() => dioClient.get<dynamic>('/stores/store-1/banners/active'))
          .thenAnswer(
        (_) async => resp<dynamic>({
          'id': 'banner-1',
          'title': 'Скидка 20%',
          'body': 'Только для PREMIUM',
        }),
      );

      await tester.pumpWidget(wrap(const ActiveBanner(storeId: 'store-1')));
      await tester.pumpAndSettle();

      expect(find.text('Скидка 20%'), findsNothing);
    });

    testWidgets(
        'dismissing the banner hides it and persists the id so it does not '
        'reappear on the next load', (tester) async {
      when(() => dioClient.get<dynamic>('/stores/store-1/banners/active'))
          .thenAnswer(
        (_) async => resp<dynamic>({
          'id': 'banner-1',
          'title': 'Скидка 20%',
          'body': 'Только для PREMIUM',
        }),
      );

      await tester.pumpWidget(wrap(const ActiveBanner(storeId: 'store-1')));
      await tester.pumpAndSettle();
      expect(find.text('Скидка 20%'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Скидка 20%'), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('dismissed_banner_ids'), contains('banner-1'));

      // Simulate a fresh load (e.g. after app relaunch) — the same
      // dismissed id must still be respected.
      await tester.pumpWidget(wrap(const ActiveBanner(storeId: 'store-1')));
      await tester.pumpAndSettle();
      expect(find.text('Скидка 20%'), findsNothing);
    });
  });
}
