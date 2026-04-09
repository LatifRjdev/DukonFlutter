import '../entities/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> getCategories(String storeId);
  Future<Category> createCategory(String storeId, Map<String, dynamic> data);
  Future<Category> updateCategory(String storeId, String id, Map<String, dynamic> data);
  Future<void> deleteCategory(String storeId, String id);
}
