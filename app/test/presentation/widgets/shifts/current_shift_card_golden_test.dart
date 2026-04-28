import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/domain/entities/shift.dart';
import 'package:dukonpro/presentation/widgets/shifts/current_shift_card.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('CurrentShiftCard goldens', () {
    final openedAt = DateTime(2024, 3, 15, 9, 0);

    Widget sample() => CurrentShiftCard(
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
          onClose: () {},
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'current_shift_card_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'current_shift_card_dark');
    });
  });
}
