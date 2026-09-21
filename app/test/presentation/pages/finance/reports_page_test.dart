import 'package:dio/dio.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/finance/reports_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

// Regression test for the 2026-09-21 manual QA finding: ReportsPage calls
// DioClient directly rather than going through a datasource with its own
// error mapping, so a raw DioException (e.g. 403 "Subscription is EXPIRED")
// used to reach mapErrorToUserMessage() unconverted and fall through to the
// same generic "Не удалось выполнить операцию" shown for every failure —
// network, 400, 403, 500 — with no way to tell a permanent failure from a
// transient one worth retrying. Fixed by converting DioException the same
// way every other remote datasource in the app does before mapping it.
class _Fake403DioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    throw DioException(
      requestOptions: RequestOptions(path: path),
      response: Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 403,
        data: {'message': 'Subscription is EXPIRED'},
      ),
      type: DioExceptionType.badResponse,
    );
  }
}

void main() {
  late MockStoreBloc storeBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());

    if (sl.isRegistered<DioClient>()) sl.unregister<DioClient>();
    sl.registerSingleton<DioClient>(_Fake403DioClient());
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) sl.unregister<DioClient>();
  });

  Widget page() => const ReportsPage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) =>
      BlocProvider<StoreBloc>.value(value: storeBloc, child: child);

  testWidgets(
      'shows "Недостаточно прав" for a 403, not the generic fallback '
      'shown for every other error type', (tester) async {
    await pumpPageWithTheme(
      tester,
      page(),
      brightness: Brightness.light,
      wrap: wrapWithBlocs,
      size: const Size(412, 900),
    );
    tester.takeException();

    expect(find.textContaining('Недостаточно прав'), findsWidgets);
    expect(find.textContaining('Не удалось выполнить операцию'), findsNothing);
  });
}
