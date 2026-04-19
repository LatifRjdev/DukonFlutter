import 'package:dokonpro/presentation/pages/settings/kkm_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  Widget page() => const KkmSettingsPage();

  group('KkmSettingsPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'kkm_settings_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'kkm_settings_dark');
    });
  });
}
