import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/data/repositories/debt_repository_impl.dart';
import 'package:dukonpro/data/sync/sync_queue.dart';

class _MockDioClient extends Mock implements DioClient {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

class _MockSyncQueue extends Mock implements SyncQueue {}

void main() {
  late DebtRepositoryImpl repo;
  late _MockDioClient dioClient;
  late _MockNetworkInfo networkInfo;
  late _MockSyncQueue syncQueue;

  setUp(() {
    dioClient = _MockDioClient();
    networkInfo = _MockNetworkInfo();
    syncQueue = _MockSyncQueue();
    repo = DebtRepositoryImpl(
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

  group('DebtRepositoryImpl', () {
    group('addCustomerPayment', () {
      test(
          'should enqueue with debt_payment entityType when offline',
          () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        await repo.addCustomerPayment('s1', 'c1', {'amount': 100});

        // Capture the entityId to verify it follows the composite format
        final captured = verify(() => syncQueue.enqueue(
              entityType: 'debt_payment',
              entityId: captureAny(named: 'entityId'),
              operation: 'CREATE',
              payload: any(named: 'payload'),
            )).captured;
        expect(captured.single, startsWith('s1:c1:temp_'));
      });

      test('should not enqueue when online', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(() => dioClient.post(
              any(),
              data: any(named: 'data'),
            )).thenAnswer(
          (_) async => Response(data: {}, requestOptions: RequestOptions(path: '/x')),
        );

        await repo.addCustomerPayment('s1', 'c1', {'amount': 100});

        verifyNever(() => syncQueue.enqueue(
              entityType: any(named: 'entityType'),
              entityId: any(named: 'entityId'),
              operation: any(named: 'operation'),
              payload: any(named: 'payload'),
            ));
        verify(() => dioClient.post(any(), data: any(named: 'data'))).called(1);
      });

      test('should include localId in payload when not provided', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        await repo.addCustomerPayment('s1', 'c1', {'amount': 100});

        final captured = verify(() => syncQueue.enqueue(
              entityType: any(named: 'entityType'),
              entityId: any(named: 'entityId'),
              operation: any(named: 'operation'),
              payload: captureAny(named: 'payload'),
            )).captured;

        final payload = captured.single as Map<String, dynamic>;
        expect(payload['amount'], 100);
        expect(payload['localId'], isNotEmpty);
      });

      test('should preserve localId if already in payload', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        await repo.addCustomerPayment('s1', 'c1', {
          'amount': 100,
          'localId': 'custom-id',
        });

        final captured = verify(() => syncQueue.enqueue(
              entityType: any(named: 'entityType'),
              entityId: any(named: 'entityId'),
              operation: any(named: 'operation'),
              payload: captureAny(named: 'payload'),
            )).captured;

        final payload = captured.single as Map<String, dynamic>;
        expect(payload['localId'], 'custom-id');
      });
    });

    group('addSupplierPayment', () {
      test(
          'should enqueue with supplier_debt_payment entityType when offline',
          () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        await repo.addSupplierPayment('s1', 'sup1', {'amount': 200});

        // Capture the entityId to verify it follows the composite format
        final captured = verify(() => syncQueue.enqueue(
              entityType: 'supplier_debt_payment',
              entityId: captureAny(named: 'entityId'),
              operation: 'CREATE',
              payload: any(named: 'payload'),
            )).captured;
        expect(captured.single, startsWith('s1:sup1:temp_'));
      });

      test('should not enqueue when online', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(() => dioClient.post(
              any(),
              data: any(named: 'data'),
            )).thenAnswer(
          (_) async => Response(data: {}, requestOptions: RequestOptions(path: '/x')),
        );

        await repo.addSupplierPayment('s1', 'sup1', {'amount': 200});

        verifyNever(() => syncQueue.enqueue(
              entityType: any(named: 'entityType'),
              entityId: any(named: 'entityId'),
              operation: any(named: 'operation'),
              payload: any(named: 'payload'),
            ));
        verify(() => dioClient.post(any(), data: any(named: 'data'))).called(1);
      });

      test('should include localId in payload when not provided', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        await repo.addSupplierPayment('s1', 'sup1', {'amount': 200});

        final captured = verify(() => syncQueue.enqueue(
              entityType: any(named: 'entityType'),
              entityId: any(named: 'entityId'),
              operation: any(named: 'operation'),
              payload: captureAny(named: 'payload'),
            )).captured;

        final payload = captured.single as Map<String, dynamic>;
        expect(payload['amount'], 200);
        expect(payload['localId'], isNotEmpty);
      });

      test('should preserve localId if already in payload', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        await repo.addSupplierPayment('s1', 'sup1', {
          'amount': 200,
          'localId': 'supplier-id',
        });

        final captured = verify(() => syncQueue.enqueue(
              entityType: any(named: 'entityType'),
              entityId: any(named: 'entityId'),
              operation: any(named: 'operation'),
              payload: captureAny(named: 'payload'),
            )).captured;

        final payload = captured.single as Map<String, dynamic>;
        expect(payload['localId'], 'supplier-id');
      });
    });
  });
}
