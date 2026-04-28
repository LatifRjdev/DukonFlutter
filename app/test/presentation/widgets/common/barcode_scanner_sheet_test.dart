import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/presentation/widgets/common/barcode_scanner_sheet.dart';

void main() {
  group('BarcodeScannerSheet', () {
    Future<void> openSheet(
      WidgetTester tester, {
      ValueChanged<String>? onScanned,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => BarcodeScannerSheet.show(
                  context,
                  onScanned: onScanned ?? (_) {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      // Use pumpAndSettle with a timeout; if camera throws, pump a few frames
      try {
        await tester.pumpAndSettle(const Duration(seconds: 2));
      } catch (_) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets(
      'should display title "Сканер штрихкода" when sheet is opened',
      (tester) async {
        await openSheet(tester);

        expect(find.text('Сканер штрихкода'), findsOneWidget);
      },
    );

    testWidgets(
      'should display close button (Icons.close_rounded) when sheet is opened',
      (tester) async {
        await openSheet(tester);

        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'should dismiss the sheet when close button is tapped',
      (tester) async {
        await openSheet(tester);

        // Sheet is open — title visible
        expect(find.text('Сканер штрихкода'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close_rounded));
        try {
          await tester.pumpAndSettle(const Duration(seconds: 2));
        } catch (_) {
          await tester.pump(const Duration(milliseconds: 300));
        }

        // Sheet dismissed — title gone
        expect(find.text('Сканер штрихкода'), findsNothing);
      },
    );

    testWidgets(
      'should display hint text "Наведите камеру на штрихкод" when sheet is opened',
      (tester) async {
        await openSheet(tester);

        expect(find.text('Наведите камеру на штрихкод'), findsOneWidget);
      },
    );
  });
}
