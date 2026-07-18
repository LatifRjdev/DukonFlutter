import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/data/datasources/local/category_local_datasource.dart';
import 'package:dukonpro/data/datasources/remote/category_remote_datasource.dart';
import 'package:dukonpro/data/repositories/category_repository_impl.dart';
import 'package:dukonpro/data/sync/sync_queue.dart';
import 'package:dukonpro/domain/entities/category.dart';

class _MockRemote extends Mock implements CategoryRemoteDatasource {}

class _MockLocal extends Mock implements CategoryLocalDatasource {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

class _MockSyncQueue extends Mock implements SyncQueue {}

class _FakeCategory extends Fake implements Category {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeCategory());
  });

  late _MockRemote remote;
  late _MockLocal local;
  late _MockNetworkInfo network;
  late _MockSyncQueue syncQueue;
  late CategoryRepositoryImpl repo;

  Category mkCategory({String id = 'c1', String storeId = 'store-1', String name = 'Drinks'}) =>
      Category(id: id, storeId: storeId, name: name);

  setUp(() {
    remote = _MockRemote();
    local = _MockLocal();
    network = _MockNetworkInfo();
    syncQueue = _MockSyncQueue();
    repo = CategoryRepositoryImpl(
      remoteDatasource: remote,
      localDatasource: local,
      networkInfo: network,
      syncQueue: syncQueue,
    );

    when(() => local.saveCategories(any())).thenAnswer((_) async {});
    when(() => local.saveCategory(any())).thenAnswer((_) async {});
    when(() => local.deleteCategory(any())).thenAnswer((_) async {});
    when(() => syncQueue.enqueue(
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          operation: any(named: 'operation'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});
  });

  group('CategoryRepositoryImpl.getCategories', () {
    test('returns local cache when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      final cached = [mkCategory(id: 'c1'), mkCategory(id: 'c2')];
      when(() => local.getCategories('store-1')).thenAnswer((_) async => cached);

      final result = await repo.getCategories('store-1');

      expect(result, cached);
      verifyNever(() => remote.getCategories(any()));
    });

    test('hits remote when online and caches the result locally', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      final remoteCategories = [mkCategory(id: 'c1'), mkCategory(id: 'c2')];
      when(() => remote.getCategories('store-1')).thenAnswer((_) async => remoteCategories);

      final result = await repo.getCategories('store-1');

      expect(result, remoteCategories);
      verify(() => local.saveCategories(remoteCategories)).called(1);
    });

    test('falls back to local cache when remote throws NetworkException', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.getCategories('store-1')).thenThrow(const NetworkException());
      final cached = [mkCategory(id: 'c1')];
      when(() => local.getCategories('store-1')).thenAnswer((_) async => cached);

      final result = await repo.getCategories('store-1');

      expect(result, cached);
    });
  });

  group('CategoryRepositoryImpl.createCategory', () {
    test('enqueues sync queue item with composite id when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final created = await repo.createCategory('store-1', {
        'name': 'New Category',
        'icon': 'drink',
        'color': '#FF0000',
        'sortOrder': 3,
        'parentId': 'p1',
      });

      expect(created.storeId, 'store-1');
      expect(created.name, 'New Category');
      expect(created.icon, 'drink');
      expect(created.color, '#FF0000');
      expect(created.sortOrder, 3);
      expect(created.parentId, 'p1');
      expect(created.id, startsWith('temp_'));
      verify(() => local.saveCategory(any())).called(1);

      final captured = verify(() => syncQueue.enqueue(
            entityType: 'category',
            entityId: captureAny(named: 'entityId'),
            operation: 'CREATE',
            payload: any(named: 'payload'),
          )).captured;
      expect(captured.single, startsWith('store-1:temp_'));
    });

    test('posts to remote when online and caches result, without enqueueing', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      final remoteCategory = mkCategory(id: 'real-id');
      when(() => remote.createCategory('store-1', any())).thenAnswer((_) async => remoteCategory);

      final created = await repo.createCategory('store-1', {'name': 'Drinks'});

      expect(created, remoteCategory);
      verify(() => remote.createCategory('store-1', any())).called(1);
      verify(() => local.saveCategory(remoteCategory)).called(1);
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test('falls back to offline queueing when remote throws NetworkException', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.createCategory('store-1', any())).thenThrow(const NetworkException());

      final created = await repo.createCategory('store-1', {'name': 'Drinks'});

      expect(created.id, startsWith('temp_'));
      expect(created.name, 'Drinks');
      verify(() => local.saveCategory(any())).called(1);
      verify(() => syncQueue.enqueue(
            entityType: 'category',
            entityId: any(named: 'entityId'),
            operation: 'CREATE',
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('defaults name to empty string when missing from payload while offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final created = await repo.createCategory('store-1', {});

      expect(created.name, '');
      expect(created.sortOrder, 0);
    });
  });

  group('CategoryRepositoryImpl.updateCategory', () {
    test('enqueues UPDATE and returns local copy when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      final localCategory = mkCategory(id: 'c1', name: 'Updated');
      when(() => local.getCategory('c1')).thenAnswer((_) async => localCategory);

      final result = await repo.updateCategory('store-1', 'c1', {'name': 'Updated'});

      expect(result, localCategory);
      verify(() => syncQueue.enqueue(
            entityType: 'category',
            entityId: 'store-1:c1',
            operation: 'UPDATE',
            payload: any(named: 'payload'),
          )).called(1);
      verifyNever(() => remote.updateCategory(any(), any(), any()));
    });

    test('throws CacheException when offline and category missing locally', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      when(() => local.getCategory('missing')).thenAnswer((_) async => null);

      expect(
        () => repo.updateCategory('store-1', 'missing', {'name': 'x'}),
        throwsA(isA<CacheException>()),
      );
    });

    test('puts to remote when online and caches result', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      final updated = mkCategory(id: 'c1', name: 'Updated');
      when(() => remote.updateCategory('store-1', 'c1', any())).thenAnswer((_) async => updated);

      final result = await repo.updateCategory('store-1', 'c1', {'name': 'Updated'});

      expect(result, updated);
      verify(() => local.saveCategory(updated)).called(1);
    });

    test('falls back to offline queueing when remote throws NetworkException', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.updateCategory('store-1', 'c1', any())).thenThrow(const NetworkException());
      final localCategory = mkCategory(id: 'c1', name: 'Cached');
      when(() => local.getCategory('c1')).thenAnswer((_) async => localCategory);

      final result = await repo.updateCategory('store-1', 'c1', {'name': 'Updated'});

      expect(result, localCategory);
      verify(() => syncQueue.enqueue(
            entityType: 'category',
            entityId: 'store-1:c1',
            operation: 'UPDATE',
            payload: any(named: 'payload'),
          )).called(1);
    });
  });

  group('CategoryRepositoryImpl.deleteCategory', () {
    test('deletes locally and enqueues DELETE when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      await repo.deleteCategory('store-1', 'c1');

      verify(() => local.deleteCategory('c1')).called(1);
      verify(() => syncQueue.enqueue(
            entityType: 'category',
            entityId: 'store-1:c1',
            operation: 'DELETE',
            payload: any(named: 'payload'),
          )).called(1);
      verifyNever(() => remote.deleteCategory(any(), any()));
    });

    test('deletes remotely and clears local cache when online', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.deleteCategory('store-1', 'c1')).thenAnswer((_) async {});

      await repo.deleteCategory('store-1', 'c1');

      verify(() => remote.deleteCategory('store-1', 'c1')).called(1);
      verify(() => local.deleteCategory('c1')).called(1);
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test('falls back to offline delete queueing when remote throws NetworkException', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.deleteCategory('store-1', 'c1')).thenThrow(const NetworkException());

      await repo.deleteCategory('store-1', 'c1');

      verify(() => local.deleteCategory('c1')).called(1);
      verify(() => syncQueue.enqueue(
            entityType: 'category',
            entityId: 'store-1:c1',
            operation: 'DELETE',
            payload: any(named: 'payload'),
          )).called(1);
    });
  });
}
