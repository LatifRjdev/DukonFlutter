import '../../core/errors/exceptions.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/local/category_local_datasource.dart';
import '../datasources/remote/category_remote_datasource.dart';
import '../sync/sync_queue.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryRemoteDatasource _remoteDatasource;
  final CategoryLocalDatasource _localDatasource;
  final NetworkInfo _networkInfo;
  final SyncQueue _syncQueue;

  CategoryRepositoryImpl({
    required CategoryRemoteDatasource remoteDatasource,
    required CategoryLocalDatasource localDatasource,
    required NetworkInfo networkInfo,
    required SyncQueue syncQueue,
  })  : _remoteDatasource = remoteDatasource,
        _localDatasource = localDatasource,
        _networkInfo = networkInfo,
        _syncQueue = syncQueue;

  @override
  Future<List<Category>> getCategories(String storeId) async {
    try {
      if (await _networkInfo.isConnected) {
        final categories =
            await _remoteDatasource.getCategories(storeId);
        await _localDatasource.saveCategories(categories);
        return categories;
      } else {
        return await _localDatasource.getCategories(storeId);
      }
    } on NetworkException {
      return await _localDatasource.getCategories(storeId);
    }
  }

  @override
  Future<Category> createCategory(
    String storeId,
    Map<String, dynamic> data,
  ) async {
    try {
      if (await _networkInfo.isConnected) {
        final category =
            await _remoteDatasource.createCategory(storeId, data);
        await _localDatasource.saveCategory(category);
        return category;
      } else {
        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        final category = Category(
          id: tempId,
          storeId: storeId,
          name: data['name'] as String? ?? '',
          icon: data['icon'] as String?,
          color: data['color'] as String?,
          sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
          parentId: data['parentId'] as String?,
        );
        await _localDatasource.saveCategory(category);
        await _syncQueue.enqueue(
          entityType: 'category',
          entityId: '$storeId:$tempId',
          operation: 'CREATE',
          payload: data,
        );
        return category;
      }
    } on NetworkException {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final category = Category(
        id: tempId,
        storeId: storeId,
        name: data['name'] as String? ?? '',
      );
      await _localDatasource.saveCategory(category);
      await _syncQueue.enqueue(
        entityType: 'category',
        entityId: '$storeId:$tempId',
        operation: 'CREATE',
        payload: data,
      );
      return category;
    }
  }

  @override
  Future<Category> updateCategory(
    String storeId,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      if (await _networkInfo.isConnected) {
        final category =
            await _remoteDatasource.updateCategory(storeId, id, data);
        await _localDatasource.saveCategory(category);
        return category;
      } else {
        await _syncQueue.enqueue(
          entityType: 'category',
          entityId: '$storeId:$id',
          operation: 'UPDATE',
          payload: data,
        );
        final localCategory = await _localDatasource.getCategory(id);
        if (localCategory != null) return localCategory;
        throw const CacheException('Category not found in local storage');
      }
    } on NetworkException {
      await _syncQueue.enqueue(
        entityType: 'category',
        entityId: '$storeId:$id',
        operation: 'UPDATE',
        payload: data,
      );
      final localCategory = await _localDatasource.getCategory(id);
      if (localCategory != null) return localCategory;
      throw const CacheException('Category not found in local storage');
    }
  }

  @override
  Future<void> deleteCategory(String storeId, String id) async {
    try {
      if (await _networkInfo.isConnected) {
        await _remoteDatasource.deleteCategory(storeId, id);
        await _localDatasource.deleteCategory(id);
      } else {
        await _localDatasource.deleteCategory(id);
        await _syncQueue.enqueue(
          entityType: 'category',
          entityId: '$storeId:$id',
          operation: 'DELETE',
        );
      }
    } on NetworkException {
      await _localDatasource.deleteCategory(id);
      await _syncQueue.enqueue(
        entityType: 'category',
        entityId: '$storeId:$id',
        operation: 'DELETE',
      );
    }
  }
}
