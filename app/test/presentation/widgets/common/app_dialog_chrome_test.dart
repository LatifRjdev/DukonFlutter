import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/presentation/widgets/common/app_dialog.dart';

void main() {
  late int confirmCount;

  Widget buildHost() {
    confirmCount = 0;
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => AppDialog.show(
              ctx,
              title: 'Confirm',
              message: 'Are you sure?',
              confirmText: 'Yes',
              cancelText: 'No',
              onConfirm: () => confirmCount++,
            ),
            child: const Text('Open dialog'),
          ),
        ),
      ),
    );
  }

  group('AppDialog chrome', () {
    testWidgets('shows title, message, and both buttons', (tester) async {
      await tester.pumpWidget(buildHost());
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
    });

    testWidgets('confirm callback fires and dismisses', (tester) async {
      await tester.pumpWidget(buildHost());
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(confirmCount, 1);
      expect(find.text('Are you sure?'), findsNothing);
    });
  });
}
