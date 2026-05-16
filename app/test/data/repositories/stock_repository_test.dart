import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/data/repositories/stock_repository_impl.dart';
import 'package:dukonpro/data/sync/sync_queue.dart';

class _MockDioClient extends Mock implements DioClient {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

class _MockSyncQueue extends Mock implements SyncQueue {}

void main() {
  late StockRepositoryImpl repo;
  late _MockDioClient dioClient;
  late _MockNetworkInfo networkInfo;
  late _MockSyncQueue syncQueue;

  setUp(() {
    dioClient = _MockDioClient();
    networkInfo = _MockNetworkInfo();
    syncQueue = _MockSyncQueue();
    repo = StockRepositoryImpl(
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

  group('StockRepositoryImpl', () {
    group('createStockMovement', () {
      test(
          'should enqueue with stock_movement entityType when offline',
          () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        await repo.createStockMovement('store-1', 'prod-1', {
          'type': 'PURCHASE',
          'quantity': 10,
        });

        // Capture the entityId to verify it follows the composite format
        final captured = verify(() => syncQueue.enqueue(
              entityType: 'stock_movement',
              entityId: captureAny(named: 'entityId'),
              operation: 'CREATE',
              payload: any(named: 'payload'),
            )).captured;
        expect(captured.single, startsWith('store-1:prod-1:temp_'));
      });

      test('should not enqueue when online', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(() => dioClient.post(
              any(),
              data: any(named: 'data'),
            )).thenAnswer(
          (_) async => Response(
            data: {
              'data': {
                'id': 'srv-1',
                'productId': 'prod-1',
                'type': 'PURCHASE',
                'quantity': 10,
                'createdAt': DateTime.now().toIso8601String(),
              },
            },
            requestOptions: RequestOptions(path: '/x'),
          ),
        );

        await repo.createStockMovement('store-1', 'prod-1', {
          'type': 'PURCHASE',
          'quantity': 10,
        });

        verifyNever(() => syncQueue.enqueue(
              entityType: any(named: 'entityType'),
              entityId: any(named: 'entityId'),
              operation: any(named: 'operation'),
              payload: any(named: 'payload'),
            ));
        verify(() => dioClient.post(any(), data: any(named: 'data')))
            .called(1);
      });

      test('should include localId in payload when not provided', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        await repo.createStockMovement('store-1', 'prod-1', {
          'type': 'PURCHASE',
          'quantity': 5,
        });

        final captured = verify(() => syncQueue.enqueue(
              entityType: any(named: 'entityType'),
              entityId: any(named: 'entityId'),
              operation: any(named: 'operation'),
              payload: captureAny(named: 'payload'),
            )).captured;

        final payload = captured.single as Map<String, dynamic>;
        expect(payload['type'], 'PURCHASE');
        expect(payload['quantity'], 5);
        expect(payload['localId'], isNotEmpty);
      });

      test('should preserve localId if already in payload', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        await repo.createStockMovement('store-1', 'prod-1', {
          'type': 'PURCHASE',
          'quantity': 5,
          'localId': 'fixed-uuid',
        });

        final captured = verify(() => syncQueue.enqueue(
              entityType: any(named: 'entityType'),
              entityId: any(named: 'entityId'),
              operation: any(named: 'operation'),
              payload: captureAny(named: 'payload'),
            )).captured;

        final payload = captured.single as Map<String, dynamic>;
        expect(payload['localId'], 'fixed-uuid');
      });

      test('should return temp StockMovement with temp_ id when offline',
          () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final movement = await repo.createStockMovement('store-1', 'prod-1', {
          'type': 'PURCHASE',
          'quantity': 10,
        });

        expect(movement.id.startsWith('temp_'), isTrue);
        expect(movement.productId, 'prod-1');
        expect(movement.type, 'PURCHASE');
        expect(movement.quantity, 10);
      });

      test('should return server StockMovement when online', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(() => dioClient.post(
              any(),
              data: any(named: 'data'),
            )).thenAnswer(
          (_) async => Response(
            data: {
              'data': {
                'id': 'srv-123',
                'productId': 'prod-1',
                'type': 'PURCHASE',
                'quantity': 15,
                'unitCost': 10.5,
                'totalCost': 157.5,
                'createdAt': '2026-05-12T12:00:00Z',
              },
            },
            requestOptions: RequestOptions(path: '/x'),
          ),
        );

        final movement = await repo.createStockMovement('store-1', 'prod-1', {
          'type': 'PURCHASE',
          'quantity': 15,
          'unitCost': 10.5,
          'totalCost': 157.5,
        });

        expect(movement.id, 'srv-123');
        expect(movement.productId, 'prod-1');
        expect(movement.type, 'PURCHASE');
        expect(movement.quantity, 15);
        expect(movement.unitCost, 10.5);
        expect(movement.totalCost, 157.5);
      });
    });
  });
}
