import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/presentation/widgets/pos/cart_item_widget.dart';
import 'package:dokonpro/presentation/blocs/pos/cart_state.dart';

void main() {
  const item = CartItem(
    productId: 'p1',
    productName: 'Чой (чай)',
    unitPrice: 15.50,
    quantity: 3,
    discount: 0,
    unit: 'PCS',
  );

  Widget buildWidget({
    CartItem cartItem = item,
    ValueChanged<int>? onQuantityChanged,
    VoidCallback? onDelete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CartItemWidget(
          item: cartItem,
          onQuantityChanged: onQuantityChanged ?? (_) {},
          onDelete: onDelete ?? () {},
        ),
      ),
    );
  }

  group('CartItemWidget', () {
    testWidgets('should display product name', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Чой (чай)'), findsOneWidget);
    });

    testWidgets('should display quantity', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('should display line total with formatting', (tester) async {
      // 15.50 * 3 - 0 = 46.50 → "46,50 сом."
      await tester.pumpWidget(buildWidget());
      expect(find.textContaining('46,50'), findsOneWidget);
    });

    testWidgets('should display discounted total when discount > 0',
        (tester) async {
      const discounted = CartItem(
        productId: 'p2',
        productName: 'Нон',
        unitPrice: 5.0,
        quantity: 4,
        discount: 3.0,
        unit: 'PCS',
      );
      // 5*4 - 3 = 17.00
      await tester.pumpWidget(buildWidget(cartItem: discounted));
      expect(find.textContaining('17,00'), findsOneWidget);
    });

    testWidgets('should call onQuantityChanged with incremented value on + tap',
        (tester) async {
      int? received;
      await tester.pumpWidget(buildWidget(
        onQuantityChanged: (v) => received = v,
      ));

      // Find the "+" icon button
      final addButton = find.byIcon(Icons.add);
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pump();

      expect(received, equals(4)); // 3 + 1
    });

    testWidgets('should call onQuantityChanged with decremented value on - tap',
        (tester) async {
      int? received;
      await tester.pumpWidget(buildWidget(
        onQuantityChanged: (v) => received = v,
      ));

      final removeButton = find.byIcon(Icons.remove);
      expect(removeButton, findsOneWidget);
      await tester.tap(removeButton);
      await tester.pump();

      expect(received, equals(2)); // 3 - 1
    });

    testWidgets('should not decrement when quantity is 1 and - tapped',
        (tester) async {
      int? received;
      const singleItem = CartItem(
        productId: 'p3',
        productName: 'Ширини',
        unitPrice: 10.0,
        quantity: 1,
      );
      await tester.pumpWidget(buildWidget(
        cartItem: singleItem,
        onQuantityChanged: (v) => received = v,
      ));

      final removeButton = find.byIcon(Icons.remove);
      await tester.tap(removeButton);
      await tester.pump();

      expect(received, isNull);
    });

    testWidgets('should call onDelete when close icon is tapped',
        (tester) async {
      bool deleted = false;
      await tester.pumpWidget(buildWidget(
        onDelete: () => deleted = true,
      ));

      final deleteButton = find.byIcon(Icons.close_rounded);
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pump();

      expect(deleted, isTrue);
    });
  });
}
