import '../../data/datasources/remote/dashboard_remote_datasource.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../presentation/blocs/dashboard/dashboard_state.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDatasource _remoteDatasource;

  DashboardRepositoryImpl({required DashboardRemoteDatasource remoteDatasource})
      : _remoteDatasource = remoteDatasource;

  @override
  Future<DashboardStats> getOverview(String storeId, {String period = 'today'}) {
    return _remoteDatasource.getOverview(storeId, period: period);
  }
}
