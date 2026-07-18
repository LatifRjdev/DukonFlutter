import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/investment_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late InvestmentRemoteDatasourceImpl ds;

  setUp(() {
    dio = _MockDioClient();
    ds = InvestmentRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(dynamic body) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  Map<String, dynamic> validInvestmentJson({String id = 'inv-1'}) => {
        'id': id,
        'storeId': 'store-1',
        'name': 'New shop equipment',
        'description': 'Refrigeration unit',
        'amount': 5000,
        'returnAmount': 5500,
        'investorName': 'Ali',
        'investorPhone': '+992900000000',
        'status': 'ACTIVE',
        'startDate': '2026-01-01T00:00:00.000Z',
        'endDate': '2026-06-01T00:00:00.000Z',
        'createdAt': '2026-01-01T00:00:00.000Z',
      };

  void mockGet(Map<String, dynamic> body) {
    when(() => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => resp(body));
  }

  group('InvestmentRemoteDatasourceImpl.getInvestments', () {
    test('parses a full list response', () async {
      mockGet({
        'data': [validInvestmentJson()],
        'total': 1,
        'totalPages': 1,
      });

      final result = await ds.getInvestments('store-1');

      expect(result.data.length, 1);
      expect(result.total, 1);
      expect(result.totalPages, 1);
      final inv = result.data.first;
      expect(inv.id, 'inv-1');
      expect(inv.storeId, 'store-1');
      expect(inv.name, 'New shop equipment');
      expect(inv.description, 'Refrigeration unit');
      expect(inv.amount, 5000.0);
      expect(inv.returnAmount, 5500.0);
      expect(inv.investorName, 'Ali');
      expect(inv.investorPhone, '+992900000000');
      expect(inv.status, 'ACTIVE');
      expect(inv.startDate, DateTime.parse('2026-01-01T00:00:00.000Z'));
      expect(inv.endDate, DateTime.parse('2026-06-01T00:00:00.000Z'));
      expect(inv.createdAt, DateTime.parse('2026-01-01T00:00:00.000Z'));
    });

    test('defaults total to 0 and totalPages to 1 when absent', () async {
      mockGet({'data': <dynamic>[]});

      final result = await ds.getInvestments('store-1');

      expect(result.data, isEmpty);
      expect(result.total, 0);
      expect(result.totalPages, 1);
    });

    test(
        'leaves description/returnAmount/investorPhone/endDate null when '
        'absent from the row', () async {
      mockGet({
        'data': [
          {
            'id': 'inv-2',
            'storeId': 'store-1',
            'name': 'Delivery bike',
            'amount': 1200,
            'investorName': 'Bek',
            'status': 'ACTIVE',
            'startDate': '2026-02-01T00:00:00.000Z',
            'createdAt': '2026-02-01T00:00:00.000Z',
          }
        ],
        'total': 1,
        'totalPages': 1,
      });

      final result = await ds.getInvestments('store-1');

      final inv = result.data.single;
      expect(inv.description, isNull);
      expect(inv.returnAmount, isNull);
      expect(inv.investorPhone, isNull);
      expect(inv.endDate, isNull);
    });

    test('coerces integer amount and returnAmount to double', () async {
      mockGet({
        'data': [
          {
            'id': 'inv-3',
            'storeId': 'store-1',
            'name': 'Stall renovation',
            'amount': 10,
            'returnAmount': 12,
            'investorName': 'Karim',
            'status': 'COMPLETED',
            'startDate': '2026-02-01T00:00:00.000Z',
            'createdAt': '2026-02-01T00:00:00.000Z',
          }
        ],
        'total': 1,
        'totalPages': 1,
      });

      final result = await ds.getInvestments('store-1');

      expect(result.data.single.amount, 10.0);
      expect(result.data.single.amount, isA<double>());
      expect(result.data.single.returnAmount, 12.0);
      expect(result.data.single.returnAmount, isA<double>());
    });

    test(
        'passes page/limit/status/startDate/endDate as query parameters '
        'when provided', () async {
      mockGet({'data': <dynamic>[]});
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 31);

      await ds.getInvestments(
        'store-1',
        page: 2,
        limit: 10,
        status: 'ACTIVE',
        startDate: start,
        endDate: end,
      );

      final captured = verify(() => dio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['page'], 2);
      expect(params['limit'], 10);
      expect(params['status'], 'ACTIVE');
      expect(params['startDate'], start.toIso8601String());
      expect(params['endDate'], end.toIso8601String());
    });

    test('omits status/startDate/endDate query params when not provided',
        () async {
      mockGet({'data': <dynamic>[]});

      await ds.getInvestments('store-1');

      final captured = verify(() => dio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['page'], 1);
      expect(params['limit'], 20);
      expect(params.containsKey('status'), isFalse);
      expect(params.containsKey('startDate'), isFalse);
      expect(params.containsKey('endDate'), isFalse);
    });

    test('requests the correct endpoint for the given storeId', () async {
      mockGet({'data': <dynamic>[]});

      await ds.getInvestments('store-42');

      verify(() => dio.get<dynamic>(
            '/stores/store-42/investments',
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
        () => ds.getInvestments('store-1'),
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
        () => ds.getInvestments('store-1'),
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
        () => ds.getInvestments('store-1'),
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
            'message': ['name is required', 'amount is required']
          },
        ),
      ));

      await expectLater(
        () => ds.getInvestments('store-1'),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'name is required, amount is required',
        )),
      );
    });

    test('falls back to dio message when error response has no message',
        () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        message: 'dio failure text',
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 502,
          data: <String, dynamic>{},
        ),
      ));

      await expectLater(
        () => ds.getInvestments('store-1'),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'dio failure text',
        )),
      );
    });
  });

  group('InvestmentRemoteDatasourceImpl.getInvestment', () {
    test('parses a single investment response', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp(validInvestmentJson()));

      final inv = await ds.getInvestment('store-1', 'inv-1');

      expect(inv.id, 'inv-1');
      expect(inv.name, 'New shop equipment');
    });

    test('requests the correct endpoint', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp(validInvestmentJson()));

      await ds.getInvestment('store-1', 'inv-9');

      verify(() => dio.get<dynamic>('/stores/store-1/investments/inv-9'))
          .called(1);
    });

    test('throws ServerException on 404 response', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
          data: {'message': 'Not found'},
        ),
      ));

      expect(
        () => ds.getInvestment('store-1', 'missing'),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('InvestmentRemoteDatasourceImpl.createInvestment', () {
    test('posts data and parses the created investment', () async {
      when(() => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp(validInvestmentJson()));

      final data = {'name': 'New shop equipment', 'amount': 5000};
      final inv = await ds.createInvestment('store-1', data);

      expect(inv.id, 'inv-1');
      verify(() => dio.post<dynamic>(
            '/stores/store-1/investments',
            data: data,
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
        () => ds.createInvestment('store-1', {'name': 'X'}),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws ServerException with message from response on 400',
        () async {
      when(() => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 400,
          data: {'message': 'Amount must be positive'},
        ),
      ));

      await expectLater(
        () => ds.createInvestment('store-1', {'amount': -1}),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'Amount must be positive',
        )),
      );
    });
  });

  group('InvestmentRemoteDatasourceImpl.updateInvestment', () {
    test('puts data and parses the updated investment', () async {
      when(() => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp(validInvestmentJson()));

      final data = {'status': 'COMPLETED'};
      final inv = await ds.updateInvestment('store-1', 'inv-1', data);

      expect(inv.id, 'inv-1');
      verify(() => dio.put<dynamic>(
            '/stores/store-1/investments/inv-1',
            data: data,
          )).called(1);
    });

    test('throws UnauthorizedException on 401 response', () async {
      when(() => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
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
        () => ds.updateInvestment('store-1', 'inv-1', {'status': 'X'}),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('InvestmentRemoteDatasourceImpl.deleteInvestment', () {
    test('calls delete on the correct endpoint', () async {
      when(() => dio.delete<dynamic>(any()))
          .thenAnswer((_) async => resp(null));

      await ds.deleteInvestment('store-1', 'inv-1');

      verify(() => dio.delete<dynamic>('/stores/store-1/investments/inv-1'))
          .called(1);
    });

    test('throws ServerException on server error', () async {
      when(() => dio.delete<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
          data: {'message': 'boom'},
        ),
      ));

      expect(
        () => ds.deleteInvestment('store-1', 'inv-1'),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws NetworkException on send timeout', () async {
      when(() => dio.delete<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.sendTimeout,
      ));

      expect(
        () => ds.deleteInvestment('store-1', 'inv-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('InvestmentRemoteDatasourceImpl.getSummary', () {
    test('parses a full summary response', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer((_) async => resp({
            'totalAmount': 6200,
            'totalCount': 2,
            'activeAmount': 5000,
            'activeCount': 1,
            'completedAmount': 1200,
            'completedReturnAmount': 1400,
            'completedCount': 1,
          }));

      final summary = await ds.getSummary('store-1');

      expect(summary.totalAmount, 6200.0);
      expect(summary.totalCount, 2);
      expect(summary.activeAmount, 5000.0);
      expect(summary.activeCount, 1);
      expect(summary.completedAmount, 1200.0);
      expect(summary.completedReturnAmount, 1400.0);
      expect(summary.completedCount, 1);
    });

    test('defaults all fields to 0 when absent from response', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp(<String, dynamic>{}));

      final summary = await ds.getSummary('store-1');

      expect(summary.totalAmount, 0);
      expect(summary.totalCount, 0);
      expect(summary.activeAmount, 0);
      expect(summary.activeCount, 0);
      expect(summary.completedAmount, 0);
      expect(summary.completedReturnAmount, 0);
      expect(summary.completedCount, 0);
    });

    test('requests the correct endpoint for the given storeId', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp(<String, dynamic>{}));

      await ds.getSummary('store-42');

      verify(() => dio.get<dynamic>('/stores/store-42/investments/summary'))
          .called(1);
    });

    test('throws NetworkException on connection timeout', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(
        () => ds.getSummary('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws ServerException with statusCode on 500 response', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
          data: {'message': 'Internal error'},
        ),
      ));

      await expectLater(
        () => ds.getSummary('store-1'),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });
}
