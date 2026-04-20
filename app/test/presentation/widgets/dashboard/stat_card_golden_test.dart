import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/dashboard/stat_card.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('StatCard goldens', () {
    Widget sample() => SizedBox(
          width: 180,
          height: 130,
          child: StatCard(
            icon: Icons.shopping_bag_outlined,
            label: 'Продажи сегодня',
            value: '1 250 000 сом',
            trendPercentage: 12.5,
            trendUp: true,
          ),
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'stat_card_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'stat_card_dark');
    });
  });
}
