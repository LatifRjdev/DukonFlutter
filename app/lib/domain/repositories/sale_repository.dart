import '../entities/sale.dart';

abstract class SaleRepository {
  Future<Sale> createSale(String storeId, Map<String, dynamic> data);

  Future<({List<Sale> data, int total, int totalPages, int skippedRows})>
      getSales(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? customerId,
    String? status,
    String? paymentType,
    DateTime? dateFrom,
    DateTime? dateTo,
  });

  Future<Sale> getSale(String storeId, String id);

  Future<Sale> refundSale(String storeId, String id, Map<String, dynamic> data);

  // Local
  Future<List<Sale>> getLocalSales(String storeId);
  Future<void> saveSaleLocally(Sale sale);
}
