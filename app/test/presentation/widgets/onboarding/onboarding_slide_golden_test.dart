import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/presentation/widgets/onboarding/onboarding_slide.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('OnboardingSlide goldens', () {
    Widget sample() => const OnboardingSlide(
          title: 'Управляйте магазином',
          description: 'Всё необходимое для эффективного управления вашим бизнесом в одном месте.',
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'onboarding_slide_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'onboarding_slide_dark');
    });
  });
}
