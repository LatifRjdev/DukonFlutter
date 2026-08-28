// Regression coverage for #11: the "Возврат" (refund) action stayed
// visible/enabled even for a sale that had already been fully refunded,
// letting a cashier attempt a double-refund. TransactionDetailPage now
// hides the button once sale.status == 'RETURNED'.
//
// Note: SPEC.md's literal text names the status string 'REFUNDED', but the
// backend's real enum (api/prisma/schema.prisma SaleStatus) only ever sends
// COMPLETED / RETURNED / PARTIALLY_RETURNED / CANCELLED — there is no
// 'REFUNDED' value. These tests exercise the real 'RETURNED' string so a
// wrong-string regression would actually be caught.
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/domain/entities/sale.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/pages/sales/transaction_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Sale _fakeSale({required String status}) => Sale(
      id: 'test-sale-id',
      storeId: 'test-store-id',
      receiptNo: '#0001',
      subtotal: 100.0,
      total: 100.0,
      paymentType: 'CASH',
      paidAmount: 100.0,
      status: status,
      createdAt: DateTime(2026, 1, 15, 10, 30),
    );

Future<void> _pump(WidgetTester tester, Sale sale) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: TransactionDetailPage(sale: sale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TransactionDetailPage refund action (#11)', () {
    testWidgets(
        'hides the "Возврат" button when the sale is already RETURNED',
        (tester) async {
      await _pump(tester, _fakeSale(status: 'RETURNED'));

      expect(find.widgetWithText(OutlinedButton, 'Возврат'), findsNothing);
      // The print action should still be there and now take the full row.
      expect(find.widgetWithText(OutlinedButton, 'Печатать чек'), findsOneWidget);
    });

    testWidgets('shows an enabled "Возврат" button for a COMPLETED sale',
        (tester) async {
      await _pump(tester, _fakeSale(status: 'COMPLETED'));

      final refundButtonFinder = find.widgetWithText(OutlinedButton, 'Возврат');
      expect(refundButtonFinder, findsOneWidget);

      final refundButton = tester.widget<OutlinedButton>(refundButtonFinder);
      expect(refundButton.onPressed, isNotNull);
    });

    testWidgets(
        'still shows an enabled "Возврат" button for a PARTIALLY_RETURNED '
        'sale (partial refunds may still have un-refunded items left)',
        (tester) async {
      await _pump(tester, _fakeSale(status: 'PARTIALLY_RETURNED'));

      final refundButtonFinder = find.widgetWithText(OutlinedButton, 'Возврат');
      expect(refundButtonFinder, findsOneWidget);

      final refundButton = tester.widget<OutlinedButton>(refundButtonFinder);
      expect(refundButton.onPressed, isNotNull);
    });
  });
}
