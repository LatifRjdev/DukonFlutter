import '../entities/product.dart';

abstract class ProductRepository {
  Future<({List<Product> data, int total, int totalPages})> getProducts(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? search,
    String? categoryId,
    bool? inStock,
    bool? lowStock,
    String? sortBy,
    String? sortOrder,
  });

  Future<Product> getProduct(String storeId, String id);

  Future<Product> getProductByBarcode(String storeId, String barcode);

  Future<Product> createProduct(String storeId, Map<String, dynamic> data);

  Future<Product> updateProduct(String storeId, String id, Map<String, dynamic> data);

  Future<void> deleteProduct(String storeId, String id);

  // Local
  Future<List<Product>> getLocalProducts(String storeId);
  Future<void> saveProductsLocally(List<Product> products);
}
