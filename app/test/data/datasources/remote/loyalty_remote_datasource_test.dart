import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/loyalty_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late LoyaltyRemoteDatasourceImpl ds;

  setUp(() {
    dio = _MockDioClient();
    ds = LoyaltyRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(dynamic body, {int statusCode = 200}) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: statusCode,
        data: body,
      );

  Map<String, dynamic> txJson({
    String id = 'tx-1',
    String type = 'EARN',
    num points = 10,
  }) =>
      {
        'id': id,
        'customerId': 'cust-1',
        'storeId': 'store-1',
        'type': type,
        'points': points,
        'createdAt': '2026-07-01T00:00:00.000Z',
      };

  group('LoyaltyRemoteDatasourceImpl.getSettings', () {
    test('returns the parsed settings map on success', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({'pointsPerCurrency': 1, 'enabled': true}),
      );

      final settings = await ds.getSettings('store-1');

      expect(settings, {'pointsPerCurrency': 1, 'enabled': true});
      verify(() => dio.get<dynamic>('/stores/store-1/loyalty/settings'))
          .called(1);
    });

    test('unwraps a {"data": {...}} envelope', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'data': {'pointsPerCurrency': 2, 'enabled': false},
        }),
      );

      final settings = await ds.getSettings('store-1');

      expect(settings, {'pointsPerCurrency': 2, 'enabled': false});
    });

    test('returns an empty map when the response body is not a map',
        () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp('unexpected'));

      final settings = await ds.getSettings('store-1');

      expect(settings, isEmpty);
    });

    test('throws NetworkException on connection timeout', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(
        () => ds.getSettings('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws UnauthorizedException on 401 response', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Unauthorized'}, statusCode: 401),
      ));

      expect(
        () => ds.getSettings('store-1'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('throws ServerException with statusCode on 500 response', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Internal error'}, statusCode: 500),
      ));

      await expectLater(
        () => ds.getSettings('store-1'),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('joins list-shaped error message with comma', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({
          'message': ['pointsPerCurrency must be positive', 'enabled required'],
        }, statusCode: 400),
      ));

      await expectLater(
        () => ds.getSettings('store-1'),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'pointsPerCurrency must be positive, enabled required',
        )),
      );
    });
  });

  group('LoyaltyRemoteDatasourceImpl.updateSettings', () {
    test('sends the given data map and returns the updated settings',
        () async {
      when(() => dio.put<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer(
        (_) async => resp({'pointsPerCurrency': 5, 'enabled': true}),
      );

      final settings = await ds.updateSettings(
        'store-1',
        {'pointsPerCurrency': 5},
      );

      expect(settings, {'pointsPerCurrency': 5, 'enabled': true});
      verify(() => dio.put<dynamic>(
            '/stores/store-1/loyalty/settings',
            data: {'pointsPerCurrency': 5},
          )).called(1);
    });

    test('throws UnauthorizedException on 401 response', () async {
      when(() => dio.put<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Unauthorized'}, statusCode: 401),
      ));

      expect(
        () => ds.updateSettings('store-1', {'enabled': false}),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('throws NetworkException on send timeout', () async {
      when(() => dio.put<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.sendTimeout,
      ));

      expect(
        () => ds.updateSettings('store-1', {'enabled': false}),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('LoyaltyRemoteDatasourceImpl.getCustomerBalance', () {
    test('parses points and transactions on success', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'points': 120,
          'transactions': [
            txJson(id: 'tx-1', type: 'EARN', points: 100),
            txJson(id: 'tx-2', type: 'REDEEM', points: -20),
          ],
        }),
      );

      final result = await ds.getCustomerBalance('store-1', 'cust-1');

      expect(result.points, 120);
      expect(result.transactions.length, 2);
      expect(result.transactions[0].id, 'tx-1');
      expect(result.transactions[1].type, 'REDEEM');
      verify(() => dio.get<dynamic>(
            '/stores/store-1/loyalty/customers/cust-1/balance',
          )).called(1);
    });

    test('defaults points to 0 when absent', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({'transactions': <dynamic>[]}),
      );

      final result = await ds.getCustomerBalance('store-1', 'cust-1');

      expect(result.points, 0);
      expect(result.transactions, isEmpty);
    });

    test('returns an empty transaction list when "transactions" is absent',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({'points': 10}),
      );

      final result = await ds.getCustomerBalance('store-1', 'cust-1');

      expect(result.transactions, isEmpty);
    });

    test('skips non-map entries in the transactions list', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'points': 10,
          'transactions': [
            txJson(id: 'tx-1'),
            'not-a-map',
            42,
            null,
          ],
        }),
      );

      final result = await ds.getCustomerBalance('store-1', 'cust-1');

      expect(result.transactions.length, 1);
      expect(result.transactions.single.id, 'tx-1');
    });

    test(
        'falls back to zero balance (does not throw) on 403 plan-ineligible response',
        () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Forbidden'}, statusCode: 403),
      ));

      final result = await ds.getCustomerBalance('store-1', 'cust-1');

      expect(result.points, 0);
      expect(result.transactions, isEmpty);
    });

    test(
        'falls back to zero balance (does not throw) on 404 no-record response',
        () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Not found'}, statusCode: 404),
      ));

      final result = await ds.getCustomerBalance('store-1', 'cust-1');

      expect(result.points, 0);
      expect(result.transactions, isEmpty);
    });

    test('falls back to zero balance on connection timeout', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      final result = await ds.getCustomerBalance('store-1', 'cust-1');

      expect(result.points, 0);
      expect(result.transactions, isEmpty);
    });
  });

  group('LoyaltyRemoteDatasourceImpl.getAnalytics', () {
    test('sends from/to as yyyy-MM-dd query params and parses the response',
        () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer(
        (_) async => resp({
          'period': {
            'from': '2026-07-01T00:00:00.000Z',
            'to': '2026-07-09T00:00:00.000Z',
          },
          'totalEarned': 1000,
          'totalRedeemed': 200,
          'totalExpired': 50,
          'discountValue': 20.0,
          'activeParticipants': 5,
          'topCustomers': [],
        }),
      );

      final from = DateTime(2026, 7, 1);
      final to = DateTime(2026, 7, 9);
      final analytics = await ds.getAnalytics('store-1', from, to);

      expect(analytics.totalEarned, 1000);
      expect(analytics.totalRedeemed, 200);
      expect(analytics.activeParticipants, 5);
      verify(() => dio.get<dynamic>(
            '/stores/store-1/loyalty/analytics',
            queryParameters: {'from': '2026-07-01', 'to': '2026-07-09'},
          )).called(1);
    });

    test('throws NetworkException on connection error', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ));

      expect(
        () => ds.getAnalytics('store-1', DateTime(2026, 7, 1), DateTime(2026, 7, 9)),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws ServerException with statusCode on 500 response', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Internal error'}, statusCode: 500),
      ));

      await expectLater(
        () => ds.getAnalytics('store-1', DateTime(2026, 7, 1), DateTime(2026, 7, 9)),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('throws UnauthorizedException on 401 response', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Unauthorized'}, statusCode: 401),
      ));

      expect(
        () => ds.getAnalytics('store-1', DateTime(2026, 7, 1), DateTime(2026, 7, 9)),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });
}
