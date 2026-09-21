import 'package:dio/dio.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/settings/my_stores_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class _FakeDioClient extends Fake implements DioClient {
  bool putShouldFail = false;
  int putCallCount = 0;
  String? lastPutName;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: [
        {
          'id': 'store-1',
          'name': 'Test_Store_2',
          'category': 'GROCERY',
          'address': '',
          'phone': '',
        },
      ] as T,
    );
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    putCallCount++;
    lastPutName = (data as Map)['name'] as String?;
    if (putShouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.connectionError,
      );
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: data as T,
    );
  }
}

void main() {
  late MockStoreBloc storeBloc;
  late _FakeDioClient dioClient;

  setUp(() {
    storeBloc = MockStoreBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());

    dioClient = _FakeDioClient();
    if (sl.isRegistered<DioClient>()) sl.unregister<DioClient>();
    sl.registerSingleton<DioClient>(dioClient);
  });

  tearDown(() {
    storeBloc.close();
    if (sl.isRegistered<DioClient>()) sl.unregister<DioClient>();
  });

  Widget wrapWithBloc(Widget child) =>
      BlocProvider<StoreBloc>.value(value: storeBloc, child: child);

  Future<void> openEditSheet(WidgetTester tester) async {
    await pumpPageWithTheme(
      tester,
      const MyStoresPage(),
      brightness: Brightness.light,
      wrap: wrapWithBloc,
      size: const Size(412, 900),
    );
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
  }

  group('MyStoresPage edit form', () {
    // Regression test: the edit form used plain TextFields with no
    // validator, so an empty name went straight to the server, which
    // 400'd with a generic "Некорректные данные" toast while the sheet
    // itself had already closed unconditionally — losing the user's
    // edits. Fixed by wrapping the fields in a Form with a validator and
    // only popping the sheet on success.
    testWidgets(
        'blocks submission client-side when name is cleared, without '
        'calling the API', (tester) async {
      await openEditSheet(tester);

      final nameField = find.widgetWithText(TextFormField, 'Название *');
      await tester.enterText(nameField, '');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(find.text('Введите название'), findsOneWidget);
      expect(dioClient.putCallCount, 0);
      // The sheet is still open — its own "Сохранить" button is still there.
      expect(find.text('Сохранить'), findsOneWidget);
    });

    testWidgets(
        'keeps the sheet open with the entered data when saving fails, '
        'instead of closing unconditionally', (tester) async {
      dioClient.putShouldFail = true;
      await openEditSheet(tester);

      final nameField = find.widgetWithText(TextFormField, 'Название *');
      await tester.enterText(nameField, 'Edited_Name');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(dioClient.putCallCount, 1);
      // Sheet is still open with the edited value intact, not discarded.
      expect(find.text('Edited_Name'), findsOneWidget);
      expect(find.text('Сохранить'), findsOneWidget);
    });

    testWidgets('closes the sheet and saves when the name is valid',
        (tester) async {
      await openEditSheet(tester);

      final nameField = find.widgetWithText(TextFormField, 'Название *');
      await tester.enterText(nameField, 'Edited_Name');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(dioClient.putCallCount, 1);
      expect(dioClient.lastPutName, 'Edited_Name');
      // The bottom sheet's own Сохранить button is gone — it closed.
      expect(find.widgetWithText(TextFormField, 'Название *'), findsNothing);
    });
  });
}
