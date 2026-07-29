import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/product_repository.dart';
import '../../../domain/repositories/stock_repository.dart';
import 'stock_intake_event.dart';
import 'stock_intake_state.dart';

class StockIntakeBloc extends Bloc<StockIntakeEvent, StockIntakeState> {
  final StockRepository _stockRepository;
  final ProductRepository _productRepository;

  StockIntakeBloc({
    required StockRepository stockRepository,
    required ProductRepository productRepository,
  })  : _stockRepository = stockRepository,
        _productRepository = productRepository,
        super(const StockIntakeState()) {
    on<StockIntakeScanBarcode>(_onScanBarcode);
    on<StockIntakeSelectProduct>(_onSelectProduct);
    on<StockIntakeSetQuantity>(_onSetQuantity);
    on<StockIntakeSetUnitCost>(_onSetUnitCost);
    on<StockIntakeSelectSupplier>(_onSelectSupplier);
    on<StockIntakeSetNotes>(_onSetNotes);
    on<StockIntakeSubmit>(_onSubmit);
    on<StockIntakeReset>(_onReset);
  }

  Future<void> _onScanBarcode(
      StockIntakeScanBarcode event, Emitter<StockIntakeState> emit) async {
    emit(state.copyWith(isSearching: true, error: null));
    try {
      final product =
          await _productRepository.getProductByBarcode(event.storeId, event.barcode);
      emit(state.copyWith(
        selectedProduct: product,
        unitCost: product.costPrice ?? 0,
        isSearching: false,
      ));
    } catch (e) {
      emit(state.copyWith(isSearching: false, error: mapErrorToUserMessage(e)));
    }
  }

  void _onSelectProduct(
      StockIntakeSelectProduct event, Emitter<StockIntakeState> emit) {
    emit(state.copyWith(
      selectedProduct: event.product,
      unitCost: event.product.costPrice ?? 0,
      error: null,
    ));
  }

  void _onSetQuantity(StockIntakeSetQuantity event, Emitter<StockIntakeState> emit) {
    emit(state.copyWith(quantity: event.quantity, error: null));
  }

  void _onSetUnitCost(StockIntakeSetUnitCost event, Emitter<StockIntakeState> emit) {
    emit(state.copyWith(unitCost: event.unitCost, error: null));
  }

  void _onSelectSupplier(
      StockIntakeSelectSupplier event, Emitter<StockIntakeState> emit) {
    if (event.supplier == null) {
      emit(state.copyWith(clearSupplier: true, error: null));
    } else {
      emit(state.copyWith(supplier: event.supplier, error: null));
    }
  }

  void _onSetNotes(StockIntakeSetNotes event, Emitter<StockIntakeState> emit) {
    emit(state.copyWith(notes: event.notes));
  }

  Future<void> _onSubmit(
      StockIntakeSubmit event, Emitter<StockIntakeState> emit) async {
    if (!state.canSubmit) return;
    emit(state.copyWith(isSubmitting: true, error: null));
    try {
      final data = <String, dynamic>{
        'productId': state.selectedProduct!.id,
        'type': 'PURCHASE',
        'quantity': state.quantity,
        'unitCost': state.unitCost,
        if (state.supplier != null) 'supplierId': state.supplier!.id,
        if (state.notes.isNotEmpty) 'notes': state.notes,
      };
      await _stockRepository.createStockMovement(
        event.storeId,
        state.selectedProduct!.id,
        data,
      );
      emit(state.copyWith(isSubmitting: false, isSuccess: true));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: mapErrorToUserMessage(e)));
    }
  }

  void _onReset(StockIntakeReset event, Emitter<StockIntakeState> emit) {
    emit(const StockIntakeState());
  }
}
