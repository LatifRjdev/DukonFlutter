import 'package:equatable/equatable.dart';

abstract class SupplierListEvent extends Equatable {
  const SupplierListEvent();
  @override
  List<Object?> get props => [];
}

class SupplierListLoadRequested extends SupplierListEvent {
  final String storeId;
  final int page;
  final String? search;
  const SupplierListLoadRequested({required this.storeId, this.page = 1, this.search});
  @override
  List<Object?> get props => [storeId, page, search];
}

class SupplierListSearchChanged extends SupplierListEvent {
  final String query;
  const SupplierListSearchChanged(this.query);
  @override
  List<Object?> get props => [query];
}

class SupplierCreateRequested extends SupplierListEvent {
  final String storeId;
  final Map<String, dynamic> data;
  const SupplierCreateRequested({required this.storeId, required this.data});
  @override
  List<Object?> get props => [storeId, data];
}

class SupplierUpdateRequested extends SupplierListEvent {
  final String storeId;
  final String supplierId;
  final Map<String, dynamic> data;
  const SupplierUpdateRequested({
    required this.storeId,
    required this.supplierId,
    required this.data,
  });
  @override
  List<Object?> get props => [storeId, supplierId, data];
}
