import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/product_repository.dart';
import 'product_list_event.dart';
import 'product_list_state.dart';

class ProductListBloc extends Bloc<ProductListEvent, ProductListState> {
  final ProductRepository _productRepository;
  String _storeId = '';

  /// The request currently being served, if any.
  ///
  /// Two screens share this bloc and both load it: the Товары tab and the POS
  /// till, which keeps its own copy of the store id. `HomePage` builds every
  /// tab into an `IndexedStack`, so both are mounted and both react to a store
  /// change — firing two identical requests for the slowest list in the app.
  /// Deduplicating here rather than at either call site keeps it true for
  /// whoever loads this bloc next.
  ///
  /// Only an identical in-flight request is dropped: a search, a category
  /// filter or another page differs by [ProductListLoadRequested]'s props and
  /// still goes through, as does any repeat once the first has finished — so
  /// pull to refresh keeps working.
  ProductListLoadRequested? _inFlight;

  ProductListBloc({required ProductRepository productRepository})
      : _productRepository = productRepository,
        super(ProductListInitial()) {
    on<ProductListLoadRequested>(_onLoadRequested);
    on<ProductListSearchChanged>(_onSearchChanged);
    on<ProductListCategoryFilterChanged>(_onCategoryFilterChanged);
    on<ProductDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onLoadRequested(ProductListLoadRequested event, Emitter<ProductListState> emit) async {
    if (_inFlight == event) return;
    _inFlight = event;
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
    } finally {
      // Cleared even on failure, so a retry of the same request is allowed.
      if (_inFlight == event) _inFlight = null;
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
