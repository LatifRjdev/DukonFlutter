import 'package:dokonpro/presentation/pages/sales/empty_sales_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  Widget page() => const EmptySalesPage();

  group('EmptySalesPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'empty_sales_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'empty_sales_dark');
    });
  });
}
