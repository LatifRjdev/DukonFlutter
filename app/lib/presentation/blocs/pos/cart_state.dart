import 'package:equatable/equatable.dart';

class CartItem {
  final String productId;
  final String productName;
  final double unitPrice;
  final double? costPrice;
  final int quantity;
  final double discount;
  final String unit;
  // Stock on hand (Product.quantity) captured when this line item was
  // added/refreshed by CartBloc._onItemAdded. Null means unknown (e.g.
  // a hand-built CartItem in a test) — in that case CartBloc doesn't
  // clamp CartItemQuantityChanged. SPEC.md #6.
  final int? stockQuantity;

  const CartItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.costPrice,
    required this.quantity,
    this.discount = 0,
    this.unit = 'PCS',
    this.stockQuantity,
  });

  double get total => (unitPrice * quantity) - discount;

  CartItem copyWith({int? quantity, double? discount, int? stockQuantity}) {
    return CartItem(
      productId: productId,
      productName: productName,
      unitPrice: unitPrice,
      costPrice: costPrice,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      unit: unit,
      stockQuantity: stockQuantity ?? this.stockQuantity,
    );
  }
}

class CartState extends Equatable {
  final List<CartItem> items;
  final double discount;
  final String discountType;
  final String? customerId;
  final String? customerName;
  final int customerLoyaltyPoints;
  final double loyaltyPointValue;
  final int redemptionPoints;

  const CartState({
    this.items = const [],
    this.discount = 0,
    this.discountType = 'FIXED',
    this.customerId,
    this.customerName,
    this.customerLoyaltyPoints = 0,
    this.loyaltyPointValue = 0,
    this.redemptionPoints = 0,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);

  double get discountAmount {
    if (discountType == 'PERCENTAGE') return subtotal * discount / 100;
    return discount;
  }

  double get loyaltyRedemptionValue => redemptionPoints * loyaltyPointValue;

  // Clamped at 0 — mirrors CheckoutBloc._onDiscountApplied's own
  // `newTotal > 0 ? newTotal : 0` clamp, so a discount (or loyalty
  // redemption) larger than the subtotal can't produce a negative total
  // here either. This getter is the single place CartState computes the
  // displayed/checkout total from, so clamping here covers every UI
  // surface that reads `cart.total` (POS cart screen, cash/credit payment
  // pages, PosCheckoutPage's CheckoutInitiated). SPEC.md #7.
  double get total {
    final rawTotal = subtotal - discountAmount - loyaltyRedemptionValue;
    return rawTotal > 0 ? rawTotal : 0;
  }
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    double? discount,
    String? discountType,
    String? customerId,
    String? customerName,
    int? customerLoyaltyPoints,
    double? loyaltyPointValue,
    int? redemptionPoints,
  }) {
    return CartState(
      items: items ?? this.items,
      discount: discount ?? this.discount,
      discountType: discountType ?? this.discountType,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerLoyaltyPoints: customerLoyaltyPoints ?? this.customerLoyaltyPoints,
      loyaltyPointValue: loyaltyPointValue ?? this.loyaltyPointValue,
      redemptionPoints: redemptionPoints ?? this.redemptionPoints,
    );
  }

  @override
  List<Object?> get props => [
        items,
        discount,
        discountType,
        customerId,
        customerLoyaltyPoints,
        loyaltyPointValue,
        redemptionPoints,
      ];
}
