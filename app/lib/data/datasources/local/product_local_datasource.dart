import 'package:sqflite/sqflite.dart';
import '../../../core/errors/exceptions.dart';
import '../../../domain/entities/product.dart';

abstract class ProductLocalDatasource {
  Future<List<Product>> getProducts(String storeId);
  Future<Product?> getProduct(String id);
  Future<Product?> getProductByBarcode(String storeId, String barcode);
  Future<void> saveProducts(List<Product> products);
  Future<void> saveProduct(Product product);
  Future<void> deleteProduct(String id);
  Future<void> clearProducts(String storeId);
}

class ProductLocalDatasourceImpl implements ProductLocalDatasource {
  final Database _db;

  static const _tableName = 'products';

  ProductLocalDatasourceImpl({required Database database}) : _db = database;

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id TEXT PRIMARY KEY,
        store_id TEXT NOT NULL,
        category_id TEXT,
        category_name TEXT,
        supplier_id TEXT,
        name TEXT NOT NULL,
        sku TEXT,
        barcode TEXT,
        description TEXT,
        cost_price REAL,
        sell_price REAL NOT NULL,
        wholesale_price REAL,
        quantity INTEGER NOT NULL DEFAULT 0,
        min_quantity INTEGER NOT NULL DEFAULT 0,
        unit TEXT NOT NULL DEFAULT 'PCS',
        image_url TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_store_id ON $_tableName (store_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_barcode ON $_tableName (barcode)',
    );
  }

  @override
  Future<List<Product>> getProducts(String storeId) async {
    try {
      final rows = await _db.query(
        _tableName,
        where: 'store_id = ?',
        whereArgs: [storeId],
        orderBy: 'name ASC',
      );
      return rows.map(_mapRowToProduct).toList();
    } catch (e) {
      throw CacheException('Failed to get local products: $e');
    }
  }

  @override
  Future<Product?> getProduct(String id) async {
    try {
      final rows = await _db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _mapRowToProduct(rows.first);
    } catch (e) {
      throw CacheException('Failed to get local product: $e');
    }
  }

  @override
  Future<Product?> getProductByBarcode(String storeId, String barcode) async {
    try {
      final rows = await _db.query(
        _tableName,
        where: 'store_id = ? AND barcode = ?',
        whereArgs: [storeId, barcode],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _mapRowToProduct(rows.first);
    } catch (e) {
      throw CacheException('Failed to get local product by barcode: $e');
    }
  }

  @override
  Future<void> saveProducts(List<Product> products) async {
    try {
      final batch = _db.batch();
      for (final product in products) {
        batch.insert(
          _tableName,
          _productToRow(product),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      throw CacheException('Failed to save products locally: $e');
    }
  }

  @override
  Future<void> saveProduct(Product product) async {
    try {
      await _db.insert(
        _tableName,
        _productToRow(product),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw CacheException('Failed to save product locally: $e');
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    try {
      await _db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw CacheException('Failed to delete local product: $e');
    }
  }

  @override
  Future<void> clearProducts(String storeId) async {
    try {
      await _db.delete(
        _tableName,
        where: 'store_id = ?',
        whereArgs: [storeId],
      );
    } catch (e) {
      throw CacheException('Failed to clear local products: $e');
    }
  }

  Map<String, dynamic> _productToRow(Product product) {
    return {
      'id': product.id,
      'store_id': product.storeId,
      'category_id': product.categoryId,
      'category_name': product.categoryName,
      'supplier_id': product.supplierId,
      'name': product.name,
      'sku': product.sku,
      'barcode': product.barcode,
      'description': product.description,
      'cost_price': product.costPrice,
      'sell_price': product.sellPrice,
      'wholesale_price': product.wholesalePrice,
      'quantity': product.quantity,
      'min_quantity': product.minQuantity,
      'unit': product.unit,
      'image_url': product.imageUrl,
      'is_active': product.isActive ? 1 : 0,
      'created_at': product.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Product _mapRowToProduct(Map<String, dynamic> row) {
    return Product(
      id: row['id'] as String,
      storeId: row['store_id'] as String,
      categoryId: row['category_id'] as String?,
      categoryName: row['category_name'] as String?,
      supplierId: row['supplier_id'] as String?,
      name: row['name'] as String,
      sku: row['sku'] as String?,
      barcode: row['barcode'] as String?,
      description: row['description'] as String?,
      costPrice: row['cost_price'] as double?,
      sellPrice: row['sell_price'] as double,
      wholesalePrice: row['wholesale_price'] as double?,
      quantity: row['quantity'] as int? ?? 0,
      minQuantity: row['min_quantity'] as int? ?? 0,
      unit: row['unit'] as String? ?? 'PCS',
      imageUrl: row['image_url'] as String?,
      isActive: (row['is_active'] as int?) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
