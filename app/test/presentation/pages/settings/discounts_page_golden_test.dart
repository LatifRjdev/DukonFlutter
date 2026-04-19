import 'package:dio/dio.dart' show Options, Response;
import 'package:dokonpro/core/network/dio_client.dart';
import 'package:dokonpro/injection.dart';
import 'package:dokonpro/presentation/pages/settings/discounts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import '../../../helpers/golden_pump_helper.dart';

// ── Fake DioClient — always throws so page renders deterministic error state ──

class _FakeDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      throw Exception('network unavailable');
}

// ── Tests ─────────────────────────────────────────────────────────────────────

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

  Widget page() => const DiscountsPage(storeId: 'test-store-id');

  group('DiscountsPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'discounts_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(tester, page(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'discounts_dark');
    });
  });
}
