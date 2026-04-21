import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/presentation/widgets/common/app_bottom_sheet.dart';

void main() {
  Widget buildHost() => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => AppBottomSheet.show<void>(
                ctx,
                title: 'Test title',
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Sheet body'),
                ),
              ),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      );

  group('AppBottomSheet chrome', () {
    testWidgets('shows title and body when opened', (tester) async {
      await tester.pumpWidget(buildHost());
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Test title'), findsOneWidget);
      expect(find.text('Sheet body'), findsOneWidget);
    });

    testWidgets('dismisses when tapping backdrop', (tester) async {
      await tester.pumpWidget(buildHost());
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet body'), findsOneWidget);

      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle();

      expect(find.text('Sheet body'), findsNothing);
    });
  });
}
