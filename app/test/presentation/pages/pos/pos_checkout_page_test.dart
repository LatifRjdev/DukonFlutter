// app/test/presentation/pages/pos/pos_checkout_page_test.dart
//
// Covers SPEC.md #6: the cart quantity stepper's "+" button must not push
// an item's quantity past the product's stock on hand, and must surface a
// snackbar when the clamp is hit instead of silently doing nothing.
//
// The actual clamp is enforced in CartBloc (see cart_bloc_test.dart) —
// CartItem.stockQuantity is captured on every CartItemAdded regardless of
// which screen dispatched it, so it can't be bypassed the way the old
// page-local `_stockOnHand` map could (product-detail "Продать" and cart
// restore both dispatch straight into CartBloc, skipping this page).
// This test only covers the page's snackbar-vs-dispatch decision, reading
// item.stockQuantity from the (mocked) CartBloc state.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/product.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_event.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_state.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_bloc.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_event.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_state.dart';
import 'package:dukonpro/presentation/blocs/pos/checkout_bloc.dart';
import 'package:dukonpro/presentation/blocs/pos/checkout_event.dart';
import 'package:dukonpro/presentation/blocs/pos/checkout_state.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_event.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/pos/pos_checkout_page.dart';
import 'package:dukonpro/presentation/widgets/common/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockCartBloc extends MockBloc<CartEvent, CartState> implements CartBloc {}

class MockCheckoutBloc extends MockBloc<CheckoutEvent, CheckoutState>
    implements CheckoutBloc {}

class MockProductListBloc extends MockBloc<ProductListEvent, ProductListState>
    implements ProductListBloc {}

class MockCustomerListBloc
    extends MockBloc<CustomerListEvent, CustomerListState>
    implements CustomerListBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockCartBloc cartBloc;
  late MockCheckoutBloc checkoutBloc;
  late MockProductListBloc productListBloc;
  late MockCustomerListBloc customerListBloc;

  final product = Product(
    id: 'p1',
    storeId: 'test-store-id',
    name: 'Test Product',
    sellPrice: 100,
    quantity: 3,
    createdAt: DateTime(2024, 1, 1),
  );

  CartState cartStateWithQuantity(int quantity) => CartState(
        items: [
          CartItem(
            productId: product.id,
            productName: product.name,
            unitPrice: product.sellPrice,
            quantity: quantity,
            // As CartBloc._onItemAdded would have captured it from
            // `product.quantity` on the CartItemAdded that put this item
            // in the cart.
            stockQuantity: product.quantity,
          ),
        ],
      );

  setUpAll(() {
    registerFallbackValue(CartCleared());
    registerFallbackValue(const CheckoutPaymentMethodSelected('CASH'));
  });

  setUp(() {
    storeBloc = MockStoreBloc();
    cartBloc = MockCartBloc();
    checkoutBloc = MockCheckoutBloc();
    productListBloc = MockProductListBloc();
    customerListBloc = MockCustomerListBloc();

    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => checkoutBloc.state).thenReturn(const CheckoutState());
    when(() => productListBloc.state).thenReturn(
      ProductListLoaded(products: [product], total: 1, totalPages: 1),
    );
    when(() => customerListBloc.state).thenReturn(CustomerListInitial());
  });

  Widget page() => const PosCheckoutPage();

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<CartBloc>.value(value: cartBloc),
          BlocProvider<CheckoutBloc>.value(value: checkoutBloc),
          BlocProvider<ProductListBloc>.value(value: productListBloc),
          BlocProvider<CustomerListBloc>.value(value: customerListBloc),
        ],
        child: child,
      );

  // Taps the quick-add tile for [product], exactly as a cashier adding it
  // to the cart would. Since CartBloc is mocked here, this only dispatches
  // CartItemAdded — the resulting cart state (with stockQuantity already
  // set) comes from `cartStateWithQuantity` via `when(() => cartBloc.state)`.
  Future<void> addProductToCart(WidgetTester tester) async {
    await tester.tap(find.text(product.name).first);
    await tester.pump();
  }

  group('PosCheckoutPage cart quantity stepper (SPEC.md #6)', () {
    testWidgets(
        'should stop incrementing and show a snackbar when quantity is already at stock on hand',
        (tester) async {
      when(() => cartBloc.state).thenReturn(cartStateWithQuantity(3));

      await pumpPageWithTheme(tester, page(),
          brightness: Brightness.light, wrap: wrapWithBlocs);
      await addProductToCart(tester);

      await tester.tap(find.byTooltip('Увеличить количество'));
      await tester.pump();

      expect(find.text('Больше нет в наличии'), findsOneWidget);
      verifyNever(() => cartBloc.add(any(that: isA<CartItemQuantityChanged>())));
    });

    testWidgets('should increment normally when quantity is below stock on hand',
        (tester) async {
      when(() => cartBloc.state).thenReturn(cartStateWithQuantity(2));

      await pumpPageWithTheme(tester, page(),
          brightness: Brightness.light, wrap: wrapWithBlocs);
      await addProductToCart(tester);

      await tester.tap(find.byTooltip('Увеличить количество'));
      await tester.pump();

      verify(() => cartBloc.add(
            const CartItemQuantityChanged(productId: 'p1', quantity: 3),
          )).called(1);
      expect(find.text('Больше нет в наличии'), findsNothing);
    });
  });

  group('PosCheckoutPage card payment confirmation (SPEC.md #8)', () {
    // Cash and debt payments both push a dedicated confirmation screen
    // before CheckoutBloc ever processes the sale. Card payment used to
    // dispatch CheckoutProcessPayment straight from the checkout CTA with
    // no review step — this group proves it now shows a confirmation
    // dialog first, and that cancelling it never reaches CheckoutBloc.
    setUp(() {
      when(() => cartBloc.state).thenReturn(
        CartState(
          items: [
            CartItem(
              productId: product.id,
              productName: product.name,
              unitPrice: product.sellPrice,
              quantity: 1,
              stockQuantity: product.quantity,
            ),
          ],
        ),
      );
    });

    Future<void> selectCardAndTapCheckout(WidgetTester tester) async {
      await tester.tap(find.text('Карта'));
      await tester.pump();
      await tester.tap(find.byType(AppButton));
      await tester.pump();
    }

    testWidgets(
        'tapping the checkout CTA with CARD selected shows a confirmation '
        'dialog instead of processing immediately', (tester) async {
      await pumpPageWithTheme(tester, page(),
          brightness: Brightness.light, wrap: wrapWithBlocs);

      await selectCardAndTapCheckout(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Оплата картой?'), findsOneWidget);
      verifyNever(() => checkoutBloc.add(any(that: isA<CheckoutProcessPayment>())));
    });

    testWidgets('cancelling the card-payment confirmation does not process the sale',
        (tester) async {
      await pumpPageWithTheme(tester, page(),
          brightness: Brightness.light, wrap: wrapWithBlocs);

      await selectCardAndTapCheckout(tester);
      await tester.tap(find.text('Отмена'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => checkoutBloc.add(any(that: isA<CheckoutProcessPayment>())));
    });

    testWidgets('confirming the card-payment dialog processes the sale',
        (tester) async {
      await pumpPageWithTheme(tester, page(),
          brightness: Brightness.light, wrap: wrapWithBlocs);

      await selectCardAndTapCheckout(tester);
      await tester.tap(find.text('Подтвердить'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      verify(() => checkoutBloc.add(any(that: isA<CheckoutPaidAmountChanged>())))
          .called(1);
      verify(() => checkoutBloc.add(any(that: isA<CheckoutProcessPayment>())))
          .called(1);
    });
  });
}
