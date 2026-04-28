import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/presentation/widgets/finance/stat_summary_row.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('StatSummaryRow goldens', () {
    Widget sample() => StatSummaryRow(
          salesCount: 42,
          avgCheck: 3750.50,
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'stat_summary_row_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'stat_summary_row_dark');
    });
  });
}
