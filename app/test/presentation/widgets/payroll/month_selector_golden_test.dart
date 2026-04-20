import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/payroll/month_selector.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('MonthSelector goldens', () {
    Widget sample() => MonthSelector(
          month: 4,
          year: 2026,
          onChanged: (_) {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'month_selector_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'month_selector_dark');
    });
  });
}
