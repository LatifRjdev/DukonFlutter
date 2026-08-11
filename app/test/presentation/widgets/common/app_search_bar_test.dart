import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/presentation/widgets/common/app_search_bar.dart';

void main() {
  group('AppSearchBar', () {
    testWidgets(
        'shows a clear button once text is entered and it clears the field on tap',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? lastOnChanged;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchBar(
              controller: controller,
              onChanged: (v) => lastOnChanged = v,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsNothing);

      await tester.enterText(find.byType(TextField), 'молоко');
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(lastOnChanged, '');
    });

    testWidgets('never shows a clear button when onScanTap is provided',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchBar(
              onScanTap: () {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'молоко');
      await tester.pump();

      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    });
  });
}
