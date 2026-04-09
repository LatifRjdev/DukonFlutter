import '../../domain/entities/payroll_period.dart';
import '../../domain/repositories/payroll_repository.dart';
import '../datasources/remote/payroll_remote_datasource.dart';

class PayrollRepositoryImpl implements PayrollRepository {
  final PayrollRemoteDatasource _remoteDatasource;

  PayrollRepositoryImpl({required PayrollRemoteDatasource remoteDatasource})
      : _remoteDatasource = remoteDatasource;

  @override
  Future<PayrollPeriod> calculatePayroll(String storeId, int month, int year) {
    return _remoteDatasource.calculatePayroll(storeId, month, year);
  }

  @override
  Future<List<PayrollPeriod>> getPayrollPeriods(String storeId) {
    return _remoteDatasource.getPayrollPeriods(storeId);
  }

  @override
  Future<PayrollPeriod> getPayrollPeriod(String storeId, String periodId) {
    return _remoteDatasource.getPayrollPeriod(storeId, periodId);
  }

  @override
  Future<void> addAdjustment(String storeId, String periodId, Map<String, dynamic> data) {
    return _remoteDatasource.addAdjustment(storeId, periodId, data);
  }

  @override
  Future<void> removeAdjustment(String storeId, String periodId, String adjustmentId) {
    return _remoteDatasource.removeAdjustment(storeId, periodId, adjustmentId);
  }

  @override
  Future<void> payIndividual(String storeId, String periodId, String payrollId) {
    return _remoteDatasource.payIndividual(storeId, periodId, payrollId);
  }

  @override
  Future<void> payAll(String storeId, String periodId) {
    return _remoteDatasource.payAll(storeId, periodId);
  }
}
