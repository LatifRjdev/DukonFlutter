import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/payroll_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late PayrollRemoteDatasourceImpl ds;

  setUp(() {
    dio = _MockDioClient();
    ds = PayrollRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(dynamic body) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  Map<String, dynamic> periodJson({String id = 'period-1'}) => {
        'id': id,
        'month': 5,
        'year': 2026,
        'status': 'CALCULATED',
        'totalAmount': 1000,
        'paidAmount': 0,
        'staffCount': 1,
        'payrolls': [],
      };

  group('PayrollRemoteDatasourceImpl.calculatePayroll', () {
    test('POSTs month/year and parses the returned period', () async {
      when(() => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp(periodJson()));

      final result = await ds.calculatePayroll('store-1', 5, 2026);

      expect(result.id, 'period-1');
      verify(() => dio.post<dynamic>(
            '/stores/store-1/payroll/calculate',
            data: {'month': 5, 'year': 2026},
          )).called(1);
    });

    test('throws NetworkException on connection timeout', () async {
      when(() => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(
        () => ds.calculatePayroll('store-1', 5, 2026),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('PayrollRemoteDatasourceImpl.getPayrollPeriods', () {
    test('parses a list of periods', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp([
            periodJson(id: 'period-1'),
            periodJson(id: 'period-2'),
          ]));

      final result = await ds.getPayrollPeriods('store-1');

      expect(result, hasLength(2));
      expect(result.map((p) => p.id), ['period-1', 'period-2']);
      verify(() => dio.get<dynamic>(
            '/stores/store-1/payroll',
            queryParameters: any(named: 'queryParameters'),
          )).called(1);
    });

    test('returns an empty list when the API returns an empty array',
        () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp(<dynamic>[]));

      final result = await ds.getPayrollPeriods('store-1');

      expect(result, isEmpty);
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
        () => ds.getPayrollPeriods('store-1'),
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
        () => ds.getPayrollPeriods('store-1'),
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
            'message': ['month is required', 'year is required'],
          },
        ),
      ));

      await expectLater(
        () => ds.getPayrollPeriods('store-1'),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'month is required, year is required',
        )),
      );
    });
  });

  group('PayrollRemoteDatasourceImpl.getPayrollPeriod', () {
    test('requests the period-detail endpoint and parses the period',
        () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp(periodJson()));

      final result = await ds.getPayrollPeriod('store-1', 'period-1');

      expect(result.id, 'period-1');
      verify(() => dio.get<dynamic>(
            '/stores/store-1/payroll/period-1',
            queryParameters: any(named: 'queryParameters'),
          )).called(1);
    });
  });

  group('PayrollRemoteDatasourceImpl.addAdjustment', () {
    test('POSTs the adjustment payload to the adjustments endpoint',
        () async {
      when(() => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp(null));

      await ds.addAdjustment(
        'store-1',
        'period-1',
        {'type': 'BONUS', 'amount': 100, 'description': 'x'},
      );

      verify(() => dio.post<dynamic>(
            '/stores/store-1/payroll/period-1/adjustments',
            data: {'type': 'BONUS', 'amount': 100, 'description': 'x'},
          )).called(1);
    });

    test('throws NetworkException on connection error', () async {
      when(() => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ));

      expect(
        () => ds.addAdjustment('store-1', 'period-1', {'amount': 1}),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('PayrollRemoteDatasourceImpl.removeAdjustment', () {
    test('DELETEs the specific adjustment endpoint', () async {
      when(() => dio.delete<dynamic>(any()))
          .thenAnswer((_) async => resp(null));

      await ds.removeAdjustment('store-1', 'period-1', 'adj-1');

      verify(() => dio.delete<dynamic>(
            '/stores/store-1/payroll/period-1/adjustments/adj-1',
          )).called(1);
    });

    test('throws ServerException with statusCode on 404 response', () async {
      when(() => dio.delete<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
          data: {'message': 'Not found'},
        ),
      ));

      await expectLater(
        () => ds.removeAdjustment('store-1', 'period-1', 'adj-missing'),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('PayrollRemoteDatasourceImpl.payIndividual', () {
    test('POSTs to the individual pay endpoint', () async {
      when(() => dio.post<dynamic>(any())).thenAnswer((_) async => resp(null));

      await ds.payIndividual('store-1', 'period-1', 'payroll-1');

      verify(() => dio.post<dynamic>(
            '/stores/store-1/payroll/period-1/pay/payroll-1',
          )).called(1);
    });
  });

  group('PayrollRemoteDatasourceImpl.payAll', () {
    test('POSTs to the pay-all endpoint', () async {
      when(() => dio.post<dynamic>(any())).thenAnswer((_) async => resp(null));

      await ds.payAll('store-1', 'period-1');

      verify(() => dio.post<dynamic>(
            '/stores/store-1/payroll/period-1/pay-all',
          )).called(1);
    });

    test('falls back to a generic error when the message is neither string nor list',
        () async {
      when(() => dio.post<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        message: 'boom',
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 502,
          data: <String, dynamic>{},
        ),
      ));

      await expectLater(
        () => ds.payAll('store-1', 'period-1'),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 502)),
      );
    });
  });
}
