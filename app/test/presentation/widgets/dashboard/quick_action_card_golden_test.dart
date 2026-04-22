import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dokonpro/presentation/widgets/dashboard/quick_action_card.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('QuickActionCard goldens', () {
    Widget sample() => SizedBox(
          width: 160,
          height: 120,
          child: QuickActionCard(
            icon: Icons.add_shopping_cart_rounded,
            label: 'Новая продажа',
            onTap: () {},
          ),
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'quick_action_card_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'quick_action_card_dark');
    });
  });
}
