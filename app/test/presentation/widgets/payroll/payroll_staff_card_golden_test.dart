import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/domain/entities/payroll_entry.dart';
import 'package:dokonpro/domain/entities/payroll_adjustment.dart';
import 'package:dokonpro/presentation/widgets/payroll/payroll_staff_card.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('PayrollStaffCard goldens', () {
    Widget sample() => PayrollStaffCard(
          entry: const PayrollEntry(
            id: 'pe1',
            staffId: 'st1',
            staffName: 'Алишер Каримов',
            staffRole: 'CASHIER',
            baseSalary: 2500.00,
            commission: 375.00,
            salesTotal: 125000.00,
            shiftsWorked: 22,
            shiftsExpected: 22,
            totalAmount: 2875.00,
            isPaid: false,
            adjustments: [
              PayrollAdjustment(
                id: 'adj1',
                type: 'BONUS',
                amount: 200.00,
                description: 'Премия за план',
              ),
            ],
          ),
          onTap: () {},
          onPay: () {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'payroll_staff_card_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'payroll_staff_card_dark');
    });
  });
}
