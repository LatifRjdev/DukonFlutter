import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/domain/entities/zakat_calculation.dart';
import 'package:dukonpro/presentation/widgets/zakat/zakat_breakdown_card.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('ZakatBreakdownCard goldens', () {
    Widget sample() => ZakatBreakdownCard(
          calculation: const ZakatCalculation(
            stockValue: 500000.00,
            receivables: 80000.00,
            payables: 120000.00,
            netAssets: 460000.00,
            nisabAmount: 350000.00,
            zakatDue: 11500.00,
            isAboveNisab: true,
          ),
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'zakat_breakdown_card_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'zakat_breakdown_card_dark');
    });
  });
}
