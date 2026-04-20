import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/settings/settings_tile.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('SettingsTile goldens', () {
    Widget sample() => SettingsTile(
          icon: Icons.store_outlined,
          title: 'Магазин',
          subtitle: 'Настройки магазина',
          onTap: () {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'settings_tile_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'settings_tile_dark');
    });
  });
}
