import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/data/repositories/supplier_repository_impl.dart';
import 'package:dukonpro/data/sync/sync_queue.dart';

class _MockDioClient extends Mock implements DioClient {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

class _MockSyncQueue extends Mock implements SyncQueue {}

Response<dynamic> _response(dynamic data) =>
    Response(data: data, requestOptions: RequestOptions(path: '/x'));

void main() {
  late SupplierRepositoryImpl repo;
  late _MockDioClient dioClient;
  late _MockNetworkInfo networkInfo;
  late _MockSyncQueue syncQueue;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    dioClient = _MockDioClient();
    networkInfo = _MockNetworkInfo();
    syncQueue = _MockSyncQueue();
    repo = SupplierRepositoryImpl(
      dioClient: dioClient,
      networkInfo: networkInfo,
      syncQueue: syncQueue,
    );

    when(() => syncQueue.enqueue(
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          operation: any(named: 'operation'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async => 1);
  });

  group('SupplierRepositoryImpl.getSuppliers', () {
    test('parses a paginated envelope response', () async {
      when(() => dioClient.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _response({
                'data': [
                  {'id': 's1', 'storeId': 'store-1', 'name': 'ACME', 'debt': 10},
                  {'id': 's2', 'storeId': 'store-1', 'name': 'Beta'},
                ],
                'total': 2,
                'totalPages': 1,
              }));

      final result = await repo.getSuppliers('store-1');

      expect(result.data, hasLength(2));
      expect(result.data[0].id, 's1');
      expect(result.data[0].debt, 10);
      expect(result.data[1].debt, 0);
      expect(result.total, 2);
      expect(result.totalPages, 1);
    });

    test('passes page, limit and search as query parameters', () async {
      when(() => dioClient.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _response({'data': [], 'total': 0, 'totalPages': 0}));

      await repo.getSuppliers('store-1', page: 2, limit: 10, search: 'acme');

      final captured = verify(() => dioClient.get(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['page'], 2);
      expect(params['limit'], 10);
      expect(params['search'], 'acme');
    });

    test('omits search query parameter when search is null', () async {
      when(() => dioClient.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _response({'data': [], 'total': 0, 'totalPages': 0}));

      await repo.getSuppliers('store-1');

      final captured = verify(() => dioClient.get(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params.containsKey('search'), isFalse);
    });

    test('omits search query parameter when search is empty', () async {
      when(() => dioClient.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _response({'data': [], 'total': 0, 'totalPages': 0}));

      await repo.getSuppliers('store-1', search: '');

      final captured = verify(() => dioClient.get(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params.containsKey('search'), isFalse);
    });

    test('maps a bare list response shape', () async {
      when(() => dioClient.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _response([
                {'id': 's1', 'storeId': 'store-1', 'name': 'ACME'},
              ]));

      final result = await repo.getSuppliers('store-1');

      expect(result.data, hasLength(1));
      expect(result.total, 1);
    });

    test('throws NetworkException on connection timeout', () async {
      when(() => dioClient.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(() => repo.getSuppliers('store-1'), throwsA(isA<NetworkException>()));
    });

    test('throws ServerException with status code on non-2xx response', () async {
      when(() => dioClient.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.badResponse,
        response: Response(
          data: {'message': 'Not found'},
          statusCode: 404,
          requestOptions: RequestOptions(path: '/x'),
        ),
      ));

      await expectLater(
        () => repo.getSuppliers('store-1'),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', 'Not found')),
      );
    });

    test('throws UnauthorizedException on 401 response', () async {
      when(() => dioClient.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.badResponse,
        response: Response(
          data: {'message': 'Token expired'},
          statusCode: 401,
          requestOptions: RequestOptions(path: '/x'),
        ),
      ));

      expect(() => repo.getSuppliers('store-1'), throwsA(isA<UnauthorizedException>()));
    });
  });

  group('SupplierRepositoryImpl.getSupplier', () {
    test('parses a plain object response', () async {
      when(() => dioClient.get(any())).thenAnswer((_) async => _response({
            'id': 's1',
            'storeId': 'store-1',
            'name': 'ACME',
            'phone': '+992900000000',
            'debt': 50,
          }));

      final supplier = await repo.getSupplier('store-1', 's1');

      expect(supplier.id, 's1');
      expect(supplier.name, 'ACME');
      expect(supplier.phone, '+992900000000');
      expect(supplier.debt, 50);
    });

    test('unwraps a data-wrapped object response', () async {
      when(() => dioClient.get(any())).thenAnswer((_) async => _response({
            'data': {'id': 's1', 'storeId': 'store-1', 'name': 'ACME'},
          }));

      final supplier = await repo.getSupplier('store-1', 's1');

      expect(supplier.id, 's1');
    });

    test('defaults optional fields to null and debt to 0 when absent', () async {
      when(() => dioClient.get(any())).thenAnswer((_) async => _response({
            'id': 's1',
            'storeId': 'store-1',
            'name': 'ACME',
          }));

      final supplier = await repo.getSupplier('store-1', 's1');

      expect(supplier.phone, isNull);
      expect(supplier.email, isNull);
      expect(supplier.address, isNull);
      expect(supplier.notes, isNull);
      expect(supplier.debt, 0);
    });

    test('throws ServerException when response body is not a map', () async {
      when(() => dioClient.get(any())).thenAnswer((_) async => _response('unexpected'));

      expect(() => repo.getSupplier('store-1', 's1'), throwsA(isA<ServerException>()));
    });

    test('throws ServerException for 5xx responses', () async {
      when(() => dioClient.get(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.badResponse,
        response: Response(
          statusCode: 500,
          requestOptions: RequestOptions(path: '/x'),
        ),
      ));

      await expectLater(
        () => repo.getSupplier('store-1', 's1'),
        throwsA(isA<ServerException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });

  group('SupplierRepositoryImpl.createSupplier', () {
    test('posts to the API and returns the created supplier when online', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => dioClient.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _response({
                'id': 's1',
                'storeId': 'store-1',
                'name': 'ACME',
              }));

      final supplier = await repo.createSupplier('store-1', {'name': 'ACME'});

      expect(supplier.id, 's1');
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test('enqueues a CREATE sync op and returns a temp supplier when offline', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final supplier = await repo.createSupplier('store-1', {
        'name': 'ACME',
        'phone': '+992900000000',
      });

      expect(supplier.id, startsWith('temp_'));
      expect(supplier.storeId, 'store-1');
      expect(supplier.name, 'ACME');
      expect(supplier.phone, '+992900000000');

      final captured = verify(() => syncQueue.enqueue(
            entityType: 'supplier',
            entityId: captureAny(named: 'entityId'),
            operation: 'CREATE',
            payload: any(named: 'payload'),
          )).captured;
      expect(captured.single, startsWith('store-1:temp_'));
    });

    test('offline temp supplier falls back to empty name when missing', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final supplier = await repo.createSupplier('store-1', {});

      expect(supplier.name, isEmpty);
    });

    test('throws NetworkException on connection error while online-check succeeds', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => dioClient.post(any(), data: any(named: 'data'))).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      ));

      expect(
        () => repo.createSupplier('store-1', {'name': 'ACME'}),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('SupplierRepositoryImpl.updateSupplier', () {
    test('puts to the API and returns the updated supplier when online', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => dioClient.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _response({
                'id': 's1',
                'storeId': 'store-1',
                'name': 'ACME Updated',
              }));

      final supplier = await repo.updateSupplier('store-1', 's1', {'name': 'ACME Updated'});

      expect(supplier.name, 'ACME Updated');
    });

    test('enqueues an UPDATE sync op and throws NetworkException when offline', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      await expectLater(
        () => repo.updateSupplier('store-1', 's1', {'name': 'ACME Updated'}),
        throwsA(isA<NetworkException>()),
      );

      verify(() => syncQueue.enqueue(
            entityType: 'supplier',
            entityId: 'store-1:s1',
            operation: 'UPDATE',
            payload: {'name': 'ACME Updated'},
          )).called(1);
    });

    test('throws ServerException when update response body is not a map', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => dioClient.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _response(null));

      expect(
        () => repo.updateSupplier('store-1', 's1', {'name': 'ACME'}),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('SupplierRepositoryImpl.deleteSupplier', () {
    test('deletes via the API when online', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => dioClient.delete(any())).thenAnswer((_) async => _response(null));

      await repo.deleteSupplier('store-1', 's1');

      verify(() => dioClient.delete(any())).called(1);
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test('enqueues a DELETE sync op when offline', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      await repo.deleteSupplier('store-1', 's1');

      verify(() => syncQueue.enqueue(
            entityType: 'supplier',
            entityId: 'store-1:s1',
            operation: 'DELETE',
            payload: null,
          )).called(1);
      verifyNever(() => dioClient.delete(any()));
    });

    test('throws NetworkException on timeout while online-check succeeds', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => dioClient.delete(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.sendTimeout,
      ));

      expect(() => repo.deleteSupplier('store-1', 's1'), throwsA(isA<NetworkException>()));
    });
  });
}
