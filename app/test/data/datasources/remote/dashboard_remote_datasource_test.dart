import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/dashboard_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late DashboardRemoteDatasourceImpl ds;

  setUp(() {
    dio = _MockDioClient();
    ds = DashboardRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(Map<String, dynamic> body) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  void mockGet(Map<String, dynamic> body) {
    when(() => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => resp(body));
  }

  group('DashboardRemoteDatasourceImpl.getOverview', () {
    test('parses full response with primary field names', () async {
      mockGet({
        'todayRevenue': 1000.0,
        'todayCost': 400.0,
        'todayExpenses': 50.0,
        'todayProfit': 550.0,
        'todaySalesCount': 5,
        'totalProducts': 20,
        'lowStockProducts': 3,
        'customerDebtsTotal': 120.0,
        'supplierDebtsTotal': 80.0,
        'recentSales': [
          {
            'id': 'sale-1',
            'receiptNo': 'R-001',
            'total': 100.0,
            'paymentType': 'CASH',
            'status': 'COMPLETED',
            'customerName': 'Ali',
            'createdAt': '2026-05-11T00:00:00.000Z',
          },
        ],
      });

      final stats = await ds.getOverview('store-1');

      expect(stats.todayRevenue, 1000.0);
      expect(stats.todayCost, 400.0);
      expect(stats.todayExpenses, 50.0);
      expect(stats.todayProfit, 550.0);
      expect(stats.todaySalesCount, 5);
      expect(stats.totalProducts, 20);
      expect(stats.lowStockProducts, 3);
      expect(stats.customerDebtsTotal, 120.0);
      expect(stats.supplierDebtsTotal, 80.0);
      expect(stats.recentSales.length, 1);
      expect(stats.recentSales.first.receiptNo, 'R-001');
      expect(stats.recentSales.first.storeId, 'store-1');
      expect(stats.recentSales.first.customerName, 'Ali');
    });

    test('falls back to alternate field names when primary keys are absent',
        () async {
      mockGet({
        'revenue': 200.0,
        'costOfGoods': 90.0,
        'expenses': 10.0,
        'netProfit': 100.0,
        'salesCount': 2,
      });

      final stats = await ds.getOverview('store-1');

      expect(stats.todayRevenue, 200.0);
      expect(stats.todayCost, 90.0);
      expect(stats.todayExpenses, 10.0);
      expect(stats.todayProfit, 100.0);
      expect(stats.todaySalesCount, 2);
    });

    test('defaults every numeric field to 0 and recentSales to empty '
        'when the response body is empty', () async {
      mockGet({});

      final stats = await ds.getOverview('store-1');

      expect(stats.todayRevenue, 0);
      expect(stats.todayCost, 0);
      expect(stats.todayExpenses, 0);
      expect(stats.todayProfit, 0);
      expect(stats.todaySalesCount, 0);
      expect(stats.totalProducts, 0);
      expect(stats.lowStockProducts, 0);
      expect(stats.customerDebtsTotal, 0);
      expect(stats.supplierDebtsTotal, 0);
      expect(stats.recentSales, isEmpty);
    });

    test('fills in defaults for a recentSales row missing optional fields',
        () async {
      mockGet({
        'recentSales': [
          <String, dynamic>{},
        ],
      });

      final stats = await ds.getOverview('store-1');

      expect(stats.recentSales.length, 1);
      final sale = stats.recentSales.first;
      expect(sale.id, '');
      expect(sale.receiptNo, '');
      expect(sale.total, 0);
      expect(sale.paymentType, 'CASH');
      expect(sale.status, 'COMPLETED');
      expect(sale.customerName, isNull);
      // Unparseable createdAt falls back to "now" rather than throwing.
      expect(sale.createdAt, isNotNull);
    });

    test('passes period/startDate/endDate through as query parameters',
        () async {
      mockGet({});
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 31);

      await ds.getOverview('store-1',
          period: 'custom', startDate: start, endDate: end);

      final captured = verify(() => dio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['period'], 'custom');
      expect(params['startDate'], start.toIso8601String());
      expect(params['endDate'], end.toIso8601String());
    });

    test('omits startDate/endDate query params when not provided', () async {
      mockGet({});

      await ds.getOverview('store-1');

      final captured = verify(() => dio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['period'], 'today');
      expect(params.containsKey('startDate'), isFalse);
      expect(params.containsKey('endDate'), isFalse);
    });

    test('requests the correct endpoint for the given storeId', () async {
      mockGet({});

      await ds.getOverview('store-42');

      verify(() => dio.get<dynamic>(
            '/stores/store-42/finances/overview',
            queryParameters: any(named: 'queryParameters'),
          )).called(1);
    });

    test('throws NetworkException on connection timeout', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(
        () => ds.getOverview('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws UnauthorizedException on 401 response', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 401,
          data: {'message': 'Unauthorized'},
        ),
      ));

      expect(
        () => ds.getOverview('store-1'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('throws ServerException with statusCode on 500 response', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
          data: {'message': 'Internal error'},
        ),
      ));

      await expectLater(
        () => ds.getOverview('store-1'),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('joins list-shaped error message with comma', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 400,
          data: {
            'message': ['field a is required', 'field b is required']
          },
        ),
      ));

      await expectLater(
        () => ds.getOverview('store-1'),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'field a is required, field b is required',
        )),
      );
    });
  });
}
