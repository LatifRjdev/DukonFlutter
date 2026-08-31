import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/supplier_repository.dart';
import 'supplier_list_event.dart';
import 'supplier_list_state.dart';

class SupplierListBloc extends Bloc<SupplierListEvent, SupplierListState> {
  final SupplierRepository _supplierRepository;

  SupplierListBloc({required SupplierRepository supplierRepository})
      : _supplierRepository = supplierRepository,
        super(SupplierListInitial()) {
    on<SupplierListLoadRequested>(_onLoadRequested);
    on<SupplierListSearchChanged>(_onSearchChanged);
    on<SupplierCreateRequested>(_onCreateRequested);
    on<SupplierUpdateRequested>(_onUpdateRequested);
  }

  String _storeId = '';

  Future<void> _onLoadRequested(
    SupplierListLoadRequested event,
    Emitter<SupplierListState> emit,
  ) async {
    emit(SupplierListLoading());
    _storeId = event.storeId;
    try {
      final result = await _supplierRepository.getSuppliers(
        event.storeId,
        page: event.page,
        search: event.search,
      );
      emit(SupplierListLoaded(
        suppliers: result.data,
        total: result.total,
        totalPages: result.totalPages,
        currentPage: event.page,
        search: event.search,
      ));
    } catch (e) {
      emit(SupplierListError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onSearchChanged(
    SupplierListSearchChanged event,
    Emitter<SupplierListState> emit,
  ) async {
    final query = event.query.isEmpty ? null : event.query;
    add(SupplierListLoadRequested(storeId: _storeId, search: query));
  }

  Future<void> _onCreateRequested(
    SupplierCreateRequested event,
    Emitter<SupplierListState> emit,
  ) async {
    emit(SupplierFormLoading());
    try {
      final supplier = await _supplierRepository.createSupplier(event.storeId, event.data);
      emit(SupplierFormSuccess(supplier: supplier, isEditing: false));
    } catch (e) {
      emit(SupplierFormError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onUpdateRequested(
    SupplierUpdateRequested event,
    Emitter<SupplierListState> emit,
  ) async {
    emit(SupplierFormLoading());
    try {
      final supplier = await _supplierRepository.updateSupplier(
        event.storeId,
        event.supplierId,
        event.data,
      );
      emit(SupplierFormSuccess(supplier: supplier, isEditing: true));
    } catch (e) {
      emit(SupplierFormError(mapErrorToUserMessage(e)));
    }
  }
}
