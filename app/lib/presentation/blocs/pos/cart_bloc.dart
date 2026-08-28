import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/datasources/local/cart_local_datasource.dart';
import '../../../domain/repositories/loyalty_repository.dart';
import 'cart_event.dart';
import 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  // E.4: optional persistence. When provided, every state change
  // writes the cart to SharedPreferences (debounced) so a process
  // kill mid-cart doesn't lose the cashier's work. Restore happens
  // explicitly via CartRestored — we never auto-restore silently.
  final CartLocalDatasource? _persistence;
  final LoyaltyRepository? _loyaltyRepository;
  Timer? _persistTimer;

  CartBloc({CartLocalDatasource? persistence, LoyaltyRepository? loyaltyRepository})
      : _persistence = persistence,
        _loyaltyRepository = loyaltyRepository,
        super(const CartState()) {
    on<CartItemAdded>(_onItemAdded);
    on<CartItemRemoved>(_onItemRemoved);
    on<CartItemQuantityChanged>(_onQuantityChanged);
    on<CartDiscountApplied>(_onDiscountApplied);
    on<CartCleared>(_onCleared);
    on<CartCustomerSelected>(_onCustomerSelected);
    on<CartRestored>(_onRestored);
    on<LoyaltyBalanceLoaded>(_onLoyaltyBalanceLoaded);
    on<RedemptionPointsChanged>(_onRedemptionPointsChanged);
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
      final stock = event.product.quantity;
      final requestedQuantity = existing.quantity + event.quantity;
      items[existingIndex] = existing.copyWith(
        // Clamp to stock on hand — mirrors _onQuantityChanged's clamp so
        // a product added to the cart multiple times (e.g. scanned or
        // tapped again) can't silently exceed stock either. SPEC.md #6.
        quantity: requestedQuantity > stock ? stock : requestedQuantity,
        // Refresh the captured stock in case it changed (restock, sale
        // elsewhere) since the item was first added. SPEC.md #6.
        stockQuantity: stock,
      );
    } else {
      final stock = event.product.quantity;
      // Clamp to stock on hand — mirrors the bump branch above and
      // _onQuantityChanged's clamp so a brand-new cart line can't start
      // out exceeding stock either (e.g. tapping an out-of-stock
      // product's quick-add / "Продать" button). SPEC.md #6.
      final requestedQuantity = event.quantity > stock ? stock : event.quantity;
      // If there's no stock to give at all, don't add a quantity-0 line
      // item — same precedent as _onQuantityChanged removing an item
      // whose clamped quantity drops to <=0.
      if (requestedQuantity > 0) {
        items.add(CartItem(
          productId: event.product.id,
          productName: event.product.name,
          unitPrice: event.product.sellPrice,
          costPrice: event.product.costPrice,
          quantity: requestedQuantity,
          unit: event.product.unit,
          // Captured regardless of which screen dispatched CartItemAdded
          // (POS quick-add, product-detail "Продать", ...) — this is the
          // single, bypass-proof place every add-to-cart path passes
          // through. SPEC.md #6.
          stockQuantity: stock,
        ));
      }
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
      final item = items[index];
      final stock = item.stockQuantity;
      // Clamp to stock on hand rather than applying the requested value
      // verbatim — enforced here so it covers every path an item can
      // reach the cart through (POS quick-add, product-detail "Продать",
      // cart restore), not just the one screen that dispatched this
      // particular event. SPEC.md #6.
      final requestedQuantity = (stock != null && event.quantity > stock)
          ? stock
          : event.quantity;
      if (requestedQuantity <= 0) {
        items.removeAt(index);
      } else {
        items[index] = item.copyWith(quantity: requestedQuantity);
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

  Future<void> _onCustomerSelected(CartCustomerSelected event, Emitter<CartState> emit) async {
    if (event.customerId == null) {
      emit(CartState(
        items: state.items,
        discount: state.discount,
        discountType: state.discountType,
      ));
      _schedulePersist();
      return;
    }
    emit(state.copyWith(
      customerId: event.customerId,
      customerName: event.customerName,
      redemptionPoints: 0,
    ));
    _schedulePersist();

    final repo = _loyaltyRepository;
    final storeId = event.storeId;
    final customerId = event.customerId;
    if (repo != null && storeId != null && customerId != null) {
      try {
        final results = await Future.wait([
          repo.getCustomerBalance(storeId, customerId),
          repo.getSettings(storeId),
        ]);
        final balance = results[0] as ({int points, List transactions});
        final settings = results[1] as Map<String, dynamic>;
        final pointValue = (settings['pointValue'] as num?)?.toDouble() ?? 0.01;
        if (!isClosed) {
          add(LoyaltyBalanceLoaded(points: balance.points, pointValue: pointValue));
        }
      } catch (_) {
        // loyalty unavailable — POS continues normally
      }
    }
  }

  void _onLoyaltyBalanceLoaded(LoyaltyBalanceLoaded event, Emitter<CartState> emit) {
    emit(state.copyWith(
      customerLoyaltyPoints: event.points,
      loyaltyPointValue: event.pointValue,
    ));
  }

  void _onRedemptionPointsChanged(RedemptionPointsChanged event, Emitter<CartState> emit) {
    final maxByBalance = state.customerLoyaltyPoints;
    final maxByTotal = state.loyaltyPointValue > 0
        ? (state.subtotal - state.discountAmount) ~/ state.loyaltyPointValue
        : 0;
    final cap = maxByBalance < maxByTotal ? maxByBalance : maxByTotal;
    emit(state.copyWith(redemptionPoints: event.points.clamp(0, cap)));
    _schedulePersist();
  }

  void _onRestored(CartRestored event, Emitter<CartState> emit) {
    emit(event.state);
    // Don't re-persist on restore — would be redundant.
  }
}
