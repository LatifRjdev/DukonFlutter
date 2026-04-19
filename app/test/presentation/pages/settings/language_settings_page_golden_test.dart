import 'package:dokonpro/presentation/pages/settings/language_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget page() => const LanguageSettingsPage();

  group('LanguageSettingsPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'language_settings_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(tester, page(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'language_settings_dark');
    });
  });
}
