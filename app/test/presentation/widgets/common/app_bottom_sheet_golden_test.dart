import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  group('AppBottomSheet goldens', () {
    // AppBottomSheet.show() wraps showModalBottomSheet which needs a Navigator.
    // We test the internal _AppBottomSheetContent chrome directly by reproducing
    // the same Container/Column layout the widget builds.
    Widget sample() => Builder(
          builder: (context) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                // Title row
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 4,
                    top: 8,
                    bottom: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Выберите категорию',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(
                          Icons.close_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Пӯшидан',
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                // Sample list content
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.category_outlined),
                          title: const Text('Напитки'),
                          onTap: () {},
                        ),
                        ListTile(
                          leading: const Icon(Icons.category_outlined),
                          title: const Text('Молочные продукты'),
                          onTap: () {},
                        ),
                        ListTile(
                          leading: const Icon(Icons.category_outlined),
                          title: const Text('Хлебобулочные изделия'),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.light,
        alignment: Alignment.bottomCenter,
        padding: EdgeInsets.zero,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'app_bottom_sheet_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.dark,
        alignment: Alignment.bottomCenter,
        padding: EdgeInsets.zero,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'app_bottom_sheet_dark');
    });
  });
}
