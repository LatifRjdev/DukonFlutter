import 'package:equatable/equatable.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/supplier.dart';

abstract class StockIntakeEvent extends Equatable {
  const StockIntakeEvent();
  @override
  List<Object?> get props => [];
}

class StockIntakeScanBarcode extends StockIntakeEvent {
  final String storeId;
  final String barcode;
  const StockIntakeScanBarcode({required this.storeId, required this.barcode});
  @override
  List<Object?> get props => [storeId, barcode];
}

class StockIntakeSelectProduct extends StockIntakeEvent {
  final Product product;
  const StockIntakeSelectProduct(this.product);
  @override
  List<Object?> get props => [product];
}

class StockIntakeSetQuantity extends StockIntakeEvent {
  final int quantity;
  const StockIntakeSetQuantity(this.quantity);
  @override
  List<Object?> get props => [quantity];
}

class StockIntakeSetUnitCost extends StockIntakeEvent {
  final double unitCost;
  const StockIntakeSetUnitCost(this.unitCost);
  @override
  List<Object?> get props => [unitCost];
}

class StockIntakeSelectSupplier extends StockIntakeEvent {
  final Supplier? supplier;
  const StockIntakeSelectSupplier(this.supplier);
  @override
  List<Object?> get props => [supplier];
}

class StockIntakeSetNotes extends StockIntakeEvent {
  final String notes;
  const StockIntakeSetNotes(this.notes);
  @override
  List<Object?> get props => [notes];
}

class StockIntakeSubmit extends StockIntakeEvent {
  final String storeId;
  const StockIntakeSubmit({required this.storeId});
  @override
  List<Object?> get props => [storeId];
}

class StockIntakeReset extends StockIntakeEvent {}
