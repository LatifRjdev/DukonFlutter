import '../../core/errors/exceptions.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/remote/customer_remote_datasource.dart';
import '../sync/sync_queue.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final CustomerRemoteDatasource _remoteDatasource;
  final NetworkInfo _networkInfo;
  final SyncQueue _syncQueue;

  CustomerRepositoryImpl({
    required CustomerRemoteDatasource remoteDatasource,
    required NetworkInfo networkInfo,
    required SyncQueue syncQueue,
  })  : _remoteDatasource = remoteDatasource,
        _networkInfo = networkInfo,
        _syncQueue = syncQueue;

  @override
  Future<({List<Customer> data, int total, int totalPages})> getCustomers(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    return await _remoteDatasource.getCustomers(
      storeId,
      page: page,
      limit: limit,
      search: search,
    );
  }

  @override
  Future<Customer> getCustomer(String storeId, String id) async {
    return await _remoteDatasource.getCustomer(storeId, id);
  }

  @override
  Future<Customer> createCustomer(
    String storeId,
    Map<String, dynamic> data,
  ) async {
    try {
      if (await _networkInfo.isConnected) {
        return await _remoteDatasource.createCustomer(storeId, data);
      } else {
        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        await _syncQueue.enqueue(
          entityType: 'customer',
          entityId: '$storeId:$tempId',
          operation: 'CREATE',
          payload: data,
        );
        return Customer(
          id: tempId,
          storeId: storeId,
          name: data['name'] as String? ?? '',
          phone: data['phone'] as String?,
          email: data['email'] as String?,
          notes: data['notes'] as String?,
        );
      }
    } on NetworkException {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      await _syncQueue.enqueue(
        entityType: 'customer',
        entityId: '$storeId:$tempId',
        operation: 'CREATE',
        payload: data,
      );
      return Customer(
        id: tempId,
        storeId: storeId,
        name: data['name'] as String? ?? '',
        phone: data['phone'] as String?,
      );
    }
  }

  @override
  Future<Customer> updateCustomer(
    String storeId,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      if (await _networkInfo.isConnected) {
        return await _remoteDatasource.updateCustomer(storeId, id, data);
      } else {
        await _syncQueue.enqueue(
          entityType: 'customer',
          entityId: '$storeId:$id',
          operation: 'UPDATE',
          payload: data,
        );
        // Return a best-effort customer from the data we have
        return await _remoteDatasource.getCustomer(storeId, id);
      }
    } on NetworkException {
      await _syncQueue.enqueue(
        entityType: 'customer',
        entityId: '$storeId:$id',
        operation: 'UPDATE',
        payload: data,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteCustomer(String storeId, String id) async {
    try {
      if (await _networkInfo.isConnected) {
        await _remoteDatasource.deleteCustomer(storeId, id);
      } else {
        await _syncQueue.enqueue(
          entityType: 'customer',
          entityId: '$storeId:$id',
          operation: 'DELETE',
        );
      }
    } on NetworkException {
      await _syncQueue.enqueue(
        entityType: 'customer',
        entityId: '$storeId:$id',
        operation: 'DELETE',
      );
    }
  }
}
