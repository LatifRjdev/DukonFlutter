import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../data/datasources/local/selected_store_local_datasource.dart';
import '../../../domain/entities/store.dart';
import '../../../domain/repositories/store_repository.dart';
import 'store_event.dart';
import 'store_state.dart';

class StoreBloc extends Bloc<StoreEvent, StoreState> {
  final StoreRepository _storeRepository;

  /// Optional so tests and previews can build the bloc without SharedPreferences.
  final SelectedStoreLocalDatasource? _selection;

  StoreBloc({
    required StoreRepository storeRepository,
    SelectedStoreLocalDatasource? selection,
  })  : _storeRepository = storeRepository,
        _selection = selection,
        super(StoreInitial()) {
    on<StoreLoadRequested>(_onLoadRequested);
    on<StoreCreateRequested>(_onCreateRequested);
    on<StoreSelected>(_onSelected);
    on<StoreResetRequested>(_onResetRequested);
  }

  Future<void> _onLoadRequested(StoreLoadRequested event, Emitter<StoreState> emit) async {
    // Keep the active store across a reload. This handler runs on cold start,
    // on pull to refresh and after editing a store, so unconditionally
    // selecting `stores.first` silently moved the user to a different store —
    // and now that the store-scoped blocs follow the selection, every screen
    // would reload with that other store's data.
    final current = state;
    // In-memory selection first; on a cold start there is none, so fall back
    // to the remembered one. A remembered id that no longer belongs to this
    // account simply will not match below.
    final selectedId = current is StoreLoaded
        ? current.selectedStore?.id
        : _selection?.read();
    emit(StoreLoading());
    try {
      final stores = await _storeRepository.getStores();
      Store? retained;
      for (final store in stores) {
        if (store.id == selectedId) {
          retained = store;
          break;
        }
      }
      emit(StoreLoaded(
        stores: stores,
        selectedStore: retained ?? (stores.isNotEmpty ? stores.first : null),
      ));
    } catch (e) {
      emit(StoreError(mapErrorToAppMessage(e)));
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
      emit(StoreError(mapErrorToAppMessage(e)));
    }
  }

  Future<void> _onSelected(StoreSelected event, Emitter<StoreState> emit) async {
    final currentState = state;
    if (currentState is StoreLoaded) {
      final selected = currentState.stores.firstWhere((s) => s.id == event.storeId);
      await _selection?.save(selected.id);
      emit(StoreLoaded(stores: currentState.stores, selectedStore: selected));
    }
  }

  Future<void> _onResetRequested(
      StoreResetRequested event, Emitter<StoreState> emit) async {
    // Dispatched on sign-out: drop the remembered store with the session.
    await _selection?.clear();
    emit(StoreInitial());
  }
}
