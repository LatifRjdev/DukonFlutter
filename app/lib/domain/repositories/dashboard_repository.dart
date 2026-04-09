import '../../presentation/blocs/dashboard/dashboard_state.dart';

abstract class DashboardRepository {
  Future<DashboardStats> getOverview(String storeId, {String period = 'today'});
}
