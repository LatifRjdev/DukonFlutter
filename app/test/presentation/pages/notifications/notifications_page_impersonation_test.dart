import 'package:dio/dio.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/notifications/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dioClient;
  late MockStoreBloc storeBloc;

  Response<T> resp<T>(T? body) => Response<T>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  final impersonationNotification = {
    'id': 'notif-1',
    'type': 'IMPERSONATION_REQUEST',
    'title': 'Запрос доступа от поддержки',
    'body': 'Поддержка Dukon запросила временный доступ к вашему аккаунту.',
    'createdAt': DateTime.now().toIso8601String(),
    'isRead': false,
  };

  setUp(() {
    dioClient = _MockDioClient();
    storeBloc = MockStoreBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());

    if (sl.isRegistered<DioClient>()) sl.unregister<DioClient>();
    sl.registerSingleton<DioClient>(dioClient);

    when(
      () => dioClient.get<Map<String, dynamic>>(
        '/stores/test-store-id/notifications',
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => resp<Map<String, dynamic>>({
        'data': [impersonationNotification],
        'total': 1,
      }),
    );
    when(
      () => dioClient.put<void>(
        '/stores/test-store-id/notifications/notif-1/read',
      ),
    ).thenAnswer((_) async => resp<void>(null));
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) sl.unregister<DioClient>();
  });

  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<StoreBloc>.value(value: storeBloc, child: child),
      );

  group('NotificationsPage — impersonation consent', () {
    testWidgets('shows Разрешить/Отклонить for an IMPERSONATION_REQUEST item',
        (tester) async {
      await tester.pumpWidget(
        wrap(const NotificationsPage(storeId: 'test-store-id')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Разрешить'), findsOneWidget);
      expect(find.text('Отклонить'), findsOneWidget);
    });

    testWidgets(
        'approving looks up the pending request then PUTs decision=APPROVED',
        (tester) async {
      when(
        () => dioClient
            .get<Map<String, dynamic>>('/impersonation-requests/pending'),
      ).thenAnswer(
        (_) async => resp<Map<String, dynamic>>({
          'id': 'req-1',
          'status': 'PENDING',
        }),
      );
      when(
        () => dioClient.put<void>(
          '/impersonation-requests/req-1/respond',
          data: {'decision': 'APPROVED'},
        ),
      ).thenAnswer((_) async => resp<void>(null));

      await tester.pumpWidget(
        wrap(const NotificationsPage(storeId: 'test-store-id')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Разрешить'));
      await tester.pumpAndSettle();

      verify(
        () => dioClient
            .get<Map<String, dynamic>>('/impersonation-requests/pending'),
      ).called(1);
      verify(
        () => dioClient.put<void>(
          '/impersonation-requests/req-1/respond',
          data: {'decision': 'APPROVED'},
        ),
      ).called(1);
      expect(find.text('Доступ предоставлен'), findsOneWidget);
      // Buttons disappear once responded.
      expect(find.text('Разрешить'), findsNothing);
    });

    testWidgets('rejecting PUTs decision=REJECTED for the found request',
        (tester) async {
      when(
        () => dioClient
            .get<Map<String, dynamic>>('/impersonation-requests/pending'),
      ).thenAnswer(
        (_) async => resp<Map<String, dynamic>>({
          'id': 'req-1',
          'status': 'PENDING',
        }),
      );
      when(
        () => dioClient.put<void>(
          '/impersonation-requests/req-1/respond',
          data: {'decision': 'REJECTED'},
        ),
      ).thenAnswer((_) async => resp<void>(null));

      await tester.pumpWidget(
        wrap(const NotificationsPage(storeId: 'test-store-id')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Отклонить'));
      await tester.pumpAndSettle();

      verify(
        () => dioClient.put<void>(
          '/impersonation-requests/req-1/respond',
          data: {'decision': 'REJECTED'},
        ),
      ).called(1);
      expect(find.text('Запрос отклонён'), findsOneWidget);
    });

    testWidgets(
        'shows an error and keeps buttons hidden-on-retry-only when no pending request is found',
        (tester) async {
      when(
        () => dioClient
            .get<Map<String, dynamic>>('/impersonation-requests/pending'),
      ).thenAnswer((_) async => resp<Map<String, dynamic>>(null));

      await tester.pumpWidget(
        wrap(const NotificationsPage(storeId: 'test-store-id')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Разрешить'));
      await tester.pumpAndSettle();

      expect(
        find.text('Не удалось обработать запрос — возможно, он уже неактивен'),
        findsOneWidget,
      );
      verifyNever(
        () => dioClient.put<void>(
          any(that: contains('/respond')),
          data: any(named: 'data'),
        ),
      );
    });
  });
}
