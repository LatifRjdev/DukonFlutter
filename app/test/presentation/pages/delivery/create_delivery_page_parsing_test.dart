// Regression test for the 2026-09-21 manual QA finding: on the "Новая
// доставка" form, the "Заказ" dropdown showed raw UUIDs ("#ec406a6c-...")
// instead of receipt numbers, and the "Курьер" dropdown rendered entirely
// blank rows. Root cause: _Sale.fromJson read `orderNumber` (a field that
// does not exist on the backend's sale objects — the real field is
// `receiptNo`, per shifts... err, sales.service.ts), and
// _StaffMember.fromJson built the name from `firstName`/`lastName` (also
// nonexistent — the real staff response has a flat `name` field, per
// staff.service.ts). Both always fell back to their empty/UUID defaults
// against any real backend response.
import 'package:dio/dio.dart' show Options, Response, RequestOptions;
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/pages/delivery/create_delivery_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDioClient extends Fake implements DioClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final reqOptions = RequestOptions(path: path);
    if (path.endsWith('/sales')) {
      return Response<T>(
        requestOptions: reqOptions,
        statusCode: 200,
        data: {
          'data': [
            {
              'id': 'ec406a6c-5281-458f-85e5-03fcc9369be1',
              'receiptNo': 'R-000042',
              'total': 500,
            },
          ],
          'total': 1,
        } as T,
      );
    }
    if (path.endsWith('/staff')) {
      return Response<T>(
        requestOptions: reqOptions,
        statusCode: 200,
        data: [
          {
            'id': 'staff-1',
            'name': 'Test_Cashier_1',
            'role': 'CASHIER',
          },
        ] as T,
      );
    }
    throw Exception('unexpected path: $path');
  }
}

void main() {
  setUp(() {
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
    sl.registerSingleton<DioClient>(_FakeDioClient());
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  testWidgets(
      'shows the real receipt number (not a raw UUID) and the real staff '
      'name (not a blank row) once refs load', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: const CreateDeliveryPage(storeId: 'store-1'),
      ),
    );
    await tester.pumpAndSettle();

    // Order dropdown: opening it reveals the real receipt number, not
    // "#ec406a6c-5281-458f-85e5-03fcc9369be1".
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('R-000042'), findsWidgets);
    expect(find.textContaining('#ec406a6c'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Courier dropdown: opening it reveals the real staff name, not a
    // blank row.
    await tester.tap(find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    expect(find.text('Test_Cashier_1'), findsWidgets);
  });
}
