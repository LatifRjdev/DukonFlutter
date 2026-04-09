import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/store_repository.dart';
import 'store_event.dart';
import 'store_state.dart';

class StoreBloc extends Bloc<StoreEvent, StoreState> {
  final StoreRepository _storeRepository;

  StoreBloc({required StoreRepository storeRepository})
      : _storeRepository = storeRepository,
        super(StoreInitial()) {
    on<StoreLoadRequested>(_onLoadRequested);
    on<StoreCreateRequested>(_onCreateRequested);
    on<StoreSelected>(_onSelected);
    on<StoreResetRequested>(_onResetRequested);
  }

  Future<void> _onLoadRequested(StoreLoadRequested event, Emitter<StoreState> emit) async {
    emit(StoreLoading());
    try {
      final stores = await _storeRepository.getStores();
      emit(StoreLoaded(stores: stores, selectedStore: stores.isNotEmpty ? stores.first : null));
    } catch (e) {
      emit(StoreError(e.toString()));
    }
  }

  Future<void> _onCreateRequested(StoreCreateRequested event, Emitter<StoreState> emit) async {
    emit(StoreLoading());
    try {
      final store = await _storeRepository.createStore(
        name: event.name,
        category: event.category,
        currency: event.currency,
        address: event.address,
        phone: event.phone,
      );
      final stores = await _storeRepository.getStores();
      emit(StoreLoaded(stores: stores, selectedStore: store));
    } catch (e) {
      emit(StoreError(e.toString()));
    }
  }

  Future<void> _onSelected(StoreSelected event, Emitter<StoreState> emit) async {
    final currentState = state;
    if (currentState is StoreLoaded) {
      final selected = currentState.stores.firstWhere((s) => s.id == event.storeId);
      emit(StoreLoaded(stores: currentState.stores, selectedStore: selected));
    }
  }

  void _onResetRequested(StoreResetRequested event, Emitter<StoreState> emit) {
    emit(StoreInitial());
  }
}
