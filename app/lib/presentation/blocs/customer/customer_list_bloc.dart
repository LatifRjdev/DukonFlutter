import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/customer_repository.dart';
import 'customer_list_event.dart';
import 'customer_list_state.dart';

class CustomerListBloc extends Bloc<CustomerListEvent, CustomerListState> {
  final CustomerRepository _customerRepository;

  CustomerListBloc({required CustomerRepository customerRepository})
      : _customerRepository = customerRepository,
        super(CustomerListInitial()) {
    on<CustomerListLoadRequested>(_onLoadRequested);
    on<CustomerListSearchChanged>(_onSearchChanged);
  }

  String _storeId = '';

  Future<void> _onLoadRequested(
    CustomerListLoadRequested event,
    Emitter<CustomerListState> emit,
  ) async {
    emit(CustomerListLoading());
    _storeId = event.storeId;
    try {
      final result = await _customerRepository.getCustomers(
        event.storeId,
        page: event.page,
        search: event.search,
      );
      emit(CustomerListLoaded(
        customers: result.data,
        total: result.total,
        totalPages: result.totalPages,
        currentPage: event.page,
        search: event.search,
      ));
    } catch (e) {
      emit(CustomerListError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onSearchChanged(
    CustomerListSearchChanged event,
    Emitter<CustomerListState> emit,
  ) async {
    final query = event.query.isEmpty ? null : event.query;
    add(CustomerListLoadRequested(storeId: _storeId, search: query));
  }
}
