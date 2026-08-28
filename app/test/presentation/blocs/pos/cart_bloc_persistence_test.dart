import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dukonpro/data/datasources/local/cart_local_datasource.dart';
import 'package:dukonpro/domain/entities/product.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_bloc.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_event.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_state.dart';

Product _makeProduct({
  String id = 'p1',
  String name = 'Apple',
  double sellPrice = 5.0,
  // Defaults to plenty of stock headroom so tests unrelated to SPEC.md #6's
  // stock clamp don't get incidentally clamped — the one test that
  // specifically exercises the clamp passes an explicit low value.
  int quantity = 100,
}) {
  return Product(
    id: id,
    storeId: 'store-1',
    name: name,
    sellPrice: sellPrice,
    quantity: quantity,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('CartBloc persistence', () {
    late CartLocalDatasource datasource;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      datasource = CartLocalDatasource(prefs);
    });

    test('should not persist before the 400ms debounce fires', () async {
      final bloc = CartBloc(persistence: datasource);
      bloc.add(CartItemAdded(product: _makeProduct()));

      // Immediately after adding — debounce timer hasn't fired yet
      final loaded = datasource.load();
      expect(loaded, isNull);

      await bloc.close();
    });

    test('should persist cart to SharedPreferences after 400ms debounce',
        () async {
      final bloc = CartBloc(persistence: datasource);
      bloc.add(CartItemAdded(product: _makeProduct()));

      // Advance past the 400ms debounce
      await Future<void>.delayed(const Duration(milliseconds: 450));

      final loaded = datasource.load();
      expect(loaded, isNotNull);
      expect(loaded!.state.items, hasLength(1));
      expect(loaded.state.items.first.productId, 'p1');

      await bloc.close();
    });

    test('should emit restored items after CartRestored event', () async {
      const savedItem = CartItem(
        productId: 'p-restore',
        productName: 'Restored Product',
        unitPrice: 15.0,
        quantity: 3,
      );
      const savedState = CartState(items: [savedItem]);
      await datasource.save(savedState);

      final bloc = CartBloc(persistence: datasource);
      final states = <CartState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const CartRestored(savedState));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states, hasLength(1));
      expect(states.first.items, hasLength(1));
      expect(states.first.items.first.productId, 'p-restore');

      await bloc.close();
    });

    // SPEC.md #6: cart_restore_prompt.dart dispatches CartRestored straight
    // into CartBloc, bypassing PosCheckoutPage. For the stock clamp to
    // survive a process-kill-and-restore, stockQuantity has to round-trip
    // through save/load, not just live in memory.
    test('round-trips stockQuantity through save/load so a restored cart '
        'still has its stock clamp enforced', () async {
      final bloc = CartBloc(persistence: datasource);
      bloc.add(CartItemAdded(product: _makeProduct(quantity: 4)));
      await Future<void>.delayed(const Duration(milliseconds: 450));
      await bloc.close();

      final loaded = datasource.load();
      expect(loaded, isNotNull);
      expect(loaded!.state.items.first.stockQuantity, 4);

      final restoredBloc = CartBloc();
      restoredBloc.add(CartRestored(loaded.state));
      restoredBloc.add(
        const CartItemQuantityChanged(productId: 'p1', quantity: 999),
      );
      await Future<void>.delayed(Duration.zero);

      expect(restoredBloc.state.items.first.quantity, 4);

      await restoredBloc.close();
    });
  });
}
