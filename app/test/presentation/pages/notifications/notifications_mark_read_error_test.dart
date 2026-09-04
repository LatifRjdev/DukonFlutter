// Regression test for post-plan SPEC.md audit finding #3: _markRead caught
// the PUT .../read failure and silently applied the optimistic "read" state
// anyway (comment: "Optimistically update anyway"), with no indication to
// the user that the write never reached the server. This exercises the fix:
// the failure now also surfaces via a snackbar, matching the pattern already
// used for the load-error half of this page.
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

  final unreadNotification = {
    'id': 'notif-1',
    'type': 'low_stock',
    'title': 'Заканчивается товар',
    'body': 'Осталось 2 шт.',
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
        'data': [unreadNotification],
        'total': 1,
      }),
    );
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) sl.unregister<DioClient>();
  });

  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<StoreBloc>.value(value: storeBloc, child: child),
      );

  testWidgets(
      'tapping an unread notification whose PUT .../read fails still marks '
      'it read locally, but now surfaces the failure via a snackbar '
      '(SPEC.md audit finding #3)', (tester) async {
    when(
      () => dioClient.put<void>(
        '/stores/test-store-id/notifications/notif-1/read',
      ),
    ).thenThrow(Exception('boom'));

    await tester.pumpWidget(
      wrap(const NotificationsPage(storeId: 'test-store-id')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Заканчивается товар'));
    await tester.pumpAndSettle();

    // The failure is no longer silently swallowed.
    expect(find.text('Не удалось выполнить операцию'), findsOneWidget);

    // The optimistic local update still happens (title switches from the
    // unread bold weight to the read weight) — this part of the
    // pre-existing behavior is unchanged by the fix.
    final titleStyle = tester
        .widget<Text>(find.text('Заканчивается товар'))
        .style;
    expect(titleStyle?.fontWeight, FontWeight.w500);
  });

  testWidgets(
      'tapping an unread notification whose PUT .../read succeeds marks it '
      'read with no error snackbar', (tester) async {
    when(
      () => dioClient.put<void>(
        '/stores/test-store-id/notifications/notif-1/read',
      ),
    ).thenAnswer((_) async => resp<void>(null));

    await tester.pumpWidget(
      wrap(const NotificationsPage(storeId: 'test-store-id')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Заканчивается товар'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось выполнить операцию'), findsNothing);
  });
}
