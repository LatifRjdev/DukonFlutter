import 'package:dokonpro/presentation/pages/product/empty_products_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  Widget page() => const EmptyProductsPage();

  group('EmptyProductsPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
      );
      await screenMatchesGolden(tester, 'empty_products_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
      );
      await screenMatchesGolden(tester, 'empty_products_dark');
    });
  });
}
