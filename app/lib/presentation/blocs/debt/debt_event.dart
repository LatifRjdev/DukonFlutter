import 'package:equatable/equatable.dart';

abstract class DebtEvent extends Equatable {
  const DebtEvent();
  @override
  List<Object?> get props => [];
}

class CustomerDebtsRequested extends DebtEvent {
  final String storeId;
  final String customerId;
  const CustomerDebtsRequested({required this.storeId, required this.customerId});
  @override
  List<Object?> get props => [storeId, customerId];
}

class SupplierDebtsRequested extends DebtEvent {
  final String storeId;
  final String supplierId;
  const SupplierDebtsRequested({required this.storeId, required this.supplierId});
  @override
  List<Object?> get props => [storeId, supplierId];
}

class DebtPaymentSubmitted extends DebtEvent {
  final String storeId;
  final String customerId;
  final String saleId;
  final double amount;
  final String method;
  final String? notes;
  const DebtPaymentSubmitted({required this.storeId, required this.customerId, required this.saleId, required this.amount, required this.method, this.notes});
  @override
  List<Object?> get props => [storeId, customerId, saleId, amount, method];
}

class SupplierPaymentSubmitted extends DebtEvent {
  final String storeId;
  final String supplierId;
  final double amount;
  final String method;
  final String? notes;
  const SupplierPaymentSubmitted({required this.storeId, required this.supplierId, required this.amount, required this.method, this.notes});
  @override
  List<Object?> get props => [storeId, supplierId, amount, method];
}

class DebtsOverviewRequested extends DebtEvent {
  final String storeId;
  const DebtsOverviewRequested({required this.storeId});
  @override
  List<Object?> get props => [storeId];
}
