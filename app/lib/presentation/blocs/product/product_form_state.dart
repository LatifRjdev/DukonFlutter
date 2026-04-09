import 'package:equatable/equatable.dart';

class ProductFormState extends Equatable {
  final int currentStep;
  final Map<String, dynamic> productData;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final String? editingProductId;
  final bool isSuccess;

  const ProductFormState({
    this.currentStep = 0,
    this.productData = const {},
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.editingProductId,
    this.isSuccess = false,
  });

  /// Step 0: Basic info (name, sku, barcode, category, description)
  /// Step 1: Pricing (costPrice, sellPrice, wholesalePrice)
  /// Step 2: Details (quantity, minQuantity, unit, supplier, image)
  static const int stepBasicInfo = 0;
  static const int stepPricing = 1;
  static const int stepDetails = 2;
  static const int totalSteps = 3;

  bool get isEditing => editingProductId != null;

  ProductFormState copyWith({
    int? currentStep,
    Map<String, dynamic>? productData,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    String? editingProductId,
    bool? isSuccess,
  }) {
    return ProductFormState(
      currentStep: currentStep ?? this.currentStep,
      productData: productData ?? this.productData,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      editingProductId: editingProductId ?? this.editingProductId,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  @override
  List<Object?> get props => [
        currentStep,
        productData,
        isLoading,
        isSubmitting,
        error,
        editingProductId,
        isSuccess,
      ];
}
