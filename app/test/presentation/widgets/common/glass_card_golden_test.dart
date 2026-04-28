import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/presentation/widgets/common/glass_card.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('GlassCard goldens', () {
    Widget sample() => const SizedBox(
          width: 300,
          child: GlassCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sample content'),
            ),
          ),
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.light);
      tester.takeException();
      await screenMatchesGolden(tester, 'glass_card_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(tester, sample(), brightness: Brightness.dark);
      tester.takeException();
      await screenMatchesGolden(tester, 'glass_card_dark');
    });
  });
}
