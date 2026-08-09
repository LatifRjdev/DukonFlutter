import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/presentation/widgets/pos/payment_method_tile.dart';

void main() {
  Widget buildTile({
    String value = 'cash',
    String groupValue = 'cash',
    ValueChanged<String>? onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PaymentMethodTile(
          label: 'Наличные',
          icon: Icons.money,
          value: value,
          groupValue: groupValue,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    );
  }

  group('PaymentMethodTile', () {
    testWidgets('should display label text', (tester) async {
      await tester.pumpWidget(buildTile());
      expect(find.text('Наличные'), findsOneWidget);
    });

    testWidgets('should display the icon', (tester) async {
      await tester.pumpWidget(buildTile());
      expect(find.byIcon(Icons.money), findsOneWidget);
    });

    testWidgets('should show selected state when value equals groupValue',
        (tester) async {
      await tester.pumpWidget(buildTile(value: 'cash', groupValue: 'cash'));
      await tester.pumpAndSettle();

      // The radio indicator inner circle should be present
      // Find the 12x12 inner dot container (only rendered when selected)
      final innerDots = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == 12 &&
            w.constraints?.maxHeight == 12,
      );
      expect(innerDots, findsOneWidget);
    });

    testWidgets('should not show inner dot when unselected', (tester) async {
      await tester.pumpWidget(buildTile(value: 'card', groupValue: 'cash'));
      await tester.pumpAndSettle();

      // The inner 12x12 dot should NOT be present
      final innerDots = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == 12 &&
            w.constraints?.maxHeight == 12,
      );
      expect(innerDots, findsNothing);
    });

    testWidgets('should call onChanged when tapped', (tester) async {
      String? received;
      await tester.pumpWidget(buildTile(
        value: 'card',
        groupValue: 'cash',
        onChanged: (v) => received = v,
      ));

      await tester.tap(find.text('Наличные'));
      await tester.pump();

      expect(received, equals('card'));
    });
  });
}
