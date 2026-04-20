import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/common/step_indicator.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('StepIndicator goldens', () {
    Widget sample() => StepIndicator(
          currentStep: 1,
          totalSteps: 3,
          labels: const ['Step 1', 'Step 2', 'Step 3'],
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'step_indicator_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'step_indicator_dark');
    });
  });
}
