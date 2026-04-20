import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/product/product_list_item.dart';
import 'package:dokonpro/domain/entities/product.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('ProductListItem goldens', () {
    Widget sample() => ProductListItem(
          product: Product(
            id: 'p-2',
            storeId: 'store-1',
            name: 'Хлеб пшеничный 500г',
            sku: 'BRD-002',
            sellPrice: 4200,
            quantity: 3,
            minQuantity: 5,
            createdAt: DateTime(2024, 1, 1),
          ),
          onTap: () {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'product_list_item_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'product_list_item_dark');
    });
  });
}
