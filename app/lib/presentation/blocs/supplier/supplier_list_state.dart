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

class SupplierFormLoading extends SupplierListState {}

class SupplierFormSuccess extends SupplierListState {
  final Supplier supplier;
  final bool isEditing;
  const SupplierFormSuccess({required this.supplier, required this.isEditing});
  @override
  List<Object?> get props => [supplier, isEditing];
}

class SupplierFormError extends SupplierListState {
  final String message;
  const SupplierFormError(this.message);
  @override
  List<Object?> get props => [message];
}
