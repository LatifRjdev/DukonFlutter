import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/domain/entities/staff_member.dart';
import 'package:dokonpro/presentation/widgets/staff/staff_card.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('StaffCard goldens', () {
    final createdAt = DateTime(2024, 1, 10);

    Widget cashierOnShift() => StaffCard(
          staff: StaffMember(
            id: 'staff-1',
            storeId: 'store-1',
            name: 'Алишер Каримов',
            phone: '+992 900 123 456',
            role: 'CASHIER',
            isActive: true,
            isOnShift: true,
            todaySales: 8450.0,
            createdAt: createdAt,
          ),
          onTap: () {},
        );

    Widget ownerOffShift() => StaffCard(
          staff: StaffMember(
            id: 'staff-2',
            storeId: 'store-1',
            name: 'Зарина Юсупова',
            role: 'OWNER',
            isActive: true,
            isOnShift: false,
            createdAt: createdAt,
          ),
        );

    testGoldens('light theme cashier on shift', (tester) async {
      await pumpWidgetWithTheme(tester, cashierOnShift(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'staff_card_cashier_light');
    });

    testGoldens('dark theme cashier on shift', (tester) async {
      await pumpWidgetWithTheme(tester, cashierOnShift(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'staff_card_cashier_dark');
    });

    testGoldens('light theme owner', (tester) async {
      await pumpWidgetWithTheme(tester, ownerOffShift(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'staff_card_owner_light');
    });

    testGoldens('dark theme owner', (tester) async {
      await pumpWidgetWithTheme(tester, ownerOffShift(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'staff_card_owner_dark');
    });
  });
}
