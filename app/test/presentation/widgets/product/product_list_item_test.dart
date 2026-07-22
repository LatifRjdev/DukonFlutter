import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/domain/entities/product.dart';
import 'package:dukonpro/presentation/widgets/product/product_list_item.dart';

Product _product({double? paybackPercent}) {
  return Product(
    id: 'p1',
    storeId: 'store-1',
    name: 'Test Product',
    sellPrice: 30,
    quantity: 10,
    createdAt: DateTime(2026, 1, 1),
    paybackPercent: paybackPercent,
  );
}

void main() {
  group('ProductListItem — payback badge', () {
    testWidgets('does not show a payback badge when paybackPercent is null', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProductListItem(product: _product(paybackPercent: null))),
      ));

      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('shows the rounded payback percentage when present', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProductListItem(product: _product(paybackPercent: 42.9))),
      ));

      expect(find.text('43%'), findsOneWidget);
    });
  });
}
