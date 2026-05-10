import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../presentation/blocs/pos/cart_state.dart';

/// E.4: Cart persistence so a process kill mid-cart doesn't drop the
/// cashier's work. We persist as JSON to SharedPreferences (small,
/// synchronous-ish, no SQLDelight ceremony for what is effectively a
/// scratchpad). Pair with CartBloc which writes on every state change
/// (debounced) and clears after checkout.
class CartLocalDatasource {
  static const _key = 'pos.cart.v1';
  static const _savedAtKey = 'pos.cart.savedAt.v1';

  final SharedPreferences _prefs;

  CartLocalDatasource(this._prefs);

  Future<void> save(CartState state) async {
    final json = {
      'items': state.items
          .map((it) => {
                'productId': it.productId,
                'productName': it.productName,
                'unitPrice': it.unitPrice,
                'costPrice': it.costPrice,
                'quantity': it.quantity,
                'discount': it.discount,
                'unit': it.unit,
              })
          .toList(),
      'discount': state.discount,
      'discountType': state.discountType,
      'customerId': state.customerId,
      'customerName': state.customerName,
    };
    await _prefs.setString(_key, jsonEncode(json));
    await _prefs.setInt(
      _savedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Returns null when there is nothing persisted. Caller decides
  /// whether to prompt the user before restoring (we don't auto-
  /// restore because a yesterday's-cart surprise is worse than
  /// retyping a few lines).
  ({CartState state, DateTime savedAt})? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final items = (json['items'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .map((m) => CartItem(
                productId: m['productId'] as String,
                productName: m['productName'] as String,
                unitPrice: (m['unitPrice'] as num).toDouble(),
                costPrice: (m['costPrice'] as num?)?.toDouble(),
                quantity: m['quantity'] as int,
                discount: (m['discount'] as num? ?? 0).toDouble(),
                unit: (m['unit'] as String?) ?? 'PCS',
              ))
          .toList();
      if (items.isEmpty) return null;
      final state = CartState(
        items: items,
        discount: (json['discount'] as num? ?? 0).toDouble(),
        discountType: (json['discountType'] as String?) ?? 'FIXED',
        customerId: json['customerId'] as String?,
        customerName: json['customerName'] as String?,
      );
      final savedAtMs = _prefs.getInt(_savedAtKey) ?? 0;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
      return (state: state, savedAt: savedAt);
    } catch (_) {
      // Corrupt payload — discard.
      return null;
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
    await _prefs.remove(_savedAtKey);
  }
}
