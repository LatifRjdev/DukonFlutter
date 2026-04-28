import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/presentation/widgets/pos/quick_product_chip.dart';
import 'package:dukonpro/domain/entities/product.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('QuickProductChip goldens', () {
    Widget sample() => QuickProductChip(
          product: Product(
            id: 'p-1',
            storeId: 'store-1',
            name: 'Хлеб',
            sellPrice: 4200,
            quantity: 10,
            createdAt: DateTime(2024, 1, 1),
          ),
          onTap: () {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'quick_product_chip_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'quick_product_chip_dark');
    });
  });
}
