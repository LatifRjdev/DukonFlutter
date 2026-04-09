import 'package:sqflite/sqflite.dart';
import '../../../core/errors/exceptions.dart';
import '../../../domain/entities/category.dart';

abstract class CategoryLocalDatasource {
  Future<List<Category>> getCategories(String storeId);
  Future<Category?> getCategory(String id);
  Future<void> saveCategories(List<Category> categories);
  Future<void> saveCategory(Category category);
  Future<void> deleteCategory(String id);
  Future<void> clearCategories(String storeId);
}

class CategoryLocalDatasourceImpl implements CategoryLocalDatasource {
  final Database _db;

  static const _tableName = 'categories';

  CategoryLocalDatasourceImpl({required Database database}) : _db = database;

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id TEXT PRIMARY KEY,
        store_id TEXT NOT NULL,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        parent_id TEXT,
        product_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_categories_store_id ON $_tableName (store_id)',
    );
  }

  @override
  Future<List<Category>> getCategories(String storeId) async {
    try {
      final rows = await _db.query(
        _tableName,
        where: 'store_id = ?',
        whereArgs: [storeId],
        orderBy: 'sort_order ASC, name ASC',
      );
      return rows.map(_mapRowToCategory).toList();
    } catch (e) {
      throw CacheException('Failed to get local categories: $e');
    }
  }

  @override
  Future<Category?> getCategory(String id) async {
    try {
      final rows = await _db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _mapRowToCategory(rows.first);
    } catch (e) {
      throw CacheException('Failed to get local category: $e');
    }
  }

  @override
  Future<void> saveCategories(List<Category> categories) async {
    try {
      final batch = _db.batch();
      for (final category in categories) {
        batch.insert(
          _tableName,
          _categoryToRow(category),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      throw CacheException('Failed to save categories locally: $e');
    }
  }

  @override
  Future<void> saveCategory(Category category) async {
    try {
      await _db.insert(
        _tableName,
        _categoryToRow(category),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw CacheException('Failed to save category locally: $e');
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    try {
      await _db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw CacheException('Failed to delete local category: $e');
    }
  }

  @override
  Future<void> clearCategories(String storeId) async {
    try {
      await _db.delete(
        _tableName,
        where: 'store_id = ?',
        whereArgs: [storeId],
      );
    } catch (e) {
      throw CacheException('Failed to clear local categories: $e');
    }
  }

  Map<String, dynamic> _categoryToRow(Category category) {
    return {
      'id': category.id,
      'store_id': category.storeId,
      'name': category.name,
      'icon': category.icon,
      'color': category.color,
      'sort_order': category.sortOrder,
      'parent_id': category.parentId,
      'product_count': category.productCount,
    };
  }

  Category _mapRowToCategory(Map<String, dynamic> row) {
    return Category(
      id: row['id'] as String,
      storeId: row['store_id'] as String,
      name: row['name'] as String,
      icon: row['icon'] as String?,
      color: row['color'] as String?,
      sortOrder: row['sort_order'] as int? ?? 0,
      parentId: row['parent_id'] as String?,
      productCount: row['product_count'] as int? ?? 0,
    );
  }
}
