import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/pos/cart_item_widget.dart';
import 'package:dokonpro/presentation/blocs/pos/cart_state.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('CartItemWidget goldens', () {
    Widget sample() => CartItemWidget(
          item: const CartItem(
            productId: 'p-1',
            productName: 'Молоко 1л',
            unitPrice: 8500,
            quantity: 3,
          ),
          onQuantityChanged: (_) {},
          onDelete: () {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'cart_item_widget_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'cart_item_widget_dark');
    });
  });
}
