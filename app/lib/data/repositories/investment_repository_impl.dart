import '../../domain/entities/investment.dart';
import '../../domain/repositories/investment_repository.dart';
import '../datasources/remote/investment_remote_datasource.dart';

class InvestmentRepositoryImpl implements InvestmentRepository {
  final InvestmentRemoteDatasource _remoteDatasource;

  InvestmentRepositoryImpl({required InvestmentRemoteDatasource remoteDatasource})
      : _remoteDatasource = remoteDatasource;

  @override
  Future<({List<Investment> data, int total, int totalPages})> getInvestments(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _remoteDatasource.getInvestments(
      storeId,
      page: page,
      limit: limit,
      status: status,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<Investment> getInvestment(String storeId, String id) {
    return _remoteDatasource.getInvestment(storeId, id);
  }

  @override
  Future<Investment> createInvestment(String storeId, Map<String, dynamic> data) {
    return _remoteDatasource.createInvestment(storeId, data);
  }

  @override
  Future<Investment> updateInvestment(String storeId, String id, Map<String, dynamic> data) {
    return _remoteDatasource.updateInvestment(storeId, id, data);
  }

  @override
  Future<void> deleteInvestment(String storeId, String id) {
    return _remoteDatasource.deleteInvestment(storeId, id);
  }

  @override
  Future<InvestmentSummary> getSummary(String storeId) {
    return _remoteDatasource.getSummary(storeId);
  }
}
