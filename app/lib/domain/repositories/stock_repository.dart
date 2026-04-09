import '../entities/stock_movement.dart';

abstract class StockRepository {
  Future<StockMovement> createStockMovement(
    String storeId,
    String productId,
    Map<String, dynamic> data,
  );

  Future<({List<StockMovement> data, int total, int totalPages})> getStockMovements(
    String storeId,
    String productId, {
    int page = 1,
    int limit = 20,
  });
}
