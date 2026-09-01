// Regression coverage for #28: _DeliveryDetail.fromJson parsed
// `total: (j['amount'] ?? j['total'] as num?)?.toDouble() ?? 0`, where Dart's
// operator precedence binds `as num?` to `j['total']` only — not to the
// result of the `??` — so a present-but-non-num `amount` value skipped the
// safe cast entirely and called `.toDouble()` on it directly. Fixed to
// `((j['amount'] ?? j['total']) as num?)?.toDouble() ?? 0`, which casts the
// already-resolved fallback value. `_DeliveryDetail` is private to
// delivery_detail_page.dart, so the fixture is exercised through the public
// DeliveryDetailPage widget with a faked DioClient response, matching this
// file's existing golden-test convention.
import 'package:dio/dio.dart' show Options, RequestOptions, Response;
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/pages/delivery/delivery_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/golden_pump_helper.dart';

// ── Fake DioClient — returns a delivery payload with `total` but no
//    `amount` key at all, the exact shape the SPEC.md #28 fixture calls for.

class _FakeDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {
          'id': 'delivery-1',
          'orderNumber': 'ORD-100',
          'customerName': 'Test Customer',
          'address': 'Test address',
          // No 'amount' key present — only 'total'.
          'total': 500,
          'status': 'NEW',
          'items': [
            {'name': 'Widget', 'qty': 3, 'price': 100},
          ],
          'createdAt': '2024-01-01T10:00:00.000Z',
        } as T,
      );
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

  testWidgets(
      'parses a delivery whose JSON has total but no amount without '
      'throwing, and shows the total value (#28)', (tester) async {
    await pumpPageWithTheme(
      tester,
      const DeliveryDetailPage(
        storeId: 'test-store-id',
        deliveryId: 'test-delivery-id',
      ),
      brightness: Brightness.light,
    );

    // The precedence bug (or a regression to it) would surface here as a
    // thrown NoSuchMethodError/TypeError during fromJson, which BlocBuilder
    // would otherwise swallow into an error state — assert explicitly that
    // nothing was thrown.
    expect(tester.takeException(), isNull);

    // Item row: 100 * 3 = "300 TJS". Total row: parsed from 'total' = "500
    // TJS". Distinct values confirm `total` was used, not just the items sum.
    expect(find.text('300 TJS'), findsOneWidget);
    expect(find.text('500 TJS'), findsOneWidget);
  });
}
