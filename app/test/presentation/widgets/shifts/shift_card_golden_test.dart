import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/domain/entities/shift.dart';
import 'package:dukonpro/presentation/widgets/shifts/shift_card.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('ShiftCard goldens', () {
    final openedAt = DateTime(2024, 3, 15, 9, 0);

    Widget openSample() => ShiftCard(
          shift: ShiftModel(
            id: 'shift-1',
            storeId: 'store-1',
            staffId: 'staff-1',
            staffName: 'Алишер Каримов',
            openedAt: openedAt,
            openingCash: 500.0,
            salesTotal: 12450.0,
            salesCount: 34,
            cashSales: 8000.0,
            cardSales: 4450.0,
            status: 'OPEN',
          ),
          onTap: () {},
        );

    Widget closedSample() => ShiftCard(
          shift: ShiftModel(
            id: 'shift-2',
            storeId: 'store-1',
            staffId: 'staff-2',
            staffName: 'Зарина Юсупова',
            openedAt: openedAt,
            closedAt: openedAt.add(const Duration(hours: 8)),
            openingCash: 300.0,
            salesTotal: 9800.0,
            salesCount: 22,
            cashSales: 5000.0,
            cardSales: 4800.0,
            status: 'CLOSED',
          ),
        );

    testGoldens('light theme open', (tester) async {
      await pumpWidgetWithTheme(tester, openSample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'shift_card_open_light');
    });

    testGoldens('dark theme open', (tester) async {
      await pumpWidgetWithTheme(tester, openSample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'shift_card_open_dark');
    });

    testGoldens('light theme closed', (tester) async {
      await pumpWidgetWithTheme(tester, closedSample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'shift_card_closed_light');
    });

    testGoldens('dark theme closed', (tester) async {
      await pumpWidgetWithTheme(tester, closedSample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'shift_card_closed_dark');
    });
  });
}
