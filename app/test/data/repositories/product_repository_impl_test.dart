import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/data/datasources/local/product_local_datasource.dart';
import 'package:dukonpro/data/datasources/remote/product_remote_datasource.dart';
import 'package:dukonpro/data/repositories/product_repository_impl.dart';
import 'package:dukonpro/data/sync/sync_queue.dart';
import 'package:dukonpro/domain/entities/product.dart';

class _MockRemote extends Mock implements ProductRemoteDatasource {}

class _MockLocal extends Mock implements ProductLocalDatasource {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

class _MockSyncQueue extends Mock implements SyncQueue {}

class _FakeProduct extends Fake implements Product {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeProduct());
  });

  late _MockRemote remote;
  late _MockLocal local;
  late _MockNetworkInfo network;
  late _MockSyncQueue syncQueue;
  late ProductRepositoryImpl repo;

  Product mkProduct({String id = 'p1', String storeId = 'store-1'}) => Product(
        id: id,
        storeId: storeId,
        name: 'Apple',
        sellPrice: 12.5,
        createdAt: DateTime.utc(2026, 4, 1),
      );

  setUp(() {
    remote = _MockRemote();
    local = _MockLocal();
    network = _MockNetworkInfo();
    syncQueue = _MockSyncQueue();
    repo = ProductRepositoryImpl(
      remoteDatasource: remote,
      localDatasource: local,
      networkInfo: network,
      syncQueue: syncQueue,
    );

    when(() => local.saveProducts(any())).thenAnswer((_) async {});
    when(() => local.saveProduct(any())).thenAnswer((_) async {});
    when(() => local.deleteProduct(any())).thenAnswer((_) async {});
    when(() => syncQueue.enqueue(
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          operation: any(named: 'operation'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});
  });

  group('ProductRepositoryImpl', () {
    test('getProducts returns local cache when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      final cached = [mkProduct(id: 'p1'), mkProduct(id: 'p2')];
      when(() => local.getProducts('store-1')).thenAnswer((_) async => cached);

      final result = await repo.getProducts('store-1');

      expect(result.data, cached);
      expect(result.total, 2);
      expect(result.totalPages, 1);
      // Critical: no remote call when offline.
      verifyNever(() => remote.getProducts(any(),
          page: any(named: 'page'),
          limit: any(named: 'limit'),
          search: any(named: 'search'),
          categoryId: any(named: 'categoryId'),
          inStock: any(named: 'inStock'),
          lowStock: any(named: 'lowStock'),
          sortBy: any(named: 'sortBy'),
          sortOrder: any(named: 'sortOrder')));
    });

    test('getProducts hits remote when online and caches first page locally',
        () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      final remoteProducts = [mkProduct(id: 'p1'), mkProduct(id: 'p2')];
      when(() => remote.getProducts(
            'store-1',
            page: 1,
            limit: 20,
            search: null,
            categoryId: null,
            inStock: null,
            lowStock: null,
            sortBy: null,
            sortOrder: null,
          )).thenAnswer((_) async => (
            data: remoteProducts,
            total: 2,
            totalPages: 1,
          ));

      final result = await repo.getProducts('store-1');

      expect(result.data, remoteProducts);
      expect(result.total, 2);
      // First page with no filter must populate local cache for offline reads.
      verify(() => local.saveProducts(remoteProducts)).called(1);
    });

    test('createProduct enqueues sync queue item with composite id when offline',
        () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final created = await repo.createProduct('store-1', {
        'name': 'New SKU',
        'sellPrice': 10,
      });

      // Optimistic local product persisted immediately.
      expect(created.storeId, 'store-1');
      expect(created.name, 'New SKU');
      expect(created.id, startsWith('temp_'));
      verify(() => local.saveProduct(any())).called(1);

      // Composite id passed to sync queue must follow "storeId:entityId".
      final captured = verify(() => syncQueue.enqueue(
            entityType: 'product',
            entityId: captureAny(named: 'entityId'),
            operation: 'CREATE',
            payload: any(named: 'payload'),
          )).captured;
      expect(captured.single, startsWith('store-1:temp_'));
    });

    test('createProduct posts to remote when online and caches result', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      final remoteProduct = mkProduct(id: 'real-id');
      when(() => remote.createProduct('store-1', any()))
          .thenAnswer((_) async => remoteProduct);

      final created = await repo.createProduct('store-1', {
        'name': 'Apple',
        'sellPrice': 12.5,
      });

      expect(created, remoteProduct);
      verify(() => remote.createProduct('store-1', any())).called(1);
      verify(() => local.saveProduct(remoteProduct)).called(1);
      // Online path must NOT enqueue — that would double-write on next sync.
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test('deleteProduct soft-deletes locally and enqueues DELETE when offline',
        () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      await repo.deleteProduct('store-1', 'p1');

      verify(() => local.deleteProduct('p1')).called(1);
      verify(() => syncQueue.enqueue(
            entityType: 'product',
            entityId: 'store-1:p1',
            operation: 'DELETE',
            payload: any(named: 'payload'),
          )).called(1);
      // No remote call while offline.
      verifyNever(() => remote.deleteProduct(any(), any()));
    });

    test('deleteProduct hits remote and clears local cache when online',
        () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.deleteProduct('store-1', 'p1'))
          .thenAnswer((_) async {});

      await repo.deleteProduct('store-1', 'p1');

      verify(() => remote.deleteProduct('store-1', 'p1')).called(1);
      verify(() => local.deleteProduct('p1')).called(1);
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });
  });
}
