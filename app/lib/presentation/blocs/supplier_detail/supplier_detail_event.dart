import 'package:equatable/equatable.dart';

abstract class SupplierDetailEvent extends Equatable {
  const SupplierDetailEvent();
  @override
  List<Object?> get props => [];
}

class SupplierDetailRequested extends SupplierDetailEvent {
  final String storeId;
  final String supplierId;
  const SupplierDetailRequested({required this.storeId, required this.supplierId});
  @override
  List<Object?> get props => [storeId, supplierId];
}
