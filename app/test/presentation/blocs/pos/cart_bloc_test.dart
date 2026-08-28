import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/product.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_bloc.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_event.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_state.dart';

// Core cart math + item mutation coverage for CartBloc.
//
// NOTE: loyalty balance loading / redemption capping is covered by
// cart_bloc_loyalty_test.dart, and SharedPreferences persistence/restore
// is covered by cart_bloc_persistence_test.dart — this file intentionally
// does not duplicate either.

Product _makeProduct({
  String id = 'p1',
  String name = 'Apple',
  double sellPrice = 10.0,
  double? costPrice = 5.0,
  String unit = 'PCS',
  // Defaults to plenty of stock headroom so tests unrelated to SPEC.md #6's
  // stock clamp don't get incidentally clamped — tests that specifically
  // exercise the clamp (0-stock, exceeding-stock cases) pass an explicit
  // low value.
  int quantity = 100,
}) {
  return Product(
    id: id,
    storeId: 'store-1',
    name: name,
    sellPrice: sellPrice,
    costPrice: costPrice,
    unit: unit,
    quantity: quantity,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('CartBloc', () {
    test('initial state is an empty cart with FIXED discount type', () {
      final bloc = CartBloc();
      expect(bloc.state.items, isEmpty);
      expect(bloc.state.discount, 0);
      expect(bloc.state.discountType, 'FIXED');
      expect(bloc.state.total, 0);
      expect(bloc.state.isEmpty, isTrue);
      expect(bloc.state.customerId, isNull);
      expect(bloc.state.redemptionPoints, 0);
    });

    group('CartItemAdded', () {
      blocTest<CartBloc, CartState>(
        'adds a new product as a new line item',
        build: () => CartBloc(),
        act: (bloc) => bloc.add(CartItemAdded(product: _makeProduct())),
        expect: () => [
          isA<CartState>()
              .having((s) => s.items.length, 'items.length', 1)
              .having((s) => s.items.first.productId, 'productId', 'p1')
              .having((s) => s.items.first.quantity, 'quantity', 1)
              .having((s) => s.items.first.unitPrice, 'unitPrice', 10.0)
              .having((s) => s.items.first.costPrice, 'costPrice', 5.0),
        ],
      );

      blocTest<CartBloc, CartState>(
        'respects a custom quantity when provided',
        build: () => CartBloc(),
        act: (bloc) =>
            bloc.add(CartItemAdded(product: _makeProduct(), quantity: 4)),
        expect: () => [
          isA<CartState>().having((s) => s.items.first.quantity, 'quantity', 4),
        ],
      );

      blocTest<CartBloc, CartState>(
        'increments quantity instead of duplicating the line item when the '
        'same product is added again',
        build: () => CartBloc(),
        seed: () => CartState(
          items: [
            const CartItem(
              productId: 'p1',
              productName: 'Apple',
              unitPrice: 10.0,
              quantity: 2,
            ),
          ],
        ),
        // Plenty of stock headroom — this test is about merge-not-duplicate
        // behavior, not the stock clamp (see the dedicated clamp test below).
        act: (bloc) => bloc.add(CartItemAdded(product: _makeProduct(quantity: 10))),
        expect: () => [
          isA<CartState>()
              .having((s) => s.items.length, 'items.length', 1)
              .having((s) => s.items.first.quantity, 'quantity', 3),
        ],
      );

      // SPEC.md #6 (remaining gap): the "+" stepper's clamp
      // (CartItemQuantityChanged) isn't the only way an existing line
      // item's quantity can grow — dispatching CartItemAdded again for a
      // product already in the cart (POS quick-add tile, product-detail
      // "Продать" button) bumps quantity too, and that bump must clamp to
      // stock on hand exactly like the stepper does.
      blocTest<CartBloc, CartState>(
        'clamps quantity to stock on hand when the same product is added '
        'multiple times via CartItemAdded (repeated scan/tap), not just '
        'via the "+" stepper',
        build: () => CartBloc(),
        act: (bloc) {
          bloc.add(CartItemAdded(product: _makeProduct(quantity: 3), quantity: 2));
          bloc.add(CartItemAdded(product: _makeProduct(quantity: 3), quantity: 2));
        },
        expect: () => [
          isA<CartState>()
              .having((s) => s.items.length, 'items.length', 1)
              .having((s) => s.items.first.quantity, 'quantity', 2)
              .having((s) => s.items.first.stockQuantity, 'stockQuantity', 3),
          isA<CartState>()
              .having((s) => s.items.length, 'items.length', 1)
              .having((s) => s.items.first.quantity, 'quantity', 3)
              .having((s) => s.items.first.stockQuantity, 'stockQuantity', 3),
        ],
      );

      blocTest<CartBloc, CartState>(
        'adds distinct products as separate line items',
        build: () => CartBloc(),
        seed: () => CartState(
          items: [
            const CartItem(
              productId: 'p1',
              productName: 'Apple',
              unitPrice: 10.0,
              quantity: 1,
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          CartItemAdded(product: _makeProduct(id: 'p2', name: 'Banana', sellPrice: 3)),
        ),
        expect: () => [
          isA<CartState>().having((s) => s.items.length, 'items.length', 2),
        ],
      );

      // SPEC.md #6: stockQuantity must be captured from event.product.quantity
      // on EVERY CartItemAdded dispatch, regardless of which screen (POS
      // quick-add, product-detail "Продать") triggered it — this is what
      // makes the clamp in CartItemQuantityChanged bypass-proof.
      blocTest<CartBloc, CartState>(
        'captures stockQuantity from the product on a brand-new line item',
        build: () => CartBloc(),
        act: (bloc) => bloc.add(
          CartItemAdded(product: _makeProduct(quantity: 7)),
        ),
        expect: () => [
          isA<CartState>()
              .having((s) => s.items.first.stockQuantity, 'stockQuantity', 7),
        ],
      );

      blocTest<CartBloc, CartState>(
        'refreshes stockQuantity when the same product is added again '
        '(e.g. restocked since it was first added)',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(
              productId: 'p1',
              productName: 'Apple',
              unitPrice: 10.0,
              quantity: 2,
              stockQuantity: 3,
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          CartItemAdded(product: _makeProduct(quantity: 9)),
        ),
        expect: () => [
          isA<CartState>()
              .having((s) => s.items.first.stockQuantity, 'stockQuantity', 9),
        ],
      );

      // SPEC.md #6 (final gap): the else branch of _onItemAdded — creating
      // a brand-new cart line item — never compared event.quantity to
      // event.product.quantity, so tapping an out-of-stock product (POS
      // quick-add tile, product-detail "Продать" button, neither of which
      // pre-check stock) created a quantity-1 line item against 0 stock.
      blocTest<CartBloc, CartState>(
        'does not add a line item for a brand-new product with 0 stock',
        build: () => CartBloc(),
        act: (bloc) =>
            bloc.add(CartItemAdded(product: _makeProduct(quantity: 0))),
        expect: () => [
          isA<CartState>().having((s) => s.items, 'items', isEmpty),
        ],
      );

      blocTest<CartBloc, CartState>(
        'clamps the requested quantity to stock on hand for a brand-new '
        'line item',
        build: () => CartBloc(),
        act: (bloc) => bloc.add(
          CartItemAdded(product: _makeProduct(quantity: 2), quantity: 5),
        ),
        expect: () => [
          isA<CartState>()
              .having((s) => s.items.length, 'items.length', 1)
              .having((s) => s.items.first.quantity, 'quantity', 2)
              .having((s) => s.items.first.stockQuantity, 'stockQuantity', 2),
        ],
      );

      blocTest<CartBloc, CartState>(
        'adds a brand-new product normally when there is plenty of stock '
        '(unaffected by the 0-stock clamp)',
        build: () => CartBloc(),
        act: (bloc) => bloc.add(
          CartItemAdded(product: _makeProduct(quantity: 10)),
        ),
        expect: () => [
          isA<CartState>()
              .having((s) => s.items.length, 'items.length', 1)
              .having((s) => s.items.first.quantity, 'quantity', 1)
              .having((s) => s.items.first.stockQuantity, 'stockQuantity', 10),
        ],
      );
    });

    group('CartItemRemoved', () {
      blocTest<CartBloc, CartState>(
        'removes the line item matching productId',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(productId: 'p1', productName: 'Apple', unitPrice: 10, quantity: 1),
            CartItem(productId: 'p2', productName: 'Banana', unitPrice: 3, quantity: 2),
          ],
        ),
        act: (bloc) => bloc.add(const CartItemRemoved('p1')),
        expect: () => [
          isA<CartState>()
              .having((s) => s.items.length, 'items.length', 1)
              .having((s) => s.items.first.productId, 'productId', 'p2'),
        ],
      );

      blocTest<CartBloc, CartState>(
        'does not emit a new state when the productId is not in the cart '
        '(resulting state is equal to current state)',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(productId: 'p1', productName: 'Apple', unitPrice: 10, quantity: 1),
          ],
        ),
        act: (bloc) => bloc.add(const CartItemRemoved('does-not-exist')),
        expect: () => [],
      );
    });

    group('CartItemQuantityChanged', () {
      blocTest<CartBloc, CartState>(
        'updates the quantity of an existing item',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(productId: 'p1', productName: 'Apple', unitPrice: 10, quantity: 1),
          ],
        ),
        act: (bloc) => bloc.add(
          const CartItemQuantityChanged(productId: 'p1', quantity: 5),
        ),
        expect: () => [
          isA<CartState>().having((s) => s.items.first.quantity, 'quantity', 5),
        ],
      );

      blocTest<CartBloc, CartState>(
        'removes the item when quantity is changed to zero',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(productId: 'p1', productName: 'Apple', unitPrice: 10, quantity: 1),
          ],
        ),
        act: (bloc) => bloc.add(
          const CartItemQuantityChanged(productId: 'p1', quantity: 0),
        ),
        expect: () => [
          isA<CartState>().having((s) => s.items, 'items', isEmpty),
        ],
      );

      blocTest<CartBloc, CartState>(
        'removes the item when quantity is changed to a negative number',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(productId: 'p1', productName: 'Apple', unitPrice: 10, quantity: 1),
          ],
        ),
        act: (bloc) => bloc.add(
          const CartItemQuantityChanged(productId: 'p1', quantity: -3),
        ),
        expect: () => [
          isA<CartState>().having((s) => s.items, 'items', isEmpty),
        ],
      );

      blocTest<CartBloc, CartState>(
        'does not emit when the productId does not exist in the cart',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(productId: 'p1', productName: 'Apple', unitPrice: 10, quantity: 1),
          ],
        ),
        act: (bloc) => bloc.add(
          const CartItemQuantityChanged(productId: 'ghost', quantity: 9),
        ),
        expect: () => [],
      );

      // SPEC.md #6 — the actual fix. The clamp lives here in CartBloc
      // (rather than in a page-local map like PosCheckoutPage's old,
      // bypassable `_stockOnHand`), so it applies no matter how the item
      // reached the cart: POS quick-add, product-detail "Продать", or a
      // restored persisted cart all populate stockQuantity via
      // _onItemAdded / a restored CartState, and this handler is the one
      // and only place a quantity increase is applied.
      blocTest<CartBloc, CartState>(
        'clamps the requested quantity to stockQuantity instead of applying '
        'it verbatim when the request exceeds stock on hand',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(
              productId: 'p1',
              productName: 'Apple',
              unitPrice: 10,
              quantity: 3,
              stockQuantity: 3,
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const CartItemQuantityChanged(productId: 'p1', quantity: 4),
        ),
        expect: () => [
          isA<CartState>().having((s) => s.items.first.quantity, 'quantity', 3),
        ],
      );

      blocTest<CartBloc, CartState>(
        'does not clamp when the requested quantity is within stock on hand',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(
              productId: 'p1',
              productName: 'Apple',
              unitPrice: 10,
              quantity: 2,
              stockQuantity: 5,
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const CartItemQuantityChanged(productId: 'p1', quantity: 3),
        ),
        expect: () => [
          isA<CartState>().having((s) => s.items.first.quantity, 'quantity', 3),
        ],
      );

      blocTest<CartBloc, CartState>(
        'does not clamp when stockQuantity is unknown (null) — e.g. a '
        'hand-built CartItem that never went through _onItemAdded',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(productId: 'p1', productName: 'Apple', unitPrice: 10, quantity: 1),
          ],
        ),
        act: (bloc) => bloc.add(
          const CartItemQuantityChanged(productId: 'p1', quantity: 50),
        ),
        expect: () => [
          isA<CartState>().having((s) => s.items.first.quantity, 'quantity', 50),
        ],
      );

      blocTest<CartBloc, CartState>(
        'closes the product-detail "Продать" bypass: an item added via a '
        'bare CartItemAdded (no PosCheckoutPage involved) still gets its '
        'quantity clamped to stock on hand',
        build: () => CartBloc(),
        act: (bloc) {
          // Mirrors product_detail_page.dart's "Продать" button, which
          // dispatches CartItemAdded straight to the app-scoped CartBloc,
          // bypassing PosCheckoutPage entirely.
          bloc.add(CartItemAdded(product: _makeProduct(quantity: 2)));
          bloc.add(const CartItemQuantityChanged(productId: 'p1', quantity: 10));
        },
        expect: () => [
          isA<CartState>().having((s) => s.items.first.quantity, 'quantity', 1),
          isA<CartState>().having((s) => s.items.first.quantity, 'quantity', 2),
        ],
      );

      blocTest<CartBloc, CartState>(
        'closes the cart-restore bypass: a CartRestored item still gets '
        'its quantity clamped to the stockQuantity carried in the '
        'restored state',
        build: () => CartBloc(),
        act: (bloc) {
          // Mirrors cart_restore_prompt.dart, which dispatches
          // CartRestored(saved.state) straight into CartBloc.
          bloc.add(const CartRestored(CartState(items: [
            CartItem(
              productId: 'p1',
              productName: 'Apple',
              unitPrice: 10,
              quantity: 1,
              stockQuantity: 4,
            ),
          ])));
          bloc.add(const CartItemQuantityChanged(productId: 'p1', quantity: 99));
        },
        expect: () => [
          isA<CartState>().having((s) => s.items.first.quantity, 'quantity', 1),
          isA<CartState>().having((s) => s.items.first.quantity, 'quantity', 4),
        ],
      );
    });

    group('CartDiscountApplied', () {
      blocTest<CartBloc, CartState>(
        'FIXED discount reduces total by a flat amount',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(productId: 'p1', productName: 'Apple', unitPrice: 10, quantity: 2),
          ],
        ),
        act: (bloc) => bloc.add(
          const CartDiscountApplied(discount: 5, type: 'FIXED'),
        ),
        expect: () => [
          isA<CartState>()
              .having((s) => s.subtotal, 'subtotal', 20)
              .having((s) => s.discountAmount, 'discountAmount', 5)
              .having((s) => s.total, 'total', 15),
        ],
      );

      blocTest<CartBloc, CartState>(
        'PERCENTAGE discount reduces total by subtotal * pct / 100',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(productId: 'p1', productName: 'Apple', unitPrice: 100, quantity: 2),
          ],
        ),
        act: (bloc) => bloc.add(
          const CartDiscountApplied(discount: 10, type: 'PERCENTAGE'),
        ),
        expect: () => [
          isA<CartState>()
              .having((s) => s.discountAmount, 'discountAmount', 20)
              .having((s) => s.total, 'total', 180),
        ],
      );

      // BUG (revenue-critical, see report): unlike CheckoutBloc's own
      // discount handler (which clamps total to 0 when discount > subtotal),
      // CartState.total performs no clamping at all. A FIXED discount larger
      // than the subtotal produces a *negative* total here, and this value
      // flows straight through PosCheckoutPage._initCheckoutAndProceed into
      // CheckoutInitiated(total: cart.total) — which CheckoutBloc also
      // accepts unclamped — so a negative total/paidAmount could reach the
      // sale payload sent to the API.
      blocTest<CartBloc, CartState>(
        'FIXED discount larger than subtotal produces a negative total '
        '(documents unclamped cart math — see BUG note above)',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(productId: 'p1', productName: 'Apple', unitPrice: 10, quantity: 2),
          ],
        ),
        act: (bloc) => bloc.add(
          const CartDiscountApplied(discount: 100, type: 'FIXED'),
        ),
        expect: () => [
          isA<CartState>().having((s) => s.total, 'total', -80),
        ],
      );
    });

    group('CartCleared', () {
      blocTest<CartBloc, CartState>(
        'resets to a brand-new empty cart from a populated state',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(productId: 'p1', productName: 'Apple', unitPrice: 10, quantity: 2),
          ],
          discount: 5,
          customerId: 'c1',
          customerName: 'Ali',
          redemptionPoints: 10,
        ),
        act: (bloc) => bloc.add(CartCleared()),
        expect: () => [const CartState()],
      );
    });

    group('CartCustomerSelected (no loyaltyRepository injected)', () {
      blocTest<CartBloc, CartState>(
        'sets customerId/customerName without attempting to load a loyalty '
        'balance when no LoyaltyRepository is configured',
        build: () => CartBloc(),
        act: (bloc) => bloc.add(
          const CartCustomerSelected(customerId: 'c1', customerName: 'Ali', storeId: 's1'),
        ),
        expect: () => [
          isA<CartState>()
              .having((s) => s.customerId, 'customerId', 'c1')
              .having((s) => s.customerName, 'customerName', 'Ali')
              .having((s) => s.customerLoyaltyPoints, 'loyaltyPoints stays 0', 0),
        ],
      );

      blocTest<CartBloc, CartState>(
        'clears customer + loyalty fields but keeps items/discount when '
        'deselecting the customer (customerId: null)',
        build: () => CartBloc(),
        seed: () => const CartState(
          items: [
            CartItem(productId: 'p1', productName: 'Apple', unitPrice: 10, quantity: 1),
          ],
          discount: 5,
          discountType: 'PERCENTAGE',
          customerId: 'c1',
          customerName: 'Ali',
          customerLoyaltyPoints: 200,
          loyaltyPointValue: 0.01,
          redemptionPoints: 20,
        ),
        act: (bloc) => bloc.add(const CartCustomerSelected(customerId: null)),
        expect: () => [
          isA<CartState>()
              .having((s) => s.customerId, 'customerId', isNull)
              .having((s) => s.customerName, 'customerName', isNull)
              .having((s) => s.customerLoyaltyPoints, 'loyaltyPoints', 0)
              .having((s) => s.redemptionPoints, 'redemptionPoints', 0)
              .having((s) => s.items.length, 'items kept', 1)
              .having((s) => s.discount, 'discount kept', 5)
              .having((s) => s.discountType, 'discountType kept', 'PERCENTAGE'),
        ],
      );
    });

    group('CartRestored', () {
      blocTest<CartBloc, CartState>(
        'replaces the current state with the restored one verbatim',
        build: () => CartBloc(),
        seed: () => const CartState(),
        act: (bloc) => bloc.add(
          const CartRestored(
            CartState(
              items: [
                CartItem(productId: 'p9', productName: 'Restored', unitPrice: 1, quantity: 1),
              ],
              discount: 2,
            ),
          ),
        ),
        expect: () => [
          isA<CartState>()
              .having((s) => s.items.first.productId, 'productId', 'p9')
              .having((s) => s.discount, 'discount', 2),
        ],
      );
    });

    group('CartState computed properties', () {
      test('subtotal sums (unitPrice * quantity - discount) across items', () {
        const state = CartState(items: [
          CartItem(productId: 'p1', productName: 'A', unitPrice: 10, quantity: 2), // 20
          CartItem(productId: 'p2', productName: 'B', unitPrice: 5, quantity: 3, discount: 3), // 12
        ]);
        expect(state.subtotal, 32);
      });

      test('itemCount sums quantities, not distinct line-item count', () {
        const state = CartState(items: [
          CartItem(productId: 'p1', productName: 'A', unitPrice: 10, quantity: 2),
          CartItem(productId: 'p2', productName: 'B', unitPrice: 5, quantity: 3),
        ]);
        expect(state.itemCount, 5);
      });

      test('isEmpty is true only when there are no items', () {
        expect(const CartState().isEmpty, isTrue);
        expect(
          const CartState(items: [
            CartItem(productId: 'p1', productName: 'A', unitPrice: 10, quantity: 1),
          ]).isEmpty,
          isFalse,
        );
      });

      test('loyaltyRedemptionValue is redemptionPoints * loyaltyPointValue and '
          'reduces total', () {
        const state = CartState(
          items: [
            CartItem(productId: 'p1', productName: 'A', unitPrice: 100, quantity: 1),
          ],
          loyaltyPointValue: 0.01,
          redemptionPoints: 50,
        );
        expect(state.loyaltyRedemptionValue, 0.5);
        expect(state.total, closeTo(99.5, 1e-9));
      });

      test('CartItem.total is unitPrice * quantity minus its own discount', () {
        const item = CartItem(
          productId: 'p1',
          productName: 'A',
          unitPrice: 10,
          quantity: 3,
          discount: 4,
        );
        expect(item.total, 26);
      });

      test('CartItem.copyWith only overrides quantity/discount, keeping '
          'identity fields intact', () {
        const item = CartItem(
          productId: 'p1',
          productName: 'A',
          unitPrice: 10,
          quantity: 1,
          unit: 'KG',
        );
        final updated = item.copyWith(quantity: 5);
        expect(updated.quantity, 5);
        expect(updated.productId, 'p1');
        expect(updated.unit, 'KG');
        expect(updated.unitPrice, 10);
      });

      test('CartItem.stockQuantity defaults to null and copyWith preserves '
          'it when not explicitly overridden', () {
        const item = CartItem(
          productId: 'p1',
          productName: 'A',
          unitPrice: 10,
          quantity: 1,
          stockQuantity: 6,
        );
        expect(const CartItem(
          productId: 'p1',
          productName: 'A',
          unitPrice: 10,
          quantity: 1,
        ).stockQuantity, isNull);
        final updated = item.copyWith(quantity: 2);
        expect(updated.stockQuantity, 6);
        final restocked = item.copyWith(stockQuantity: 10);
        expect(restocked.stockQuantity, 10);
        expect(restocked.quantity, 1);
      });
    });
  });
}
