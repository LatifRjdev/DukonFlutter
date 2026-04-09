import '../entities/finance_summary.dart';

abstract class FinanceRepository {
  Future<FinanceSummary> getDashboard(String storeId, {DateTime? startDate, DateTime? endDate});
  Future<FinanceSummary> getSummary(String storeId, {required String period, DateTime? startDate, DateTime? endDate});
}
