// Regression coverage for the 2026-09-21 manual QA finding: deleting a
// payroll adjustment is fully wired end-to-end on the backend/Bloc side
// (RemoveAdjustment event, PayrollBloc._onRemoveAdjustment,
// PayrollRepository.removeAdjustment) but had no UI trigger anywhere.
// This covers PayrollStaffCard's half: an optional onDeleteAdjustment
// callback renders a delete icon per adjustment row.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/domain/entities/payroll_entry.dart';
import 'package:dukonpro/domain/entities/payroll_adjustment.dart';
import 'package:dukonpro/presentation/widgets/payroll/payroll_staff_card.dart';

void main() {
  const adjustment = PayrollAdjustment(
    id: 'adj-1',
    type: 'BONUS',
    amount: 200,
    description: 'Премия за план',
  );
  final entryWithAdjustment = const PayrollEntry(
    id: 'pe1',
    staffId: 'st1',
    staffName: 'Алишер Каримов',
    totalAmount: 2875,
    adjustments: [adjustment],
  );

  Future<void> pump(WidgetTester tester, Widget card) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: card)),
      );

  testWidgets(
      'does not show a delete icon on the adjustment row when '
      'onDeleteAdjustment is not provided', (tester) async {
    await pump(
      tester,
      PayrollStaffCard(entry: entryWithAdjustment),
    );

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets(
      'shows a delete icon on the adjustment row when onDeleteAdjustment '
      'is provided, and tapping it invokes the callback with that '
      'adjustment', (tester) async {
    PayrollAdjustment? deleted;
    await pump(
      tester,
      PayrollStaffCard(
        entry: entryWithAdjustment,
        onDeleteAdjustment: (adj) => deleted = adj,
      ),
    );

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(deleted, adjustment);
  });
}
