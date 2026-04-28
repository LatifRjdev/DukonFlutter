import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/presentation/widgets/pos/payment_method_tile.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('PaymentMethodTile goldens', () {
    Widget sample() => PaymentMethodTile(
          label: 'Наличные',
          icon: Icons.payments_outlined,
          value: 'CASH',
          groupValue: 'CASH',
          onChanged: (_) {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'payment_method_tile_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'payment_method_tile_dark');
    });
  });
}
