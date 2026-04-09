import 'package:equatable/equatable.dart';

class SupplierPayment extends Equatable {
  final String id;
  final String storeId;
  final String supplierId;
  final double amount;
  final String method;
  final String? notes;
  final DateTime createdAt;

  const SupplierPayment({
    required this.id,
    required this.storeId,
    required this.supplierId,
    required this.amount,
    required this.method,
    this.notes,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, supplierId, amount, method, createdAt];
}
