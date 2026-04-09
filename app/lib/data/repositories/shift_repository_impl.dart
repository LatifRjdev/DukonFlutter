import '../../domain/entities/shift.dart';
import '../../domain/entities/z_report.dart';
import '../../domain/repositories/shift_repository.dart';
import '../datasources/remote/shift_remote_datasource.dart';

class ShiftRepositoryImpl implements ShiftRepository {
  final ShiftRemoteDatasource _remoteDatasource;

  ShiftRepositoryImpl({required ShiftRemoteDatasource remoteDatasource})
      : _remoteDatasource = remoteDatasource;

  @override
  Future<ShiftModel> openShift(String storeId, Map<String, dynamic> data) {
    return _remoteDatasource.openShift(storeId, data);
  }

  @override
  Future<ShiftModel> closeShift(String storeId, String shiftId, Map<String, dynamic> data) {
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
