import '../entities/supplier.dart';

abstract class SupplierRepository {
  Future<({List<Supplier> data, int total, int totalPages})> getSuppliers(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? search,
  });
  Future<Supplier> getSupplier(String storeId, String id);
  Future<Supplier> createSupplier(String storeId, Map<String, dynamic> data);
  Future<Supplier> updateSupplier(String storeId, String id, Map<String, dynamic> data);
  Future<void> deleteSupplier(String storeId, String id);
}
