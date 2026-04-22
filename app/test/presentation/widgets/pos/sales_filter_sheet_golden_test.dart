import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/pos/sales_filter_sheet.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('SalesFilterSheet goldens', () {
    Widget sample() => SalesFilterSheet(
          onApply: (_) {},
          initial: const SalesFilter(),
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.light,
        alignment: Alignment.bottomCenter,
        padding: EdgeInsets.zero,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'sales_filter_sheet_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.dark,
        alignment: Alignment.bottomCenter,
        padding: EdgeInsets.zero,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'sales_filter_sheet_dark');
    });
  });
}
