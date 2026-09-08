import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/sale_remote_datasource.dart';

// BUG #28 root cause was that ONE malformed row in the API response
// caused the WHOLE list to fail to parse, and the user saw
// "Не удалось выполнить операцию" on История продаж despite a 200
// response with valid rows alongside.
//
// Spec decision Q3=C: fix the root cause AND make the parser
// resilient — wrap each row in try/catch, skip-and-warn on failure,
// surface the count via `skippedRows` in the return record.
class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late SaleRemoteDatasourceImpl ds;

  setUp(() {
    dio = _MockDioClient();
    ds = SaleRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(Map<String, dynamic> body) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  group('SaleRemoteDatasourceImpl.getSales — parser resilience', () {
    test(
        'returns 2 sales + skippedRows=1 when 1 of 3 rows is malformed',
        () async {
      // First and third rows are valid; second is missing the required
      // `total` field which the model treats as required.
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({
            'data': [
              _validSaleJson('R-001'),
              _malformedRowJson(),
              _validSaleJson('R-002'),
            ],
            'total': 3,
            'page': 1,
            'limit': 20,
            'totalPages': 1,
          }));

      final result = await ds.getSales('store-1');

      expect(result.data.length, 2);
      expect(result.data.map((s) => s.receiptNo), ['R-001', 'R-002']);
      expect(result.skippedRows, 1);
    });

    // Regression test for a real bug found during a live manual QA pass
    // (2026-09-07): the sales LIST endpoint (`SalesService.findAll`)
    // deliberately returns a lightweight items projection —
    // {id, productName, quantity, total} only, no saleId/productId/
    // unitPrice — for pagination performance; only the single-sale detail
    // endpoint returns those fields. `_mapSaleItem` used to require all
    // three unconditionally, so EVERY sale returned by the list endpoint
    // failed to parse (the exception from `_mapSaleItem` propagates up
    // through `_mapSale`, which has no per-item try/catch of its own,
    // and gets caught by `getSales`'s per-*row* catch) — making История
    // продаж always render empty regardless of real data, while `total`
    // (from a separate COUNT query) stayed correct. This reproduces that
    // exact minimal item shape and asserts it now parses successfully.
    test(
        'parses a sale whose item uses the sales-LIST minimal projection '
        '(no saleId/productId/unitPrice) instead of skipping it', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({
            'data': [
              {
                ..._validSaleJson('R-003'),
                'items': [
                  {
                    'id': 'item-1',
                    'productName': 'Test_Product_1',
                    'quantity': 2,
                    'total': 160,
                  },
                ],
              },
            ],
            'total': 1,
            'page': 1,
            'limit': 20,
            'totalPages': 1,
          }));

      final result = await ds.getSales('store-1');

      expect(result.skippedRows, 0);
      expect(result.data.length, 1);
      final item = result.data.single.items.single;
      expect(item.productName, 'Test_Product_1');
      expect(item.quantity, 2);
      expect(item.total, 160);
      // Derived fallbacks: saleId from the parent sale, unitPrice from
      // total/quantity, productId empty rather than throwing.
      expect(item.saleId, 'sale-R-003');
      expect(item.unitPrice, 80);
      expect(item.productId, '');
    });

    test('returns 0 sales + skippedRows=0 when API returns empty list',
        () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({
            'data': [],
            'total': 0,
            'page': 1,
            'limit': 20,
            'totalPages': 0,
          }));

      final result = await ds.getSales('store-1');
      expect(result.data, isEmpty);
      expect(result.skippedRows, 0);
    });
  });
}

Map<String, dynamic> _validSaleJson(String receiptNo) => {
      'id': 'sale-$receiptNo',
      'storeId': 'store-1',
      'customerId': null,
      'staffId': null,
      'shiftId': null,
      'receiptNo': receiptNo,
      'subtotal': 5,
      'discount': 0,
      'discountType': null,
      'total': 5,
      'paymentType': 'CASH',
      'paidAmount': 5,
      'change': 0,
      'debtAmount': 0,
      'dueDate': null,
      'status': 'COMPLETED',
      'notes': null,
      'localId': null,
      'createdAt': '2026-05-11T00:00:00.000Z',
      'updatedAt': '2026-05-11T00:00:00.000Z',
      'items': [],
    };

// Missing `total` — current parser does (json['total'] as num).toDouble()
// which throws on null. Resilience guarantees the rest of the page still
// renders.
Map<String, dynamic> _malformedRowJson() => {
      'id': 'bad',
      'storeId': 'store-1',
      'receiptNo': 'BAD',
      'subtotal': 5,
      // 'total' deliberately missing
      'paymentType': 'CASH',
      'paidAmount': 5,
      'createdAt': '2026-05-11T00:00:00.000Z',
      'updatedAt': '2026-05-11T00:00:00.000Z',
      'items': [],
    };
