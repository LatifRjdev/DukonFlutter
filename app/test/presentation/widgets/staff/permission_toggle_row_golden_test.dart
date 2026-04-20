import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/staff/permission_toggle_row.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('PermissionToggleRow goldens', () {
    Widget enabledSample() => PermissionToggleRow(
          permissionKey: 'manage_products',
          label: 'Управление товарами',
          description: 'Добавление, редактирование товаров',
          value: true,
          enabled: true,
          onChanged: (_) {},
        );

    Widget disabledSample() => PermissionToggleRow(
          permissionKey: 'manage_staff',
          label: 'Управление персоналом',
          value: false,
          enabled: false,
        );

    testGoldens('light theme enabled', (tester) async {
      await pumpWidgetWithTheme(tester, enabledSample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'permission_toggle_row_enabled_light');
    });

    testGoldens('dark theme enabled', (tester) async {
      await pumpWidgetWithTheme(tester, enabledSample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'permission_toggle_row_enabled_dark');
    });

    testGoldens('light theme disabled', (tester) async {
      await pumpWidgetWithTheme(tester, disabledSample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'permission_toggle_row_disabled_light');
    });

    testGoldens('dark theme disabled', (tester) async {
      await pumpWidgetWithTheme(tester, disabledSample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'permission_toggle_row_disabled_dark');
    });
  });
}
