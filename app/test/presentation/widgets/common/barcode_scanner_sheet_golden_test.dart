import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/presentation/widgets/common/barcode_scanner_sheet.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('BarcodeScannerSheet goldens', () {
    Widget sample() => BarcodeScannerSheet(onScanned: (_) {});

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.light,
        alignment: Alignment.bottomCenter,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'barcode_scanner_sheet_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.dark,
        alignment: Alignment.bottomCenter,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'barcode_scanner_sheet_dark');
    });
  });
}
