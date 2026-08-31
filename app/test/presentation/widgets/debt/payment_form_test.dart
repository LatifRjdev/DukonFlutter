// Regression coverage for SPEC.md #23: the shared PaymentForm used by both
// the customer-debts and supplier-debts screens used to silently do nothing
// when the submit button was tapped with an invalid amount (<= 0, or greater
// than the max payable amount) — no error, no feedback, onSubmit just never
// fired. This exercises the fix: the amount field now shows an inline
// validation error and the form never calls onSubmit for an invalid amount.
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/widgets/common/app_button.dart';
import 'package:dukonpro/presentation/widgets/debt/payment_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpForm(
    WidgetTester tester, {
    required double maxAmount,
    required ValueChanged<({double amount, String method, String? notes})>
        onSubmit,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: Scaffold(
          body: PaymentForm(maxAmount: maxAmount, onSubmit: onSubmit),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterAmount(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextFormField).first, value);
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'shows an inline error and does not call onSubmit for a zero amount',
      (tester) async {
    var called = false;
    await pumpForm(
      tester,
      maxAmount: 1000,
      onSubmit: (_) => called = true,
    );

    await enterAmount(tester, '0');
    await tapSubmit(tester);

    expect(called, isFalse);
    expect(find.text('Некорректная сумма'), findsOneWidget);
  });

  testWidgets(
      'shows an inline error and does not call onSubmit for a negative amount',
      (tester) async {
    var called = false;
    await pumpForm(
      tester,
      maxAmount: 1000,
      onSubmit: (_) => called = true,
    );

    await enterAmount(tester, '-50');
    await tapSubmit(tester);

    expect(called, isFalse);
    expect(find.text('Некорректная сумма'), findsOneWidget);
  });

  testWidgets(
      'shows an inline error and does not call onSubmit for an amount over '
      'the maximum', (tester) async {
    var called = false;
    await pumpForm(
      tester,
      maxAmount: 500,
      onSubmit: (_) => called = true,
    );

    await enterAmount(tester, '600');
    await tapSubmit(tester);

    expect(called, isFalse);
    expect(find.text('Сумма не может превышать 500.00'), findsOneWidget);
  });

  testWidgets(
      'calls onSubmit with the parsed amount for a valid amount within range',
      (tester) async {
    ({double amount, String method, String? notes})? submitted;
    await pumpForm(
      tester,
      maxAmount: 1000,
      onSubmit: (payment) => submitted = payment,
    );

    await enterAmount(tester, '250');
    await tapSubmit(tester);

    expect(submitted, isNotNull);
    expect(submitted!.amount, 250);
  });
}
