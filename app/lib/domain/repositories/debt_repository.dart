// app/lib/domain/repositories/debt_repository.dart
//
// Spec B E.3: replaces direct DioClient calls inside DebtBloc.
// Both methods support offline replay via client-generated localId.
abstract class DebtRepository {
  /// Records a payment toward a customer's outstanding debt.
  /// Returns once the API confirms (online) OR the request is queued
  /// (offline). Caller should treat both as success.
  Future<void> addCustomerPayment(
    String storeId,
    String customerId,
    Map<String, dynamic> data,
  );

  /// Records a payment to a supplier (reduces our debt to them).
  Future<void> addSupplierPayment(
    String storeId,
    String supplierId,
    Map<String, dynamic> data,
  );
}
