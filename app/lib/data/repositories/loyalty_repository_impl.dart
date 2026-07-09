import '../../domain/entities/loyalty_analytics.dart';
import '../../domain/entities/loyalty_transaction.dart';
import '../../domain/repositories/loyalty_repository.dart';
import '../datasources/remote/loyalty_remote_datasource.dart';

class LoyaltyRepositoryImpl implements LoyaltyRepository {
  final LoyaltyRemoteDatasource _remote;

  LoyaltyRepositoryImpl({required LoyaltyRemoteDatasource remote})
      : _remote = remote;

  @override
  Future<Map<String, dynamic>> getSettings(String storeId) =>
      _remote.getSettings(storeId);

  @override
  Future<Map<String, dynamic>> updateSettings(
          String storeId, Map<String, dynamic> data) =>
      _remote.updateSettings(storeId, data);

  @override
  Future<({int points, List<LoyaltyTransaction> transactions})>
      getCustomerBalance(String storeId, String customerId) =>
          _remote.getCustomerBalance(storeId, customerId);

  @override
  Future<LoyaltyAnalytics> getAnalytics(
          String storeId, DateTime from, DateTime to) =>
      _remote.getAnalytics(storeId, from, to);
}
