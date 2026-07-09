import '../entities/loyalty_analytics.dart';
import '../entities/loyalty_transaction.dart';

abstract class LoyaltyRepository {
  Future<Map<String, dynamic>> getSettings(String storeId);
  Future<Map<String, dynamic>> updateSettings(
      String storeId, Map<String, dynamic> data);
  Future<({int points, List<LoyaltyTransaction> transactions})>
      getCustomerBalance(String storeId, String customerId);
  Future<LoyaltyAnalytics> getAnalytics(
      String storeId, DateTime from, DateTime to);
}
