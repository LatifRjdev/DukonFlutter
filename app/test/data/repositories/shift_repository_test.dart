import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/data/datasources/remote/shift_remote_datasource.dart';
import 'package:dukonpro/data/repositories/shift_repository_impl.dart';
import 'package:dukonpro/data/sync/sync_queue.dart';
import 'package:dukonpro/domain/entities/shift.dart';
import 'package:dukonpro/domain/entities/z_report.dart';

class _MockShiftRemoteDatasource extends Mock
    implements ShiftRemoteDatasource {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

class _MockSyncQueue extends Mock implements SyncQueue {}

void main() {
  late ShiftRepositoryImpl repo;
  late _MockShiftRemoteDatasource remoteDatasource;
  late _MockNetworkInfo networkInfo;
  late _MockSyncQueue syncQueue;

  ShiftModel shift({String status = 'OPEN', String id = 'shift-1'}) =>
      ShiftModel(
        id: id,
        storeId: 's1',
        staffId: 'staff-1',
        openedAt: DateTime(2026, 7, 17, 8),
        openingCash: 500,
        status: status,
      );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    remoteDatasource = _MockShiftRemoteDatasource();
    networkInfo = _MockNetworkInfo();
    syncQueue = _MockSyncQueue();
    repo = ShiftRepositoryImpl(
      remoteDatasource: remoteDatasource,
      networkInfo: networkInfo,
      syncQueue: syncQueue,
    );

    when(() => syncQueue.enqueue(
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          operation: any(named: 'operation'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});
  });

  group('ShiftRepositoryImpl.openShift', () {
    test('calls the remote datasource directly when online', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remoteDatasource.openShift(any(), any()))
          .thenAnswer((_) async => shift());

      final result = await repo.openShift('s1', {'openingCash': 500});

      expect(result.id, 'shift-1');
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test('attaches a localId to the payload sent to the remote datasource',
        () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remoteDatasource.openShift(any(), any()))
          .thenAnswer((_) async => shift());

      await repo.openShift('s1', {'openingCash': 500});

      final captured = verify(
        () => remoteDatasource.openShift('s1', captureAny()),
      ).captured;
      final payload = captured.single as Map<String, dynamic>;
      expect(payload['openingCash'], 500);
      expect(payload['localId'], isNotEmpty);
    });

    test('preserves an already-supplied localId', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remoteDatasource.openShift(any(), any()))
          .thenAnswer((_) async => shift());

      await repo.openShift('s1', {'openingCash': 500, 'localId': 'fixed-id'});

      final captured = verify(
        () => remoteDatasource.openShift('s1', captureAny()),
      ).captured;
      final payload = captured.single as Map<String, dynamic>;
      expect(payload['localId'], 'fixed-id');
    });

    test('enqueues a CREATE sync op with entityType=shift when offline',
        () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repo.openShift('s1', {'openingCash': 500});

      final captured = verify(() => syncQueue.enqueue(
            entityType: 'shift',
            entityId: captureAny(named: 'entityId'),
            operation: 'CREATE',
            payload: any(named: 'payload'),
          )).captured;
      expect(captured.single, startsWith('s1:temp_'));
      // Offline write returns an immediately-renderable temp shift.
      expect(result.id, startsWith('temp_'));
      expect(result.storeId, 's1');
      expect(result.openingCash, 500);
      expect(result.status, 'OPEN');
      verifyNever(() => remoteDatasource.openShift(any(), any()));
    });

    test('falls back to the offline path when the datasource throws '
        'NetworkException while "online"', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remoteDatasource.openShift(any(), any()))
          .thenThrow(const NetworkException());

      final result = await repo.openShift('s1', {'openingCash': 500});

      expect(result.id, startsWith('temp_'));
      verify(() => syncQueue.enqueue(
            entityType: 'shift',
            entityId: any(named: 'entityId'),
            operation: 'CREATE',
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('propagates non-network exceptions from the remote datasource '
        'without queueing (e.g. active-shift 409 conflict)', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => remoteDatasource.openShift(any(), any())).thenThrow(
        const ServerException('Shift already open', statusCode: 409),
      );

      await expectLater(
        () => repo.openShift('s1', {'openingCash': 500}),
        throwsA(isA<ServerException>()),
      );
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test('uses openingCash=0 for the offline temp shift when omitted',
        () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repo.openShift('s1', {});

      expect(result.openingCash, 0);
    });
  });

  group('ShiftRepositoryImpl.closeShift — critical financial event', () {
    test('calls the remote datasource directly and returns the closed shift',
        () async {
      when(() => remoteDatasource.closeShift(any(), any(), any()))
          .thenAnswer((_) async => shift(status: 'CLOSED'));

      final result =
          await repo.closeShift('s1', 'shift-1', {'closingCash': 1200});

      expect(result.status, 'CLOSED');
      verify(() =>
              remoteDatasource.closeShift('s1', 'shift-1', {'closingCash': 1200}))
          .called(1);
    });

    test('never enqueues to the sync queue, even though openShift does',
        () async {
      when(() => remoteDatasource.closeShift(any(), any(), any()))
          .thenAnswer((_) async => shift(status: 'CLOSED'));

      await repo.closeShift('s1', 'shift-1', {'closingCash': 1200});

      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test('propagates NetworkException from the datasource instead of '
        'silently queueing the close — offline shift-close must surface '
        'to the cashier, not disappear', () async {
      when(() => remoteDatasource.closeShift(any(), any(), any()))
          .thenThrow(const NetworkException());

      await expectLater(
        () => repo.closeShift('s1', 'shift-1', {'closingCash': 1200}),
        throwsA(isA<NetworkException>()),
      );
      verifyNever(() => syncQueue.enqueue(
            entityType: any(named: 'entityType'),
            entityId: any(named: 'entityId'),
            operation: any(named: 'operation'),
            payload: any(named: 'payload'),
          ));
    });

    test('does not consult NetworkInfo before closing (no online gate)',
        () async {
      when(() => remoteDatasource.closeShift(any(), any(), any()))
          .thenAnswer((_) async => shift(status: 'CLOSED'));

      await repo.closeShift('s1', 'shift-1', {'closingCash': 1200});

      verifyNever(() => networkInfo.isConnected);
    });
  });

  group('ShiftRepositoryImpl passthrough methods', () {
    test('getCurrentShift delegates to the remote datasource', () async {
      when(() => remoteDatasource.getCurrentShift(any()))
          .thenAnswer((_) async => shift());

      final result = await repo.getCurrentShift('s1');

      expect(result?.id, 'shift-1');
      verify(() => remoteDatasource.getCurrentShift('s1')).called(1);
    });

    test('getCurrentShift returns null when there is no open shift',
        () async {
      when(() => remoteDatasource.getCurrentShift(any()))
          .thenAnswer((_) async => null);

      final result = await repo.getCurrentShift('s1');

      expect(result, isNull);
    });

    test('getShifts forwards pagination/filter params and result',
        () async {
      when(() => remoteDatasource.getShifts(
            any(),
            page: any(named: 'page'),
            staffId: any(named: 'staffId'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          )).thenAnswer((_) async => (data: [shift()], total: 1, totalPages: 1));

      final result = await repo.getShifts('s1',
          page: 2, staffId: 'staff-1', dateFrom: '2026-07-01', dateTo: '2026-07-31');

      expect(result.data, hasLength(1));
      expect(result.total, 1);
      verify(() => remoteDatasource.getShifts(
            's1',
            page: 2,
            staffId: 'staff-1',
            dateFrom: '2026-07-01',
            dateTo: '2026-07-31',
          )).called(1);
    });

    test('getShift delegates to the remote datasource', () async {
      when(() => remoteDatasource.getShift(any(), any()))
          .thenAnswer((_) async => shift());

      final result = await repo.getShift('s1', 'shift-1');

      expect(result.id, 'shift-1');
      verify(() => remoteDatasource.getShift('s1', 'shift-1')).called(1);
    });

    test('getZReport delegates to the remote datasource', () async {
      final report = ZReport(
        staffName: 'Ali',
        openedAt: DateTime(2026, 7, 17, 8),
        closedAt: DateTime(2026, 7, 17, 20),
        duration: '12h',
        expectedCash: 1000,
        actualCash: 950,
        difference: -50,
      );
      when(() => remoteDatasource.getZReport(any(), any()))
          .thenAnswer((_) async => report);

      final result = await repo.getZReport('s1', 'shift-1');

      expect(result.difference, -50);
      verify(() => remoteDatasource.getZReport('s1', 'shift-1')).called(1);
    });
  });
}
