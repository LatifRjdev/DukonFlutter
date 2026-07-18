import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/store_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late StoreRemoteDatasourceImpl ds;

  setUp(() {
    dio = _MockDioClient();
    ds = StoreRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(dynamic body, {int statusCode = 200}) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: statusCode,
        data: body,
      );

  Map<String, dynamic> storeJson({
    String id = 'store-1',
    String? currency,
    String? address,
    String? phone,
    String? logoUrl,
    Map<String, dynamic>? settings,
    bool? isActive,
  }) => {
        'id': id,
        'ownerId': 'owner-1',
        'name': 'My Shop',
        'category': 'grocery',
        'currency': ?currency,
        'address': ?address,
        'phone': ?phone,
        'logoUrl': ?logoUrl,
        'settings': ?settings,
        'isActive': ?isActive,
        'createdAt': '2026-05-11T00:00:00.000Z',
      };

  group('StoreRemoteDatasourceImpl.getStores', () {
    test('parses a list of full store JSON objects', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp([
          storeJson(id: 'store-1', currency: 'USD', address: 'Main St'),
          storeJson(id: 'store-2'),
        ]),
      );

      final stores = await ds.getStores();

      expect(stores.length, 2);
      expect(stores[0].id, 'store-1');
      expect(stores[0].currency, 'USD');
      expect(stores[0].address, 'Main St');
      expect(stores[1].id, 'store-2');
      verify(() => dio.get<dynamic>('/stores')).called(1);
    });

    test('returns an empty list when the API returns an empty array',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer((_) async => resp([]));

      final stores = await ds.getStores();

      expect(stores, isEmpty);
    });

    test('throws NetworkException on connection timeout', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(() => ds.getStores(), throwsA(isA<NetworkException>()));
    });

    test('throws UnauthorizedException on 401 response', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Unauthorized'}, statusCode: 401),
      ));

      expect(() => ds.getStores(), throwsA(isA<UnauthorizedException>()));
    });

    test('throws ServerException with statusCode on 500 response', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Internal error'}, statusCode: 500),
      ));

      await expectLater(
        () => ds.getStores(),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('joins list-shaped error message with comma', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({
          'message': ['name is required', 'category is required'],
        }, statusCode: 400),
      ));

      await expectLater(
        () => ds.getStores(),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'name is required, category is required',
        )),
      );
    });
  });

  group('StoreRemoteDatasourceImpl.getStore', () {
    test('fills in defaults when optional fields are missing', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp(storeJson()),
      );

      final store = await ds.getStore('store-1');

      expect(store.currency, 'TJS');
      expect(store.address, isNull);
      expect(store.phone, isNull);
      expect(store.logoUrl, isNull);
      expect(store.settings, isEmpty);
      expect(store.isActive, isTrue);
      verify(() => dio.get<dynamic>('/stores/store-1')).called(1);
    });

    test('parses settings map and explicit isActive=false when present',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp(storeJson(
          settings: {'receiptFooter': 'Thanks!'},
          isActive: false,
        )),
      );

      final store = await ds.getStore('store-1');

      expect(store.settings, {'receiptFooter': 'Thanks!'});
      expect(store.isActive, isFalse);
    });

    test('throws ServerException with statusCode on 404 response', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Not found'}, statusCode: 404),
      ));

      await expectLater(
        () => ds.getStore('missing'),
        throwsA(
            isA<ServerException>().having((e) => e.statusCode, 's', 404)),
      );
    });
  });

  group('StoreRemoteDatasourceImpl.createStore', () {
    test('omits address/phone keys from the payload when not provided',
        () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(storeJson()));

      await ds.createStore(name: 'My Shop', category: 'grocery');

      final captured = verify(() => dio.post<dynamic>(
            '/stores',
            data: captureAny(named: 'data'),
          )).captured;
      final payload = captured.single as Map<String, dynamic>;
      expect(payload['name'], 'My Shop');
      expect(payload['category'], 'grocery');
      expect(payload['currency'], 'TJS');
      expect(payload.containsKey('address'), isFalse);
      expect(payload.containsKey('phone'), isFalse);
    });

    test('includes address/phone in the payload when provided', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(storeJson()));

      await ds.createStore(
        name: 'My Shop',
        category: 'grocery',
        currency: 'USD',
        address: 'Main St 1',
        phone: '+992900000000',
      );

      final captured = verify(() => dio.post<dynamic>(
            '/stores',
            data: captureAny(named: 'data'),
          )).captured;
      final payload = captured.single as Map<String, dynamic>;
      expect(payload['currency'], 'USD');
      expect(payload['address'], 'Main St 1');
      expect(payload['phone'], '+992900000000');
    });

    test('parses and returns the created store from the response', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(storeJson(id: 'new-store')));

      final store =
          await ds.createStore(name: 'My Shop', category: 'grocery');

      expect(store.id, 'new-store');
    });

    test('throws ServerException with statusCode on 409 conflict', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Store already exists'}, statusCode: 409),
      ));

      await expectLater(
        () => ds.createStore(name: 'My Shop', category: 'grocery'),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('throws NetworkException on connection error', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ));

      expect(
        () => ds.createStore(name: 'My Shop', category: 'grocery'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('StoreRemoteDatasourceImpl.updateStore', () {
    test('sends the given data map and parses the updated store', () async {
      when(() => dio.put<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(storeJson(address: 'New Address')));

      final store =
          await ds.updateStore('store-1', {'address': 'New Address'});

      expect(store.address, 'New Address');
      verify(() => dio.put<dynamic>(
            '/stores/store-1',
            data: {'address': 'New Address'},
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
        () => ds.updateStore('store-1', {'address': 'x'}),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('StoreRemoteDatasourceImpl.deleteStore', () {
    test('calls delete on the correct endpoint', () async {
      when(() => dio.delete<dynamic>(any()))
          .thenAnswer((_) async => resp(null));

      await ds.deleteStore('store-1');

      verify(() => dio.delete<dynamic>('/stores/store-1')).called(1);
    });

    test('throws ServerException with statusCode on 500 response', () async {
      when(() => dio.delete<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Internal error'}, statusCode: 500),
      ));

      await expectLater(
        () => ds.deleteStore('store-1'),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('throws NetworkException on receive timeout', () async {
      when(() => dio.delete<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.receiveTimeout,
      ));

      expect(
        () => ds.deleteStore('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
