import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/data/datasources/local/sale_local_datasource.dart';
import 'package:dukonpro/data/datasources/remote/sale_remote_datasource.dart';
import 'package:dukonpro/data/repositories/sale_repository_impl.dart';
import 'package:dukonpro/data/sync/sync_queue.dart';
import 'package:dukonpro/domain/entities/sale.dart';

// Revenue-critical path: a sale made while offline must be persisted
// locally AND enqueued for later sync — never silently dropped. Mirrors
// the offline/sync-queue pattern in debt_repository_test.dart.

class _MockSaleRemoteDatasource extends Mock implements SaleRemoteDatasource {}

class _MockSaleLocalDatasource extends Mock implements SaleLocalDatasource {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

class _MockSyncQueue extends Mock implements SyncQueue {}

Sale _makeSale({
  String id = 'sale-1',
  String storeId = 'store-1',
  String receiptNo = 'R-001',
  double total = 100,
}) {
  return Sale(
    id: id,
    storeId: storeId,
    receiptNo: receiptNo,
    subtotal: total,
    total: total,
    paymentType: 'CASH',
    paidAmount: total,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  late SaleRepositoryImpl repo;
  late _MockSaleRemoteDatasource remote;
  late _MockSaleLocalDatasource local;
  late _MockNetworkInfo networkInfo;
  late _MockSyncQueue syncQueue;

  setUpAll(() {
    registerFallbackValue(_makeSale());
    registerFallbackValue(<Sale>[]);
  });

  setUp(() {
    remote = _MockSaleRemoteDatasource();
    local = _MockSaleLocalDatasource();
    networkInfo = _MockNetworkInfo();
    syncQueue = _MockSyncQueue();
    repo = SaleRepositoryImpl(
      remoteDatasource: remote,
      localDatasource: local,
      networkInfo: networkInfo,
      syncQueue: syncQueue,
    );

    when(() => local.saveSale(any())).thenAnswer((_) async {});
    when(() => local.saveSales(any())).thenAnswer((_) async {});
    when(() => syncQueue.enqueue(
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          operation: any(named: 'operation'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});
  });

  group('SaleRepositoryImpl.createSale', () {
    test('creates remotely and caches locally when online', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remote.createSale(any(), any()))
          .thenAnswer((_) async => _makeSale(id: 'sale-1'));

      final result = await repo.createSale('store-1', {'paymentType': 'CASH'});

      expect(result.id, 'sale-1');
      verify(() => remote.createSale('store-1', {'paymentType': 'CASH'})).called(1);
      verify(() => local.saveSale(any(that: isA<Sale>()))).called(1);
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test('goes straight to offline creation without calling remote when '
        'isConnected is false', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repo.createSale('store-1', {
        'paymentType': 'CASH',
        '_offlineSubtotal': 50.0,
        '_offlineTotal': 50.0,
      });

      expect(result.id, startsWith('temp_'));
      verifyNever(() => remote.createSale(any(), any()));
      verify(() => local.saveSale(any(that: isA<Sale>()))).called(1);
      verify(() => syncQueue.enqueue(
            entityType: 'sale',
            entityId: any(named: 'entityId'),
            operation: 'CREATE',
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('falls back to offline creation when the remote call throws '
        'NetworkException even though isConnected reported true (flaky '
        'connectivity)', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remote.createSale(any(), any())).thenThrow(const NetworkException());

      final result = await repo.createSale('store-1', {'paymentType': 'CASH'});

      expect(result.id, startsWith('temp_'));
      verify(() => local.saveSale(any(that: isA<Sale>()))).called(1);
      verify(() => syncQueue.enqueue(
            entityType: 'sale',
            entityId: any(named: 'entityId'),
            operation: 'CREATE',
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('does NOT fall back to offline and does not swallow non-network '
        'exceptions from the remote datasource (e.g. a 400 stock validation '
        'error must surface as an error, not be silently queued for retry)',
        () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remote.createSale(any(), any()))
          .thenThrow(const ServerException('Insufficient stock', statusCode: 400));

      await expectLater(
        () => repo.createSale('store-1', {'paymentType': 'CASH'}),
        throwsA(isA<ServerException>()),
      );

      verifyNever(() => local.saveSale(any()));
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test('computes the offline sale totals from the _offline* metadata keys '
        'so the success screen does not show 0 TJS', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repo.createSale('store-1', {
        'paymentType': 'CASH',
        'paidAmount': 100.0,
        'discount': 10.0,
        '_offlineSubtotal': 90.0,
        '_offlineTotal': 80.0,
        '_offlineChange': 20.0,
        '_offlineDebt': 0.0,
      });

      expect(result.subtotal, 90.0);
      expect(result.total, 80.0);
      expect(result.change, 20.0);
      expect(result.debtAmount, 0.0);
      expect(result.paymentType, 'CASH');
    });

    test('defaults offline totals to 0 when _offline* metadata keys are '
        'missing', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repo.createSale('store-1', {'paymentType': 'CASH'});

      expect(result.subtotal, 0);
      expect(result.total, 0);
      expect(result.change, 0);
      expect(result.debtAmount, 0);
    });

    test('generates a receiptNo prefixed OFF- and a temp_ id when creating '
        'offline', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repo.createSale('store-1', {'paymentType': 'CASH'});

      expect(result.id, startsWith('temp_'));
      expect(result.receiptNo, startsWith('OFF-'));
      expect(result.storeId, 'store-1');
    });

    test('strips all _offline* keys from the payload enqueued to the sync '
        'queue (API rejects unknown fields via forbidNonWhitelisted)',
        () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      await repo.createSale('store-1', {
        'paymentType': 'CASH',
        'paidAmount': 100.0,
        '_offlineSubtotal': 90.0,
        '_offlineTotal': 80.0,
        '_offlineChange': 20.0,
        '_offlineDebt': 0.0,
      });

      final captured = verify(() => syncQueue.enqueue(
            entityType: 'sale',
            entityId: any(named: 'entityId'),
            operation: 'CREATE',
            payload: captureAny(named: 'payload'),
          )).captured;
      final payload = captured.single as Map<String, dynamic>;
      expect(payload.keys.where((k) => k.startsWith('_offline')), isEmpty);
      expect(payload['paymentType'], 'CASH');
      expect(payload['paidAmount'], 100.0);
    });

    test('enqueues with the composite storeId:tempId entityId format',
        () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repo.createSale('store-1', {'paymentType': 'CASH'});

      final captured = verify(() => syncQueue.enqueue(
            entityType: 'sale',
            entityId: captureAny(named: 'entityId'),
            operation: 'CREATE',
            payload: any(named: 'payload'),
          )).captured;
      expect(captured.single, 'store-1:${result.id}');
    });
  });

  group('SaleRepositoryImpl.getSales', () {
    test('fetches from remote and caches page 1 with no filters when online',
        () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remote.getSales(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            customerId: any(named: 'customerId'),
            status: any(named: 'status'),
            paymentType: any(named: 'paymentType'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          )).thenAnswer((_) async => (
            data: [_makeSale()],
            total: 1,
            totalPages: 1,
            skippedRows: 0,
          ));

      final result = await repo.getSales('store-1');

      expect(result.data, hasLength(1));
      verify(() => local.saveSales(any(that: isA<List<Sale>>()))).called(1);
    });

    test('does not cache locally when page != 1', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remote.getSales(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            customerId: any(named: 'customerId'),
            status: any(named: 'status'),
            paymentType: any(named: 'paymentType'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          )).thenAnswer((_) async => (data: <Sale>[], total: 0, totalPages: 2, skippedRows: 0));

      await repo.getSales('store-1', page: 2);

      verifyNever(() => local.saveSales(any()));
    });

    test('does not cache locally when a filter (e.g. paymentType) is applied',
        () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remote.getSales(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            customerId: any(named: 'customerId'),
            status: any(named: 'status'),
            paymentType: any(named: 'paymentType'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          )).thenAnswer((_) async => (data: <Sale>[], total: 0, totalPages: 1, skippedRows: 0));

      await repo.getSales('store-1', paymentType: 'CASH');

      verifyNever(() => local.saveSales(any()));
    });

    test('reads from local cache when offline', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      when(() => local.getSales(any())).thenAnswer((_) async => [_makeSale()]);

      final result = await repo.getSales('store-1');

      expect(result.data, hasLength(1));
      expect(result.totalPages, 1);
      expect(result.skippedRows, 0);
      verifyNever(() => remote.getSales(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            customerId: any(named: 'customerId'),
            status: any(named: 'status'),
            paymentType: any(named: 'paymentType'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ));
    });

    test('falls back to local cache when the remote call throws '
        'NetworkException', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remote.getSales(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            customerId: any(named: 'customerId'),
            status: any(named: 'status'),
            paymentType: any(named: 'paymentType'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          )).thenThrow(const NetworkException());
      when(() => local.getSales(any())).thenAnswer((_) async => [_makeSale()]);

      final result = await repo.getSales('store-1');

      expect(result.data, hasLength(1));
    });

    test('propagates skippedRows from the remote result untouched', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remote.getSales(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            customerId: any(named: 'customerId'),
            status: any(named: 'status'),
            paymentType: any(named: 'paymentType'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          )).thenAnswer((_) async => (data: <Sale>[], total: 5, totalPages: 1, skippedRows: 2));

      final result = await repo.getSales('store-1');

      expect(result.skippedRows, 2);
    });
  });

  group('SaleRepositoryImpl.getSale', () {
    test('fetches from remote and caches locally when online', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remote.getSale(any(), any())).thenAnswer((_) async => _makeSale());

      final result = await repo.getSale('store-1', 'sale-1');

      expect(result.id, 'sale-1');
      verify(() => local.saveSale(any(that: isA<Sale>()))).called(1);
    });

    test('returns the cached sale when offline and present locally', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      when(() => local.getSale(any())).thenAnswer((_) async => _makeSale());

      final result = await repo.getSale('store-1', 'sale-1');

      expect(result.id, 'sale-1');
      verifyNever(() => remote.getSale(any(), any()));
    });

    test('throws CacheException when offline and the sale is not cached',
        () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      when(() => local.getSale(any())).thenAnswer((_) async => null);

      await expectLater(
        () => repo.getSale('store-1', 'missing'),
        throwsA(isA<CacheException>()),
      );
    });

    test('falls back to local cache on NetworkException and throws '
        'CacheException when not found there either', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remote.getSale(any(), any())).thenThrow(const NetworkException());
      when(() => local.getSale(any())).thenAnswer((_) async => null);

      await expectLater(
        () => repo.getSale('store-1', 'sale-1'),
        throwsA(isA<CacheException>()),
      );
    });
  });

  group('SaleRepositoryImpl.refundSale', () {
    test('refunds remotely and caches the updated sale when online', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remote.refundSale(any(), any(), any()))
          .thenAnswer((_) async => _makeSale(total: 0));

      final result = await repo.refundSale('store-1', 'sale-1', {'reason': 'x'});

      expect(result.total, 0);
      verify(() => local.saveSale(any(that: isA<Sale>()))).called(1);
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test('enqueues an UPDATE refund op and returns the cached sale when '
        'offline (refunds require server; must not be lost)', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      when(() => local.getSale(any())).thenAnswer((_) async => _makeSale());

      final result = await repo.refundSale('store-1', 'sale-1', {'reason': 'x'});

      expect(result.id, 'sale-1');
      final captured = verify(() => syncQueue.enqueue(
            entityType: 'sale',
            entityId: 'store-1:sale-1',
            operation: 'UPDATE',
            payload: captureAny(named: 'payload'),
          )).captured;
      final payload = captured.single as Map<String, dynamic>;
      expect(payload['action'], 'refund');
      expect(payload['reason'], 'x');
      verifyNever(() => remote.refundSale(any(), any(), any()));
    });

    test('throws CacheException when offline and refunding a sale that is '
        'not cached locally', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      when(() => local.getSale(any())).thenAnswer((_) async => null);

      await expectLater(
        () => repo.refundSale('store-1', 'missing', {}),
        throwsA(isA<CacheException>()),
      );
    });

    test('enqueues an UPDATE refund op and falls back to cache on '
        'NetworkException', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remote.refundSale(any(), any(), any())).thenThrow(const NetworkException());
      when(() => local.getSale(any())).thenAnswer((_) async => _makeSale());

      final result = await repo.refundSale('store-1', 'sale-1', {'reason': 'y'});

      expect(result.id, 'sale-1');
      verify(() => syncQueue.enqueue(
            entityType: 'sale',
            entityId: 'store-1:sale-1',
            operation: 'UPDATE',
            payload: any(named: 'payload'),
          )).called(1);
    });
  });

  group('SaleRepositoryImpl local passthrough', () {
    test('getLocalSales delegates to the local datasource', () async {
      when(() => local.getSales(any())).thenAnswer((_) async => [_makeSale()]);

      final result = await repo.getLocalSales('store-1');

      expect(result, hasLength(1));
      verify(() => local.getSales('store-1')).called(1);
    });

    test('saveSaleLocally delegates to the local datasource', () async {
      final sale = _makeSale();
      await repo.saveSaleLocally(sale);
      verify(() => local.saveSale(sale)).called(1);
    });
  });
}
