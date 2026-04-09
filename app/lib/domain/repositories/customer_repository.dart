import '../entities/customer.dart';

abstract class CustomerRepository {
  Future<({List<Customer> data, int total, int totalPages})> getCustomers(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? search,
  });
  Future<Customer> getCustomer(String storeId, String id);
  Future<Customer> createCustomer(String storeId, Map<String, dynamic> data);
  Future<Customer> updateCustomer(String storeId, String id, Map<String, dynamic> data);
  Future<void> deleteCustomer(String storeId, String id);
}
