import 'package:equatable/equatable.dart';
import '../../../domain/entities/product.dart';
import 'cart_state.dart';

abstract class CartEvent extends Equatable {
  const CartEvent();
  @override
  List<Object?> get props => [];
}

class CartItemAdded extends CartEvent {
  final Product product;
  final int quantity;
  const CartItemAdded({required this.product, this.quantity = 1});
  @override
  List<Object?> get props => [product, quantity];
}

class CartItemRemoved extends CartEvent {
  final String productId;
  const CartItemRemoved(this.productId);
  @override
  List<Object?> get props => [productId];
}

class CartItemQuantityChanged extends CartEvent {
  final String productId;
  final int quantity;
  const CartItemQuantityChanged({required this.productId, required this.quantity});
  @override
  List<Object?> get props => [productId, quantity];
}

class CartDiscountApplied extends CartEvent {
  final double discount;
  final String type;
  const CartDiscountApplied({required this.discount, required this.type});
  @override
  List<Object?> get props => [discount, type];
}

class CartCleared extends CartEvent {}

class CartCustomerSelected extends CartEvent {
  final String? customerId;
  final String? customerName;
  final String? storeId;
  const CartCustomerSelected({this.customerId, this.customerName, this.storeId});
  @override
  List<Object?> get props => [customerId, storeId];
}

class LoyaltyBalanceLoaded extends CartEvent {
  final int points;
  final double pointValue;
  const LoyaltyBalanceLoaded({required this.points, required this.pointValue});
  @override
  List<Object?> get props => [points, pointValue];
}

class RedemptionPointsChanged extends CartEvent {
  final int points;
  const RedemptionPointsChanged(this.points);
  @override
  List<Object?> get props => [points];
}

// E.4: emitted when the user accepts the "restore previous cart?"
// prompt at app cold start. Replaces the empty CartState with the
// previously-persisted one.
class CartRestored extends CartEvent {
  final CartState state;
  const CartRestored(this.state);
  @override
  List<Object?> get props => [state];
}
