import 'package:equatable/equatable.dart';
import '../../../domain/entities/customer.dart';

abstract class CustomerDetailState extends Equatable {
  const CustomerDetailState();
  @override
  List<Object?> get props => [];
}

class CustomerDetailInitial extends CustomerDetailState {}
class CustomerDetailLoading extends CustomerDetailState {}

class CustomerDetailLoaded extends CustomerDetailState {
  final Customer customer;
  final List<Map<String, dynamic>> recentSales;
  const CustomerDetailLoaded({required this.customer, required this.recentSales});
  @override
  List<Object?> get props => [customer, recentSales];
}

class CustomerDetailError extends CustomerDetailState {
  final String message;
  const CustomerDetailError(this.message);
  @override
  List<Object?> get props => [message];
}
