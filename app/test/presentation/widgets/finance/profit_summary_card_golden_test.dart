import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/finance/profit_summary_card.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('ProfitSummaryCard goldens', () {
    Widget sample() => ProfitSummaryCard(
          income: 500000.00,
          expenses: 200000.00,
          profit: 300000.00,
          currency: 'TJS',
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'profit_summary_card_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'profit_summary_card_dark');
    });
  });
}
