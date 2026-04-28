import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/presentation/widgets/debt/debt_card.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('DebtCard goldens', () {
    Widget sample() => DebtCard(
          name: 'Иван Петров',
          debt: 45000.00,
          phone: '+992 900 123456',
          onTap: () {},
          isSupplier: false,
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'debt_card_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'debt_card_dark');
    });
  });
}
