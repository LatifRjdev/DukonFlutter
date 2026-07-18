import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/finance_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dioClient;
  late FinanceRemoteDatasourceImpl ds;

  setUp(() {
    dioClient = _MockDioClient();
    ds = FinanceRemoteDatasourceImpl(dioClient: dioClient);
  });

  Response<dynamic> resp(Map<String, dynamic> body) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  group('FinanceRemoteDatasourceImpl.getDashboard', () {
    test('maps a full dashboard response into a FinanceSummary', () async {
      when(() => dioClient.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({
            'totalRevenue': 1000,
            'totalExpenses': 400,
            'profit': 600,
            'salesCount': 10,
            'averageCheck': 100,
            'topProducts': [
              {
                'productId': 'p1',
                'productName': 'Bread',
                'totalQuantity': 5,
                'totalRevenue': 250,
              },
            ],
          }));

      final summary = await ds.getDashboard('store-1');

      expect(summary.totalIncome, 1000);
      expect(summary.totalExpenses, 400);
      expect(summary.profit, 600);
      expect(summary.salesCount, 10);
      expect(summary.avgCheck, 100);
      expect(summary.topProducts.length, 1);
      expect(summary.topProducts.first.id, 'p1');
      expect(summary.topProducts.first.name, 'Bread');
      expect(summary.topProducts.first.quantity, 5);
      expect(summary.topProducts.first.revenue, 250);
    });

    test('defaults missing numeric fields to 0 and topProducts to empty list',
        () async {
      when(() => dioClient.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({}));

      final summary = await ds.getDashboard('store-1');

      expect(summary.totalIncome, 0);
      expect(summary.totalExpenses, 0);
      expect(summary.profit, 0);
      expect(summary.salesCount, 0);
      expect(summary.avgCheck, 0);
      expect(summary.topProducts, isEmpty);
    });

    test('falls back to empty string ids/names for malformed topProducts row',
        () async {
      when(() => dioClient.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({
            'topProducts': [<String, dynamic>{}],
          }));

      final summary = await ds.getDashboard('store-1');

      expect(summary.topProducts.single.id, '');
      expect(summary.topProducts.single.name, '');
      expect(summary.topProducts.single.quantity, 0);
      expect(summary.topProducts.single.revenue, 0);
    });

    test('passes startDate/endDate as ISO8601 query parameters when provided',
        () async {
      when(() => dioClient.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({}));

      final start = DateTime.utc(2026, 1, 1);
      final end = DateTime.utc(2026, 1, 31);
      await ds.getDashboard('store-1', startDate: start, endDate: end);

      final captured = verify(() => dioClient.get(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['startDate'], start.toIso8601String());
      expect(params['endDate'], end.toIso8601String());
    });

    test('omits startDate/endDate query parameters when not provided',
        () async {
      when(() => dioClient.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({}));

      await ds.getDashboard('store-1');

      final captured = verify(() => dioClient.get(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params.containsKey('startDate'), isFalse);
      expect(params.containsKey('endDate'), isFalse);
    });

    test('throws NetworkException on connection timeout', () async {
      when(() => dioClient.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(
        () => ds.getDashboard('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws UnauthorizedException on 401 response', () async {
      when(() => dioClient.get(
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
        () => ds.getDashboard('store-1'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('throws ServerException carrying statusCode + joined message list',
        () async {
      when(() => dioClient.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
          data: {
            'message': ['boom', 'again']
          },
        ),
      ));

      try {
        await ds.getDashboard('store-1');
        fail('expected ServerException');
      } on ServerException catch (e) {
        expect(e.statusCode, 500);
        expect(e.message, 'boom, again');
      }
    });
  });

  group('FinanceRemoteDatasourceImpl.getSummary', () {
    test('aggregates salesByDay/expensesByDay into totals and avgCheck',
        () async {
      when(() => dioClient.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({
            'salesByDay': [
              {'revenue': 100, 'count': 2},
              {'revenue': 50, 'count': 1},
            ],
            'expensesByDay': [
              {'total': 30},
              {'total': 20},
            ],
          }));

      final summary = await ds.getSummary('store-1', period: 'month');

      expect(summary.totalIncome, 150);
      expect(summary.totalExpenses, 50);
      expect(summary.profit, 100);
      expect(summary.salesCount, 3);
      expect(summary.avgCheck, 50);
    });

    test('defaults to zeros and avgCheck 0 when salesCount is 0', () async {
      when(() => dioClient.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({
            'salesByDay': <dynamic>[],
            'expensesByDay': <dynamic>[],
          }));

      final summary = await ds.getSummary('store-1', period: 'month');

      expect(summary.totalIncome, 0);
      expect(summary.totalExpenses, 0);
      expect(summary.profit, 0);
      expect(summary.salesCount, 0);
      expect(summary.avgCheck, 0);
    });

    test('defaults to zeros when salesByDay/expensesByDay keys are absent',
        () async {
      when(() => dioClient.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({}));

      final summary = await ds.getSummary('store-1', period: 'week');

      expect(summary.totalIncome, 0);
      expect(summary.totalExpenses, 0);
      expect(summary.salesCount, 0);
    });

    test('sends period + startDate/endDate as query parameters', () async {
      when(() => dioClient.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({}));

      final start = DateTime.utc(2026, 2, 1);
      final end = DateTime.utc(2026, 2, 28);
      await ds.getSummary(
        'store-1',
        period: 'month',
        startDate: start,
        endDate: end,
      );

      final captured = verify(() => dioClient.get(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['period'], 'month');
      expect(params['startDate'], start.toIso8601String());
      expect(params['endDate'], end.toIso8601String());
    });

    test('throws NetworkException on connection error', () async {
      when(() => dioClient.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ));

      expect(
        () => ds.getSummary('store-1', period: 'month'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws ServerException with generic message when response has no '
        'message field', () async {
      when(() => dioClient.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        message: 'some dio message',
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
          data: <String, dynamic>{},
        ),
      ));

      try {
        await ds.getSummary('store-1', period: 'month');
        fail('expected ServerException');
      } on ServerException catch (e) {
        expect(e.statusCode, 404);
        expect(e.message, 'some dio message');
      }
    });
  });
}
