import '../../domain/entities/finance_summary.dart';
import '../../domain/repositories/finance_repository.dart';
import '../datasources/remote/finance_remote_datasource.dart';

class FinanceRepositoryImpl implements FinanceRepository {
  final FinanceRemoteDatasource _remoteDatasource;

  FinanceRepositoryImpl({required FinanceRemoteDatasource remoteDatasource})
      : _remoteDatasource = remoteDatasource;

  @override
  Future<FinanceSummary> getDashboard(String storeId, {DateTime? startDate, DateTime? endDate}) {
    return _remoteDatasource.getDashboard(storeId, startDate: startDate, endDate: endDate);
  }

  @override
  Future<FinanceSummary> getSummary(String storeId, {required String period, DateTime? startDate, DateTime? endDate}) {
    return _remoteDatasource.getSummary(storeId, period: period, startDate: startDate, endDate: endDate);
  }
}
