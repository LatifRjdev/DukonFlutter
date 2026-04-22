import 'package:dio/dio.dart' show Options, Response;
import 'package:dokonpro/core/network/dio_client.dart';
import 'package:dokonpro/injection.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/pages/settings/my_stores_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class _FakeDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      throw Exception('network unavailable');
}

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
    storeBloc.close();
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  Widget wrapWithBloc(Widget child) => BlocProvider<StoreBloc>.value(
        value: storeBloc,
        child: child,
      );

  Widget page() => const MyStoresPage();

  group('MyStoresPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBloc,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'my_stores_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBloc,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'my_stores_dark');
    });
  });
}
