import '../entities/investment.dart';

abstract class InvestmentRepository {
  Future<({List<Investment> data, int total, int totalPages})> getInvestments(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<Investment> getInvestment(String storeId, String id);
  Future<Investment> createInvestment(String storeId, Map<String, dynamic> data);
  Future<Investment> updateInvestment(String storeId, String id, Map<String, dynamic> data);
  Future<void> deleteInvestment(String storeId, String id);
  Future<InvestmentSummary> getSummary(String storeId);
}
