import 'package:equatable/equatable.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/supplier.dart';

class StockIntakeState extends Equatable {
  final Product? selectedProduct;
  final int quantity;
  final double unitCost;
  final Supplier? supplier;
  final String notes;
  final bool isSearching;
  final bool isSubmitting;
  final bool isSuccess;
  final String? error;

  const StockIntakeState({
    this.selectedProduct,
    this.quantity = 0,
    this.unitCost = 0,
    this.supplier,
    this.notes = '',
    this.isSearching = false,
    this.isSubmitting = false,
    this.isSuccess = false,
    this.error,
  });

  double get totalCost => quantity * unitCost;
  bool get canSubmit =>
      selectedProduct != null && quantity > 0 && unitCost > 0;

  StockIntakeState copyWith({
    Product? selectedProduct,
    int? quantity,
    double? unitCost,
    Supplier? supplier,
    String? notes,
    bool? isSearching,
    bool? isSubmitting,
    bool? isSuccess,
    String? error,
    bool clearProduct = false,
    bool clearSupplier = false,
  }) {
    return StockIntakeState(
      selectedProduct: clearProduct ? null : (selectedProduct ?? this.selectedProduct),
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      supplier: clearSupplier ? null : (supplier ?? this.supplier),
      notes: notes ?? this.notes,
      isSearching: isSearching ?? this.isSearching,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        selectedProduct,
        quantity,
        unitCost,
        supplier,
        notes,
        isSearching,
        isSubmitting,
        isSuccess,
        error,
      ];
}
