import 'package:equatable/equatable.dart';
import '../../../domain/entities/supplier.dart';

abstract class SupplierListState extends Equatable {
  const SupplierListState();
  @override
  List<Object?> get props => [];
}

class SupplierListInitial extends SupplierListState {}

class SupplierListLoading extends SupplierListState {}

class SupplierListLoaded extends SupplierListState {
  final List<Supplier> suppliers;
  final int total;
  final int totalPages;
  final int currentPage;
  final String? search;
  const SupplierListLoaded({
    required this.suppliers,
    required this.total,
    required this.totalPages,
    required this.currentPage,
    this.search,
  });
  @override
  List<Object?> get props => [suppliers, total, totalPages, currentPage, search];
}

class SupplierListError extends SupplierListState {
  final String message;
  const SupplierListError(this.message);
  @override
  List<Object?> get props => [message];
}
