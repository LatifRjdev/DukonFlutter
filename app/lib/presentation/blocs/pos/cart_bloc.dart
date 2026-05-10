import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/datasources/local/cart_local_datasource.dart';
import 'cart_event.dart';
import 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  // E.4: optional persistence. When provided, every state change
  // writes the cart to SharedPreferences (debounced) so a process
  // kill mid-cart doesn't lose the cashier's work. Restore happens
  // explicitly via CartRestored — we never auto-restore silently.
  final CartLocalDatasource? _persistence;
  Timer? _persistTimer;

  CartBloc({CartLocalDatasource? persistence})
      : _persistence = persistence,
        super(const CartState()) {
    on<CartItemAdded>(_onItemAdded);
    on<CartItemRemoved>(_onItemRemoved);
    on<CartItemQuantityChanged>(_onQuantityChanged);
    on<CartDiscountApplied>(_onDiscountApplied);
    on<CartCleared>(_onCleared);
    on<CartCustomerSelected>(_onCustomerSelected);
    on<CartRestored>(_onRestored);
  }

  void _schedulePersist() {
    if (_persistence == null) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), () {
      if (state.isEmpty) {
        _persistence.clear();
      } else {
        _persistence.save(state);
      }
    });
  }

  @override
  Future<void> close() {
    _persistTimer?.cancel();
    return super.close();
  }

  void _onItemAdded(CartItemAdded event, Emitter<CartState> emit) {
    final items = List<CartItem>.from(state.items);
    final existingIndex = items.indexWhere((i) => i.productId == event.product.id);

    if (existingIndex >= 0) {
      final existing = items[existingIndex];
      items[existingIndex] = existing.copyWith(quantity: existing.quantity + event.quantity);
    } else {
      items.add(CartItem(
        productId: event.product.id,
        productName: event.product.name,
        unitPrice: event.product.sellPrice,
        costPrice: event.product.costPrice,
        quantity: event.quantity,
        unit: event.product.unit,
      ));
    }
    emit(state.copyWith(items: items));
    _schedulePersist();
  }

  void _onItemRemoved(CartItemRemoved event, Emitter<CartState> emit) {
    final items = state.items.where((i) => i.productId != event.productId).toList();
    emit(state.copyWith(items: items));
    _schedulePersist();
  }

  void _onQuantityChanged(CartItemQuantityChanged event, Emitter<CartState> emit) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((i) => i.productId == event.productId);
    if (index >= 0) {
      if (event.quantity <= 0) {
        items.removeAt(index);
      } else {
        items[index] = items[index].copyWith(quantity: event.quantity);
      }
    }
    emit(state.copyWith(items: items));
    _schedulePersist();
  }

  void _onDiscountApplied(CartDiscountApplied event, Emitter<CartState> emit) {
    emit(state.copyWith(discount: event.discount, discountType: event.type));
    _schedulePersist();
  }

  void _onCleared(CartCleared event, Emitter<CartState> emit) {
    emit(const CartState());
    // Cleared usually means checkout completed — drop the persisted
    // cart immediately rather than waiting for the debounce.
    _persistTimer?.cancel();
    _persistence?.clear();
  }

  void _onCustomerSelected(CartCustomerSelected event, Emitter<CartState> emit) {
    emit(state.copyWith(customerId: event.customerId, customerName: event.customerName));
    _schedulePersist();
  }

  void _onRestored(CartRestored event, Emitter<CartState> emit) {
    emit(event.state);
    // Don't re-persist on restore — would be redundant.
  }
}
