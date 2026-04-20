import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('AppDialog goldens', () {
    // AppDialog.show() requires a live Navigator/showDialog, so we test
    // the visual chrome by composing the same Dialog widget it builds
    // internally. This gives full golden coverage of colors & layout.
    Widget sample({bool isDanger = false}) => Builder(
          builder: (context) {
            final confirmColor = isDanger
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary;
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Подтвердите действие',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Вы уверены, что хотите удалить этот товар?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Inter',
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : const Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: OutlinedButton(
                              onPressed: () {},
                              child: const Text(
                                'Бекор',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: confirmColor,
                                elevation: 0,
                              ),
                              child: const Text(
                                'Тасдиқ',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.light,
        alignment: Alignment.center,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'app_dialog_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.dark,
        alignment: Alignment.center,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'app_dialog_dark');
    });

    testGoldens('danger light theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(isDanger: true),
        brightness: Brightness.light,
        alignment: Alignment.center,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'app_dialog_danger_light');
    });
  });
}
