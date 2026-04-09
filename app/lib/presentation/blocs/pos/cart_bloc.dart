import 'package:flutter_bloc/flutter_bloc.dart';
import 'cart_event.dart';
import 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartState()) {
    on<CartItemAdded>(_onItemAdded);
    on<CartItemRemoved>(_onItemRemoved);
    on<CartItemQuantityChanged>(_onQuantityChanged);
    on<CartDiscountApplied>(_onDiscountApplied);
    on<CartCleared>(_onCleared);
    on<CartCustomerSelected>(_onCustomerSelected);
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
  }

  void _onItemRemoved(CartItemRemoved event, Emitter<CartState> emit) {
    final items = state.items.where((i) => i.productId != event.productId).toList();
    emit(state.copyWith(items: items));
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
  }

  void _onDiscountApplied(CartDiscountApplied event, Emitter<CartState> emit) {
    emit(state.copyWith(discount: event.discount, discountType: event.type));
  }

  void _onCleared(CartCleared event, Emitter<CartState> emit) {
    emit(const CartState());
  }

  void _onCustomerSelected(CartCustomerSelected event, Emitter<CartState> emit) {
    emit(state.copyWith(customerId: event.customerId, customerName: event.customerName));
  }
}
