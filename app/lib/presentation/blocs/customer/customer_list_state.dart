import 'package:equatable/equatable.dart';
import '../../../domain/entities/customer.dart';

abstract class CustomerListState extends Equatable {
  const CustomerListState();
  @override
  List<Object?> get props => [];
}

class CustomerListInitial extends CustomerListState {}

class CustomerListLoading extends CustomerListState {}

class CustomerListLoaded extends CustomerListState {
  final List<Customer> customers;
  final int total;
  final int totalPages;
  final int currentPage;
  final String? search;
  const CustomerListLoaded({
    required this.customers,
    required this.total,
    required this.totalPages,
    required this.currentPage,
    this.search,
  });
  @override
  List<Object?> get props => [customers, total, totalPages, currentPage, search];
}

class CustomerListError extends CustomerListState {
  final String message;
  const CustomerListError(this.message);
  @override
  List<Object?> get props => [message];
}
