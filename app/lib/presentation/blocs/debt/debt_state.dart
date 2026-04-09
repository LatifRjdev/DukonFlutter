import 'package:equatable/equatable.dart';

abstract class DebtState extends Equatable {
  const DebtState();
  @override
  List<Object?> get props => [];
}

class DebtInitial extends DebtState {}
class DebtLoading extends DebtState {}

class CustomerDebtsLoaded extends DebtState {
  final List<Map<String, dynamic>> sales;
  final double totalDebt;
  const CustomerDebtsLoaded({required this.sales, required this.totalDebt});
  @override
  List<Object?> get props => [sales, totalDebt];
}

class SupplierDebtsLoaded extends DebtState {
  final double debt;
  final List<Map<String, dynamic>> payments;
  const SupplierDebtsLoaded({required this.debt, required this.payments});
  @override
  List<Object?> get props => [debt, payments];
}

class DebtPaymentSuccess extends DebtState {
  final String message;
  const DebtPaymentSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class DebtsOverviewLoaded extends DebtState {
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> suppliers;
  final double totalCustomerDebt;
  final double totalSupplierDebt;
  const DebtsOverviewLoaded({
    required this.customers,
    required this.suppliers,
    required this.totalCustomerDebt,
    required this.totalSupplierDebt,
  });
  @override
  List<Object?> get props => [customers, suppliers, totalCustomerDebt, totalSupplierDebt];
}

class DebtError extends DebtState {
  final String message;
  const DebtError(this.message);
  @override
  List<Object?> get props => [message];
}
