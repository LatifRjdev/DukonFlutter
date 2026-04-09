import '../../core/errors/exceptions.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/local/product_local_datasource.dart';
import '../datasources/remote/product_remote_datasource.dart';
import '../sync/sync_queue.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDatasource _remoteDatasource;
  final ProductLocalDatasource _localDatasource;
  final NetworkInfo _networkInfo;
  final SyncQueue _syncQueue;

  ProductRepositoryImpl({
    required ProductRemoteDatasource remoteDatasource,
    required ProductLocalDatasource localDatasource,
    required NetworkInfo networkInfo,
    required SyncQueue syncQueue,
  })  : _remoteDatasource = remoteDatasource,
        _localDatasource = localDatasource,
        _networkInfo = networkInfo,
        _syncQueue = syncQueue;

  @override
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
  }) async {
    try {
      if (await _networkInfo.isConnected) {
        final result = await _remoteDatasource.getProducts(
          storeId,
          page: page,
          limit: limit,
          search: search,
          categoryId: categoryId,
          inStock: inStock,
          lowStock: lowStock,
          sortBy: sortBy,
          sortOrder: sortOrder,
        );

        // Cache first page locally for offline access
        if (page == 1 && search == null && categoryId == null) {
          await _localDatasource.saveProducts(result.data);
        }

        return result;
      } else {
        // Offline: return local products
        final localProducts = await _localDatasource.getProducts(storeId);
        return (
          data: localProducts,
          total: localProducts.length,
          totalPages: 1,
        );
      }
    } on NetworkException {
      final localProducts = await _localDatasource.getProducts(storeId);
      return (
        data: localProducts,
        total: localProducts.length,
        totalPages: 1,
      );
    }
  }

  @override
  Future<Product> getProduct(String storeId, String id) async {
    try {
      if (await _networkInfo.isConnected) {
        final product = await _remoteDatasource.getProduct(storeId, id);
        await _localDatasource.saveProduct(product);
        return product;
      } else {
        final localProduct = await _localDatasource.getProduct(id);
        if (localProduct != null) return localProduct;
        throw const CacheException('Product not found in local storage');
      }
    } on NetworkException {
      final localProduct = await _localDatasource.getProduct(id);
      if (localProduct != null) return localProduct;
      throw const CacheException('Product not found in local storage');
    }
  }

  @override
  Future<Product> getProductByBarcode(String storeId, String barcode) async {
    try {
      if (await _networkInfo.isConnected) {
        final product =
            await _remoteDatasource.getProductByBarcode(storeId, barcode);
        await _localDatasource.saveProduct(product);
        return product;
      } else {
        final localProduct =
            await _localDatasource.getProductByBarcode(storeId, barcode);
        if (localProduct != null) return localProduct;
        throw const CacheException(
          'Product not found by barcode in local storage',
        );
      }
    } on NetworkException {
      final localProduct =
          await _localDatasource.getProductByBarcode(storeId, barcode);
      if (localProduct != null) return localProduct;
      throw const CacheException(
        'Product not found by barcode in local storage',
      );
    }
  }

  @override
  Future<Product> createProduct(
    String storeId,
    Map<String, dynamic> data,
  ) async {
    try {
      if (await _networkInfo.isConnected) {
        final product =
            await _remoteDatasource.createProduct(storeId, data);
        await _localDatasource.saveProduct(product);
        return product;
      } else {
        // Create locally with a temporary ID and enqueue for sync
        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        final product = Product(
          id: tempId,
          storeId: storeId,
          name: data['name'] as String? ?? '',
          sellPrice: (data['sellPrice'] as num?)?.toDouble() ?? 0,
          createdAt: DateTime.now(),
          categoryId: data['categoryId'] as String?,
          sku: data['sku'] as String?,
          barcode: data['barcode'] as String?,
          description: data['description'] as String?,
          costPrice: (data['costPrice'] as num?)?.toDouble(),
          wholesalePrice: (data['wholesalePrice'] as num?)?.toDouble(),
          quantity: (data['quantity'] as num?)?.toInt() ?? 0,
          minQuantity: (data['minQuantity'] as num?)?.toInt() ?? 0,
          unit: data['unit'] as String? ?? 'PCS',
        );
        await _localDatasource.saveProduct(product);
        await _syncQueue.enqueue(
          entityType: 'product',
          entityId: '$storeId:$tempId',
          operation: 'CREATE',
          payload: data,
        );
        return product;
      }
    } on NetworkException {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final product = Product(
        id: tempId,
        storeId: storeId,
        name: data['name'] as String? ?? '',
        sellPrice: (data['sellPrice'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.now(),
      );
      await _localDatasource.saveProduct(product);
      await _syncQueue.enqueue(
        entityType: 'product',
        entityId: '$storeId:$tempId',
        operation: 'CREATE',
        payload: data,
      );
      return product;
    }
  }

  @override
  Future<Product> updateProduct(
    String storeId,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      if (await _networkInfo.isConnected) {
        final product =
            await _remoteDatasource.updateProduct(storeId, id, data);
        await _localDatasource.saveProduct(product);
        return product;
      } else {
        await _syncQueue.enqueue(
          entityType: 'product',
          entityId: '$storeId:$id',
          operation: 'UPDATE',
          payload: data,
        );
        // Return existing local product with optimistic update
        final localProduct = await _localDatasource.getProduct(id);
        if (localProduct != null) return localProduct;
        throw const CacheException('Product not found in local storage');
      }
    } on NetworkException {
      await _syncQueue.enqueue(
        entityType: 'product',
        entityId: '$storeId:$id',
        operation: 'UPDATE',
        payload: data,
      );
      final localProduct = await _localDatasource.getProduct(id);
      if (localProduct != null) return localProduct;
      throw const CacheException('Product not found in local storage');
    }
  }

  @override
  Future<void> deleteProduct(String storeId, String id) async {
    try {
      if (await _networkInfo.isConnected) {
        await _remoteDatasource.deleteProduct(storeId, id);
        await _localDatasource.deleteProduct(id);
      } else {
        await _localDatasource.deleteProduct(id);
        await _syncQueue.enqueue(
          entityType: 'product',
          entityId: '$storeId:$id',
          operation: 'DELETE',
        );
      }
    } on NetworkException {
      await _localDatasource.deleteProduct(id);
      await _syncQueue.enqueue(
        entityType: 'product',
        entityId: '$storeId:$id',
        operation: 'DELETE',
      );
    }
  }

  @override
  Future<List<Product>> getLocalProducts(String storeId) async {
    return await _localDatasource.getProducts(storeId);
  }

  @override
  Future<void> saveProductsLocally(List<Product> products) async {
    await _localDatasource.saveProducts(products);
  }
}
