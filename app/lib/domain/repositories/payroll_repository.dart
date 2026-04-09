import '../entities/payroll_period.dart';

abstract class PayrollRepository {
  Future<PayrollPeriod> calculatePayroll(String storeId, int month, int year);
  Future<List<PayrollPeriod>> getPayrollPeriods(String storeId);
  Future<PayrollPeriod> getPayrollPeriod(String storeId, String periodId);
  Future<void> addAdjustment(String storeId, String periodId, Map<String, dynamic> data);
  Future<void> removeAdjustment(String storeId, String periodId, String adjustmentId);
  Future<void> payIndividual(String storeId, String periodId, String payrollId);
  Future<void> payAll(String storeId, String periodId);
}
