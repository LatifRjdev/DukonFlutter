import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/product_repository.dart';
import 'product_list_event.dart';
import 'product_list_state.dart';

class ProductListBloc extends Bloc<ProductListEvent, ProductListState> {
  final ProductRepository _productRepository;
  String _storeId = '';

  ProductListBloc({required ProductRepository productRepository})
      : _productRepository = productRepository,
        super(ProductListInitial()) {
    on<ProductListLoadRequested>(_onLoadRequested);
    on<ProductListSearchChanged>(_onSearchChanged);
    on<ProductListCategoryFilterChanged>(_onCategoryFilterChanged);
    on<ProductDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onLoadRequested(ProductListLoadRequested event, Emitter<ProductListState> emit) async {
    _storeId = event.storeId;
    emit(ProductListLoading());
    try {
      final result = await _productRepository.getProducts(
        event.storeId,
        page: event.page,
        search: event.search,
        categoryId: event.categoryId,
      );
      emit(ProductListLoaded(
        products: result.data,
        total: result.total,
        totalPages: result.totalPages,
        currentPage: event.page,
        search: event.search,
        categoryId: event.categoryId,
      ));
    } catch (e) {
      emit(ProductListError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onSearchChanged(ProductListSearchChanged event, Emitter<ProductListState> emit) async {
    add(ProductListLoadRequested(storeId: _storeId, search: event.query));
  }

  Future<void> _onCategoryFilterChanged(ProductListCategoryFilterChanged event, Emitter<ProductListState> emit) async {
    add(ProductListLoadRequested(storeId: _storeId, categoryId: event.categoryId));
  }

  Future<void> _onDeleteRequested(ProductDeleteRequested event, Emitter<ProductListState> emit) async {
    try {
      await _productRepository.deleteProduct(event.storeId, event.productId);
      add(ProductListLoadRequested(storeId: event.storeId));
    } catch (e) {
      emit(ProductListError(mapErrorToUserMessage(e)));
    }
  }
}
