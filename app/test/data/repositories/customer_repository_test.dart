import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/data/datasources/remote/customer_remote_datasource.dart';
import 'package:dukonpro/data/repositories/customer_repository_impl.dart';
import 'package:dukonpro/data/sync/sync_queue.dart';
import 'package:dukonpro/domain/entities/customer.dart';

class _MockRemote extends Mock implements CustomerRemoteDatasource {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

class _MockSyncQueue extends Mock implements SyncQueue {}

void main() {
  late _MockRemote remote;
  late _MockNetworkInfo network;
  late _MockSyncQueue syncQueue;
  late CustomerRepositoryImpl repo;

  Customer mkCustomer({String id = 'c1', String storeId = 'store-1'}) =>
      Customer(id: id, storeId: storeId, name: 'Ali', debt: 0);

  setUp(() {
    remote = _MockRemote();
    network = _MockNetworkInfo();
    syncQueue = _MockSyncQueue();
    repo = CustomerRepositoryImpl(
      remoteDatasource: remote,
      networkInfo: network,
      syncQueue: syncQueue,
    );

    when(() => syncQueue.enqueue(
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          operation: any(named: 'operation'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});
  });

  group('CustomerRepositoryImpl.getCustomers', () {
    test('delegates to remote datasource and returns its result', () async {
      final customers = [mkCustomer(id: 'c1'), mkCustomer(id: 'c2')];
      when(() => remote.getCustomers(
            'store-1',
            page: 1,
            limit: 20,
            search: null,
          )).thenAnswer((_) async => (
            data: customers,
            total: 2,
            totalPages: 1,
          ));

      final result = await repo.getCustomers('store-1');

      expect(result.data, customers);
      expect(result.total, 2);
      expect(result.totalPages, 1);
    });

    test('forwards page/limit/search to remote datasource', () async {
      when(() => remote.getCustomers(
            'store-1',
            page: 2,
            limit: 10,
            search: 'ali',
          )).thenAnswer((_) async => (
            data: <Customer>[],
            total: 0,
            totalPages: 0,
          ));

      await repo.getCustomers('store-1', page: 2, limit: 10, search: 'ali');

      verify(() => remote.getCustomers(
            'store-1',
            page: 2,
            limit: 10,
            search: 'ali',
          )).called(1);
    });
  });

  group('CustomerRepositoryImpl.getCustomer', () {
    test('delegates to remote datasource', () async {
      final customer = mkCustomer(id: 'c1');
      when(() => remote.getCustomer('store-1', 'c1'))
          .thenAnswer((_) async => customer);

      final result = await repo.getCustomer('store-1', 'c1');

      expect(result, customer);
    });
  });

  group('CustomerRepositoryImpl.createCustomer', () {
    test('posts to remote when online and does not enqueue', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      final created = mkCustomer(id: 'real-id');
      when(() => remote.createCustomer('store-1', any()))
          .thenAnswer((_) async => created);

      final result = await repo.createCustomer('store-1', {'name': 'Ali'});

      expect(result, created);
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test(
        'enqueues CREATE with composite temp id and returns optimistic '
        'customer when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final result = await repo.createCustomer('store-1', {
        'name': 'Ali',
        'phone': '+992900000000',
        'email': 'ali@example.com',
        'notes': 'VIP',
      });

      expect(result.storeId, 'store-1');
      expect(result.name, 'Ali');
      expect(result.phone, '+992900000000');
      expect(result.email, 'ali@example.com');
      expect(result.notes, 'VIP');
      expect(result.id, startsWith('temp_'));

      final captured = verify(() => syncQueue.enqueue(
            entityType: 'customer',
            entityId: captureAny(named: 'entityId'),
            operation: 'CREATE',
            payload: {
              'name': 'Ali',
              'phone': '+992900000000',
              'email': 'ali@example.com',
              'notes': 'VIP',
            },
          )).captured;
      expect(captured.single, startsWith('store-1:temp_'));
    });

    test('falls back to empty name when offline payload has no name',
        () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final result = await repo.createCustomer('store-1', {});

      expect(result.name, '');
    });

    test('enqueues CREATE and returns optimistic customer on NetworkException',
        () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.createCustomer('store-1', any()))
          .thenThrow(const NetworkException());

      final result = await repo.createCustomer('store-1', {
        'name': 'Ali',
        'phone': '+992900000000',
      });

      expect(result.id, startsWith('temp_'));
      expect(result.name, 'Ali');
      expect(result.phone, '+992900000000');
      verify(() => syncQueue.enqueue(
            entityType: 'customer',
            entityId: any(named: 'entityId'),
            operation: 'CREATE',
            payload: any(named: 'payload'),
          )).called(1);
    });
  });

  group('CustomerRepositoryImpl.updateCustomer', () {
    test('puts to remote when online and does not enqueue', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      final updated = mkCustomer(id: 'c1');
      when(() => remote.updateCustomer('store-1', 'c1', any()))
          .thenAnswer((_) async => updated);

      final result =
          await repo.updateCustomer('store-1', 'c1', {'name': 'Ali 2'});

      expect(result, updated);
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test(
        'enqueues UPDATE with composite id and returns best-effort remote '
        'fetch when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      final existing = mkCustomer(id: 'c1');
      when(() => remote.getCustomer('store-1', 'c1'))
          .thenAnswer((_) async => existing);

      final result =
          await repo.updateCustomer('store-1', 'c1', {'name': 'Ali 2'});

      expect(result, existing);
      verify(() => syncQueue.enqueue(
            entityType: 'customer',
            entityId: 'store-1:c1',
            operation: 'UPDATE',
            payload: {'name': 'Ali 2'},
          )).called(1);
    });

    test('enqueues UPDATE and rethrows on NetworkException', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.updateCustomer('store-1', 'c1', any()))
          .thenThrow(const NetworkException());

      await expectLater(
        () => repo.updateCustomer('store-1', 'c1', {'name': 'Ali 2'}),
        throwsA(isA<NetworkException>()),
      );

      verify(() => syncQueue.enqueue(
            entityType: 'customer',
            entityId: 'store-1:c1',
            operation: 'UPDATE',
            payload: {'name': 'Ali 2'},
          )).called(1);
    });
  });

  group('CustomerRepositoryImpl.deleteCustomer', () {
    test('calls remote when online and does not enqueue', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.deleteCustomer('store-1', 'c1'))
          .thenAnswer((_) async {});

      await repo.deleteCustomer('store-1', 'c1');

      verify(() => remote.deleteCustomer('store-1', 'c1')).called(1);
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test('enqueues DELETE with composite id when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      await repo.deleteCustomer('store-1', 'c1');

      verify(() => syncQueue.enqueue(
            entityType: 'customer',
            entityId: 'store-1:c1',
            operation: 'DELETE',
            payload: any(named: 'payload'),
          )).called(1);
      verifyNever(() => remote.deleteCustomer(any(), any()));
    });

    test('swallows NetworkException and enqueues DELETE instead', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.deleteCustomer('store-1', 'c1'))
          .thenThrow(const NetworkException());

      await repo.deleteCustomer('store-1', 'c1');

      verify(() => syncQueue.enqueue(
            entityType: 'customer',
            entityId: 'store-1:c1',
            operation: 'DELETE',
            payload: any(named: 'payload'),
          )).called(1);
    });
  });
}
