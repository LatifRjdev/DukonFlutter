import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/domain/entities/product.dart';
import 'package:dukonpro/presentation/widgets/product/product_card.dart';

Product _product({double? paybackPercent, int quantity = 10}) {
  return Product(
    id: 'p1',
    storeId: 'store-1',
    name: 'Test Product',
    sellPrice: 30,
    quantity: quantity,
    createdAt: DateTime(2026, 1, 1),
    paybackPercent: paybackPercent,
  );
}

void main() {
  group('ProductCard — payback badge', () {
    testWidgets('does not show a payback badge when paybackPercent is null', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProductCard(product: _product(paybackPercent: null))),
      ));

      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('shows the rounded payback percentage when present', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProductCard(product: _product(paybackPercent: 99.4))),
      ));

      expect(find.text('99%'), findsOneWidget);
    });

    testWidgets('rounds up correctly at the boundary', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProductCard(product: _product(paybackPercent: 100.0))),
      ));

      expect(find.text('100%'), findsOneWidget);
    });
  });
}
