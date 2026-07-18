import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/data/datasources/remote/store_remote_datasource.dart';
import 'package:dukonpro/data/repositories/store_repository_impl.dart';
import 'package:dukonpro/domain/entities/store.dart';

class _MockStoreRemoteDatasource extends Mock
    implements StoreRemoteDatasource {}

void main() {
  late StoreRepositoryImpl repo;
  late _MockStoreRemoteDatasource remote;

  Store buildStore({String id = 'store-1'}) => Store(
        id: id,
        ownerId: 'owner-1',
        name: 'My Shop',
        category: 'grocery',
        createdAt: DateTime(2026, 1, 1),
      );

  setUp(() {
    remote = _MockStoreRemoteDatasource();
    repo = StoreRepositoryImpl(remoteDatasource: remote);
  });

  group('StoreRepositoryImpl.createStore', () {
    test('delegates to remote datasource and returns its result', () async {
      final store = buildStore();
      when(() => remote.createStore(
            name: any(named: 'name'),
            category: any(named: 'category'),
            currency: any(named: 'currency'),
            address: any(named: 'address'),
            phone: any(named: 'phone'),
          )).thenAnswer((_) async => store);

      final result = await repo.createStore(name: 'My Shop', category: 'grocery');

      expect(result, store);
    });

    test('passes name/category/currency/address/phone through unchanged',
        () async {
      when(() => remote.createStore(
            name: any(named: 'name'),
            category: any(named: 'category'),
            currency: any(named: 'currency'),
            address: any(named: 'address'),
            phone: any(named: 'phone'),
          )).thenAnswer((_) async => buildStore());

      await repo.createStore(
        name: 'My Shop',
        category: 'grocery',
        currency: 'USD',
        address: 'Main St 1',
        phone: '+992900000000',
      );

      verify(() => remote.createStore(
            name: 'My Shop',
            category: 'grocery',
            currency: 'USD',
            address: 'Main St 1',
            phone: '+992900000000',
          )).called(1);
    });

    test('defaults currency to TJS when not supplied', () async {
      when(() => remote.createStore(
            name: any(named: 'name'),
            category: any(named: 'category'),
            currency: any(named: 'currency'),
            address: any(named: 'address'),
            phone: any(named: 'phone'),
          )).thenAnswer((_) async => buildStore());

      await repo.createStore(name: 'My Shop', category: 'grocery');

      verify(() => remote.createStore(
            name: 'My Shop',
            category: 'grocery',
            currency: 'TJS',
            address: null,
            phone: null,
          )).called(1);
    });

    test('propagates NetworkException from the remote datasource', () async {
      when(() => remote.createStore(
            name: any(named: 'name'),
            category: any(named: 'category'),
            currency: any(named: 'currency'),
            address: any(named: 'address'),
            phone: any(named: 'phone'),
          )).thenThrow(const NetworkException());

      expect(
        () => repo.createStore(name: 'My Shop', category: 'grocery'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('propagates ServerException from the remote datasource', () async {
      when(() => remote.createStore(
            name: any(named: 'name'),
            category: any(named: 'category'),
            currency: any(named: 'currency'),
            address: any(named: 'address'),
            phone: any(named: 'phone'),
          )).thenThrow(const ServerException('boom', statusCode: 409));

      expect(
        () => repo.createStore(name: 'My Shop', category: 'grocery'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('StoreRepositoryImpl.getStores', () {
    test('delegates to remote datasource and returns its result', () async {
      final stores = [buildStore(id: 's1'), buildStore(id: 's2')];
      when(() => remote.getStores()).thenAnswer((_) async => stores);

      final result = await repo.getStores();

      expect(result, stores);
    });

    test('propagates NetworkException from the remote datasource', () async {
      when(() => remote.getStores()).thenThrow(const NetworkException());

      expect(() => repo.getStores(), throwsA(isA<NetworkException>()));
    });
  });

  group('StoreRepositoryImpl.getStore', () {
    test('delegates the id and returns the remote result', () async {
      final store = buildStore(id: 'store-9');
      when(() => remote.getStore(any())).thenAnswer((_) async => store);

      final result = await repo.getStore('store-9');

      expect(result, store);
      verify(() => remote.getStore('store-9')).called(1);
    });

    test('propagates ServerException with statusCode 404', () async {
      when(() => remote.getStore(any()))
          .thenThrow(const ServerException('Not found', statusCode: 404));

      expect(
        () => repo.getStore('missing'),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('StoreRepositoryImpl.updateStore', () {
    test('passes id and data through and returns updated store', () async {
      final store = buildStore(id: 'store-1');
      when(() => remote.updateStore(any(), any()))
          .thenAnswer((_) async => store);

      final result =
          await repo.updateStore('store-1', {'address': 'New Address'});

      expect(result, store);
      verify(() => remote.updateStore('store-1', {'address': 'New Address'}))
          .called(1);
    });

    test('propagates UnauthorizedException from the remote datasource',
        () async {
      when(() => remote.updateStore(any(), any()))
          .thenThrow(const UnauthorizedException());

      expect(
        () => repo.updateStore('store-1', {'address': 'x'}),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('StoreRepositoryImpl.deleteStore', () {
    test('delegates the id to the remote datasource', () async {
      when(() => remote.deleteStore(any())).thenAnswer((_) async {});

      await repo.deleteStore('store-1');

      verify(() => remote.deleteStore('store-1')).called(1);
    });

    test('propagates ServerException from the remote datasource', () async {
      when(() => remote.deleteStore(any()))
          .thenThrow(const ServerException('boom', statusCode: 500));

      expect(
        () => repo.deleteStore('store-1'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
