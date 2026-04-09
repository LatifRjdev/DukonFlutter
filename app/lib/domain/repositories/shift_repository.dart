import '../entities/shift.dart';
import '../entities/z_report.dart';

abstract class ShiftRepository {
  Future<ShiftModel> openShift(String storeId, Map<String, dynamic> data);
  Future<ShiftModel> closeShift(String storeId, String shiftId, Map<String, dynamic> data);
  Future<ShiftModel?> getCurrentShift(String storeId);
  Future<({List<ShiftModel> data, int total, int totalPages})> getShifts(
    String storeId, {
    int page = 1,
    String? staffId,
    String? dateFrom,
    String? dateTo,
  });
  Future<ShiftModel> getShift(String storeId, String id);
  Future<ZReport> getZReport(String storeId, String shiftId);
}
