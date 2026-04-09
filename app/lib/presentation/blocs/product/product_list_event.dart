import 'package:equatable/equatable.dart';

abstract class ProductListEvent extends Equatable {
  const ProductListEvent();
  @override
  List<Object?> get props => [];
}

class ProductListLoadRequested extends ProductListEvent {
  final String storeId;
  final String? search;
  final String? categoryId;
  final int page;
  const ProductListLoadRequested({required this.storeId, this.search, this.categoryId, this.page = 1});
  @override
  List<Object?> get props => [storeId, search, categoryId, page];
}

class ProductListSearchChanged extends ProductListEvent {
  final String query;
  const ProductListSearchChanged(this.query);
  @override
  List<Object?> get props => [query];
}

class ProductListCategoryFilterChanged extends ProductListEvent {
  final String? categoryId;
  const ProductListCategoryFilterChanged(this.categoryId);
  @override
  List<Object?> get props => [categoryId];
}

class ProductDeleteRequested extends ProductListEvent {
  final String storeId;
  final String productId;
  const ProductDeleteRequested({required this.storeId, required this.productId});
  @override
  List<Object?> get props => [storeId, productId];
}
