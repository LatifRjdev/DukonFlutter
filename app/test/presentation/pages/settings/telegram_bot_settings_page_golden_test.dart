import 'package:dio/dio.dart' show Options, Response;
import 'package:dokonpro/core/network/dio_client.dart';
import 'package:dokonpro/injection.dart';
import 'package:dokonpro/presentation/pages/settings/telegram_bot_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import '../../../helpers/golden_pump_helper.dart';

class _FakeDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      throw Exception('network unavailable');

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      throw Exception('network unavailable');
}

void main() {
  setUp(() {
    if (!sl.isRegistered<DioClient>()) {
      sl.registerSingleton<DioClient>(_FakeDioClient());
    }
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  Widget page() =>
      const TelegramBotSettingsPage(storeId: 'test-store-id');

  group('TelegramBotSettingsPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'telegram_bot_settings_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'telegram_bot_settings_dark');
    });
  });
}
