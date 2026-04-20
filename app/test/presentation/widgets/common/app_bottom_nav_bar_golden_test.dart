import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/common/app_bottom_nav_bar.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('AppBottomNavBar goldens', () {
    Widget sample() => AppBottomNavBar(
          currentIndex: 0,
          onTap: (_) {},
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
      await screenMatchesGolden(tester, 'app_bottom_nav_bar_light');
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
      await screenMatchesGolden(tester, 'app_bottom_nav_bar_dark');
    });
  });
}
