import 'package:equatable/equatable.dart';
import 'cart_state.dart';

abstract class CheckoutEvent extends Equatable {
  const CheckoutEvent();
  @override
  List<Object?> get props => [];
}

class CheckoutInitiated extends CheckoutEvent {
  final List<CartItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final String? customerId;
  final String? customerName;
  const CheckoutInitiated({
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    this.customerId,
    this.customerName,
  });
  @override
  List<Object?> get props => [items, subtotal, discount, total, customerId];
}

class CheckoutPaymentMethodSelected extends CheckoutEvent {
  final String paymentMethod;
  const CheckoutPaymentMethodSelected(this.paymentMethod);
  @override
  List<Object?> get props => [paymentMethod];
}

class CheckoutDiscountApplied extends CheckoutEvent {
  final double discount;
  final String discountType;
  const CheckoutDiscountApplied({required this.discount, required this.discountType});
  @override
  List<Object?> get props => [discount, discountType];
}

class CheckoutPaidAmountChanged extends CheckoutEvent {
  final double paidAmount;
  const CheckoutPaidAmountChanged(this.paidAmount);
  @override
  List<Object?> get props => [paidAmount];
}

class CheckoutProcessPayment extends CheckoutEvent {
  final String storeId;
  const CheckoutProcessPayment({required this.storeId});
  @override
  List<Object?> get props => [storeId];
}
