import '../../domain/entities/store.dart';
import '../../domain/repositories/store_repository.dart';
import '../datasources/remote/store_remote_datasource.dart';

class StoreRepositoryImpl implements StoreRepository {
  final StoreRemoteDatasource _remoteDatasource;

  StoreRepositoryImpl({required StoreRemoteDatasource remoteDatasource})
      : _remoteDatasource = remoteDatasource;

  @override
  Future<Store> createStore({
    required String name,
    required String category,
    String currency = 'TJS',
    String? address,
    String? phone,
  }) async {
    return await _remoteDatasource.createStore(
      name: name,
      category: category,
      currency: currency,
      address: address,
      phone: phone,
    );
  }

  @override
  Future<List<Store>> getStores() async {
    return await _remoteDatasource.getStores();
  }

  @override
  Future<Store> getStore(String id) async {
    return await _remoteDatasource.getStore(id);
  }

  @override
  Future<Store> updateStore(String id, Map<String, dynamic> data) async {
    return await _remoteDatasource.updateStore(id, data);
  }

  @override
  Future<void> deleteStore(String id) async {
    await _remoteDatasource.deleteStore(id);
  }
}
