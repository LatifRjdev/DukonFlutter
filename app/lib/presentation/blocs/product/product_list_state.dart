import 'package:equatable/equatable.dart';
import '../../../domain/entities/product.dart';

abstract class ProductListState extends Equatable {
  const ProductListState();
  @override
  List<Object?> get props => [];
}

class ProductListInitial extends ProductListState {}
class ProductListLoading extends ProductListState {}

class ProductListLoaded extends ProductListState {
  final List<Product> products;
  final int total;
  final int totalPages;
  final int currentPage;
  final String? search;
  final String? categoryId;
  const ProductListLoaded({
    required this.products,
    required this.total,
    required this.totalPages,
    this.currentPage = 1,
    this.search,
    this.categoryId,
  });
  @override
  List<Object?> get props => [products, total, currentPage, search, categoryId];
}

class ProductListError extends ProductListState {
  final String message;
  const ProductListError(this.message);
  @override
  List<Object?> get props => [message];
}
