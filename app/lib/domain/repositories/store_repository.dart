import '../entities/store.dart';

abstract class StoreRepository {
  Future<Store> createStore({
    required String name,
    required String category,
    String currency,
    String? address,
    String? phone,
  });

  Future<List<Store>> getStores();

  Future<Store> getStore(String id);

  Future<Store> updateStore(String id, Map<String, dynamic> data);

  Future<void> deleteStore(String id);
}
