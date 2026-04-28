import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/presentation/widgets/finance/period_selector.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('PeriodSelector goldens', () {
    Widget sample() => PeriodSelector(
          selected: 'month',
          onChanged: (_) {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'period_selector_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'period_selector_dark');
    });
  });
}
