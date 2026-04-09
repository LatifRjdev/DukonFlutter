import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/product_repository.dart';
import 'product_form_event.dart';
import 'product_form_state.dart';

class ProductFormBloc extends Bloc<ProductFormEvent, ProductFormState> {
  final ProductRepository _productRepository;

  ProductFormBloc({required ProductRepository productRepository})
      : _productRepository = productRepository,
        super(const ProductFormState()) {
    on<ProductFormUpdateStep>(_onUpdateStep);
    on<ProductFormSaveStep>(_onSaveStep);
    on<ProductFormSubmit>(_onSubmit);
    on<ProductFormLoadProduct>(_onLoadProduct);
    on<ProductFormReset>(_onReset);
  }

  void _onUpdateStep(ProductFormUpdateStep event, Emitter<ProductFormState> emit) {
    emit(state.copyWith(currentStep: event.step, error: null));
  }

  void _onSaveStep(ProductFormSaveStep event, Emitter<ProductFormState> emit) {
    final updatedData = Map<String, dynamic>.from(state.productData)..addAll(event.data);
    final nextStep = event.step + 1;
    emit(state.copyWith(
      productData: updatedData,
      currentStep: nextStep < ProductFormState.totalSteps ? nextStep : state.currentStep,
      error: null,
    ));
  }

  Future<void> _onSubmit(ProductFormSubmit event, Emitter<ProductFormState> emit) async {
    emit(state.copyWith(isSubmitting: true, error: null));
    try {
      if (state.isEditing) {
        await _productRepository.updateProduct(
          event.storeId,
          state.editingProductId!,
          state.productData,
        );
      } else {
        await _productRepository.createProduct(event.storeId, state.productData);
      }
      emit(state.copyWith(isSubmitting: false, isSuccess: true));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: e.toString()));
    }
  }

  Future<void> _onLoadProduct(ProductFormLoadProduct event, Emitter<ProductFormState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final product = await _productRepository.getProduct(event.storeId, event.productId);
      final data = <String, dynamic>{
        'name': product.name,
        'sku': product.sku,
        'barcode': product.barcode,
        'categoryId': product.categoryId,
        'description': product.description,
        'costPrice': product.costPrice,
        'sellPrice': product.sellPrice,
        'wholesalePrice': product.wholesalePrice,
        'quantity': product.quantity,
        'minQuantity': product.minQuantity,
        'unit': product.unit,
        'supplierId': product.supplierId,
        'imageUrl': product.imageUrl,
      };
      emit(state.copyWith(
        isLoading: false,
        productData: data,
        editingProductId: product.id,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onReset(ProductFormReset event, Emitter<ProductFormState> emit) {
    emit(const ProductFormState());
  }
}
