import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/presentation/widgets/product/product_card.dart';
import 'package:dukonpro/domain/entities/product.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('ProductCard goldens', () {
    Widget sample() => SizedBox(
          width: 180,
          height: 220,
          child: ProductCard(
            product: Product(
              id: 'p-1',
              storeId: 'store-1',
              name: 'Молоко 1л',
              sku: 'MLK-001',
              sellPrice: 8500,
              quantity: 24,
              minQuantity: 5,
              createdAt: DateTime(2024, 1, 1),
            ),
            onTap: () {},
          ),
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'product_card_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'product_card_dark');
    });
  });
}
