import 'package:uuid/uuid.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/shift.dart';
import '../../domain/entities/z_report.dart';
import '../../domain/repositories/shift_repository.dart';
import '../datasources/remote/shift_remote_datasource.dart';
import '../sync/sync_queue.dart';

/// E.1: Shift repository now offline-aware. Open-shift writes go to
/// the API when online; offline writes are queued for replay with a
/// client-supplied `localId` so the server returns the existing shift
/// instead of throwing the active-shift conflict on retry.
///
/// Close-shift is intentionally NOT queued — the cashier closes at end
/// of day which generally has connectivity, and the close payload
/// includes summary data we can't easily reconstruct on replay.
class ShiftRepositoryImpl implements ShiftRepository {
  final ShiftRemoteDatasource _remoteDatasource;
  final NetworkInfo _networkInfo;
  final SyncQueue _syncQueue;

  ShiftRepositoryImpl({
    required ShiftRemoteDatasource remoteDatasource,
    required NetworkInfo networkInfo,
    required SyncQueue syncQueue,
  })  : _remoteDatasource = remoteDatasource,
        _networkInfo = networkInfo,
        _syncQueue = syncQueue;

  @override
  Future<ShiftModel> openShift(
      String storeId, Map<String, dynamic> data) async {
    // Always attach a localId so retries are deduplicated by the server.
    final payload = Map<String, dynamic>.from(data);
    payload['localId'] ??= const Uuid().v4();

    try {
      if (await _networkInfo.isConnected) {
        return await _remoteDatasource.openShift(storeId, payload);
      }
    } on NetworkException {
      // Fall through to offline path.
    }

    // Offline: build a temp Shift, enqueue the API call, return a
    // ShiftModel the UI can render immediately. Replay reconciles
    // against the server-issued id on next sync.
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final shift = ShiftModel(
      id: tempId,
      storeId: storeId,
      staffId: '',
      openedAt: DateTime.now(),
      openingCash: (payload['openingCash'] as num?)?.toDouble() ?? 0,
      status: 'OPEN',
    );

    await _syncQueue.enqueue(
      entityType: 'shift',
      entityId: '$storeId:$tempId',
      operation: 'CREATE',
      payload: payload,
    );

    return shift;
  }

  @override
  Future<ShiftModel> closeShift(
      String storeId, String shiftId, Map<String, dynamic> data) {
    return _remoteDatasource.closeShift(storeId, shiftId, data);
  }

  @override
  Future<ShiftModel?> getCurrentShift(String storeId) {
    return _remoteDatasource.getCurrentShift(storeId);
  }

  @override
  Future<({List<ShiftModel> data, int total, int totalPages})> getShifts(
    String storeId, {
    int page = 1,
    String? staffId,
    String? dateFrom,
    String? dateTo,
  }) {
    return _remoteDatasource.getShifts(
      storeId,
      page: page,
      staffId: staffId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  @override
  Future<ShiftModel> getShift(String storeId, String id) {
    return _remoteDatasource.getShift(storeId, id);
  }

  @override
  Future<ZReport> getZReport(String storeId, String shiftId) {
    return _remoteDatasource.getZReport(storeId, shiftId);
  }
}
