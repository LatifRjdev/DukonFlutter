import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/customer_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late CustomerRemoteDatasourceImpl ds;

  setUp(() {
    dio = _MockDioClient();
    ds = CustomerRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(dynamic body) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  Map<String, dynamic> fullCustomerJson({String id = 'c1'}) => {
        'id': id,
        'storeId': 'store-1',
        'name': 'Ali',
        'phone': '+992900000000',
        'email': 'ali@example.com',
        'birthday': '2000-01-15T00:00:00.000Z',
        'notes': 'VIP customer',
        'loyaltyPoints': 120,
        'totalSpent': 4500.5,
        'debt': 100,
        'isActive': true,
        'telegramChatId': 'tg-123',
      };

  Map<String, dynamic> minimalCustomerJson({String id = 'c2'}) => {
        'id': id,
        'storeId': 'store-1',
        'name': 'Bek',
      };

  group('CustomerRemoteDatasourceImpl.getCustomers', () {
    test('returns mapped customers + pagination totals on success', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({
            'data': [fullCustomerJson(id: 'c1'), minimalCustomerJson(id: 'c2')],
            'total': 2,
            'page': 1,
            'limit': 20,
            'totalPages': 1,
          }));

      final result = await ds.getCustomers('store-1');

      expect(result.data.length, 2);
      expect(result.data[0].id, 'c1');
      expect(result.data[1].id, 'c2');
      expect(result.total, 2);
      expect(result.totalPages, 1);
    });

    test('returns empty list when API returns empty data array', () async {
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

      final result = await ds.getCustomers('store-1');

      expect(result.data, isEmpty);
      expect(result.total, 0);
    });

    test('includes search query param only when search is non-empty', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({'data': [], 'total': 0, 'totalPages': 0}));

      await ds.getCustomers('store-1', search: 'ali');

      final captured = verify(() => dio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['search'], 'ali');
    });

    test('omits search query param when search is null', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({'data': [], 'total': 0, 'totalPages': 0}));

      await ds.getCustomers('store-1');

      final captured = verify(() => dio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params.containsKey('search'), isFalse);
    });

    test('maps connection timeout DioException to NetworkException', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(
        () => ds.getCustomers('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('CustomerRemoteDatasourceImpl.getCustomer', () {
    test('parses full JSON shape correctly', () async {
      when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => resp(fullCustomerJson()));

      final customer = await ds.getCustomer('store-1', 'c1');

      expect(customer.id, 'c1');
      expect(customer.name, 'Ali');
      expect(customer.phone, '+992900000000');
      expect(customer.email, 'ali@example.com');
      expect(customer.birthday, DateTime.parse('2000-01-15T00:00:00.000Z'));
      expect(customer.notes, 'VIP customer');
      expect(customer.loyaltyPoints, 120);
      expect(customer.totalSpent, 4500.5);
      expect(customer.debt, 100);
      expect(customer.isActive, isTrue);
      expect(customer.telegramChatId, 'tg-123');
    });

    test('applies defaults for missing optional numeric/bool fields', () async {
      when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => resp(minimalCustomerJson()));

      final customer = await ds.getCustomer('store-1', 'c2');

      expect(customer.phone, isNull);
      expect(customer.email, isNull);
      expect(customer.birthday, isNull);
      expect(customer.notes, isNull);
      expect(customer.loyaltyPoints, 0);
      expect(customer.totalSpent, 0);
      expect(customer.debt, 0);
      expect(customer.isActive, isTrue);
      expect(customer.telegramChatId, isNull);
    });

    test('unwraps {"data": {...}} envelope shape', () async {
      when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => resp({'data': fullCustomerJson(id: 'c3')}));

      final customer = await ds.getCustomer('store-1', 'c3');

      expect(customer.id, 'c3');
    });

    test('throws ServerException when response body is not a map', () async {
      when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => resp('unexpected-string'));

      expect(
        () => ds.getCustomer('store-1', 'c1'),
        throwsA(isA<ServerException>()),
      );
    });

    test('maps 401 DioException to UnauthorizedException', () async {
      when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 401,
          data: {'message': 'Unauthorized'},
        ),
      ));

      expect(
        () => ds.getCustomer('store-1', 'c1'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('maps generic 500 DioException to ServerException with statusCode',
        () async {
      when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
          data: {'message': 'Boom'},
        ),
      ));

      try {
        await ds.getCustomer('store-1', 'c1');
        fail('should have thrown');
      } on ServerException catch (e) {
        expect(e.statusCode, 500);
        expect(e.message, 'Boom');
      }
    });

    test('joins list-shaped error message field with a comma', () async {
      when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 400,
          data: {
            'message': ['name is required', 'phone is invalid'],
          },
        ),
      ));

      try {
        await ds.getCustomer('store-1', 'c1');
        fail('should have thrown');
      } on ServerException catch (e) {
        expect(e.message, 'name is required, phone is invalid');
      }
    });
  });

  group('CustomerRemoteDatasourceImpl.createCustomer', () {
    test('posts data and returns the mapped customer', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(fullCustomerJson()));

      final customer =
          await ds.createCustomer('store-1', {'name': 'Ali'});

      expect(customer.id, 'c1');
      verify(() => dio.post<dynamic>(any(), data: {'name': 'Ali'})).called(1);
    });

    test('throws ServerException when response body is empty', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(null));

      expect(
        () => ds.createCustomer('store-1', {'name': 'Ali'}),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('CustomerRemoteDatasourceImpl.updateCustomer', () {
    test('puts data and returns the mapped customer', () async {
      when(() => dio.put<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(fullCustomerJson()));

      final customer =
          await ds.updateCustomer('store-1', 'c1', {'name': 'Ali 2'});

      expect(customer.id, 'c1');
    });

    test('maps DioException to ServerException', () async {
      when(() => dio.put<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
          data: {'message': 'Not found'},
        ),
      ));

      expect(
        () => ds.updateCustomer('store-1', 'c1', {'name': 'x'}),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('CustomerRemoteDatasourceImpl.deleteCustomer', () {
    test('calls delete endpoint successfully', () async {
      when(() => dio.delete<dynamic>(any()))
          .thenAnswer((_) async => resp(null));

      await ds.deleteCustomer('store-1', 'c1');

      verify(() => dio.delete<dynamic>(any())).called(1);
    });

    test('maps connection error DioException to NetworkException', () async {
      when(() => dio.delete<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ));

      expect(
        () => ds.deleteCustomer('store-1', 'c1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
