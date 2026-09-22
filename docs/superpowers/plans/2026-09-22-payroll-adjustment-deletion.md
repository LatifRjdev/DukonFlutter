# Payroll Adjustment Deletion (mobile UI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a delete icon + confirmation dialog for payroll adjustments, wiring up the already-fully-implemented `RemoveAdjustment` Bloc event that currently has no UI trigger anywhere in the app.

**Architecture:** `PayrollStaffCard` gains an optional `onDeleteAdjustment` callback rendered as a delete icon on each adjustment row; `payroll_page.dart` passes that callback wired to a new `_confirmDeleteAdjustment` method that shows a confirmation `AlertDialog` (mirroring the file's existing `_payAll` dialog) and dispatches the existing `RemoveAdjustment` event on confirm. No backend, Bloc, repository, or datasource changes — that entire chain already works.

**Tech Stack:** Flutter, flutter_bloc, bloc_test/mocktail for tests, golden_toolkit for existing golden coverage (unchanged by this plan).

**Spec:** `docs/superpowers/specs/2026-09-22-payroll-adjustment-deletion-design.md`

---

### Task 1: Add the delete icon to `PayrollStaffCard`

**Files:**
- Modify: `app/lib/presentation/widgets/payroll/payroll_staff_card.dart:8-13` (constructor), `:98-124` (adjustments rendering)
- Test: `app/test/presentation/widgets/payroll/payroll_staff_card_delete_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `app/test/presentation/widgets/payroll/payroll_staff_card_delete_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/presentation/widgets/payroll/payroll_staff_card_delete_test.dart`

Expected: FAIL — `onDeleteAdjustment` is not a defined named parameter of `PayrollStaffCard` (compile error), and/or `find.byIcon(Icons.delete_outline)` finds nothing.

- [ ] **Step 3: Add the callback and delete icon**

In `app/lib/presentation/widgets/payroll/payroll_staff_card.dart`, change the constructor (currently lines 8-13):

```dart
class PayrollStaffCard extends StatelessWidget {
  final PayrollEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onPay;
  final void Function(PayrollAdjustment)? onDeleteAdjustment;

  const PayrollStaffCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onPay,
    this.onDeleteAdjustment,
  });
```

Add the import at the top of the file (it's not currently imported directly — only used via `entry.adjustments`, which is typed through `payroll_entry.dart`'s own import of it):

```dart
import '../../../domain/entities/payroll_adjustment.dart';
```

Then change the adjustments rendering block (currently lines 98-124) from:

```dart
          if (entry.adjustments.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingSm),
            ...entry.adjustments.map((adj) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    adj.type == 'BONUS' ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    size: 14,
                    color: adj.type == 'BONUS' ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      adj.description,
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                  ),
                  Text(
                    '${adj.type == 'BONUS' ? '+' : '-'}${adj.amount.toStringAsFixed(0)} TJS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: adj.type == 'BONUS' ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
            )),
          ],
```

to:

```dart
          if (entry.adjustments.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingSm),
            ...entry.adjustments.map((adj) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    adj.type == 'BONUS' ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    size: 14,
                    color: adj.type == 'BONUS' ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      adj.description,
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                  ),
                  Text(
                    '${adj.type == 'BONUS' ? '+' : '-'}${adj.amount.toStringAsFixed(0)} TJS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: adj.type == 'BONUS' ? AppColors.success : AppColors.error,
                    ),
                  ),
                  if (onDeleteAdjustment != null)
                    InkWell(
                      onTap: () => onDeleteAdjustment!(adj),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            )),
          ],
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/presentation/widgets/payroll/payroll_staff_card_delete_test.dart`

Expected: PASS (2 tests)

- [ ] **Step 5: Run the existing golden test to confirm no visual regression**

Run: `cd app && flutter test test/presentation/widgets/payroll/payroll_staff_card_golden_test.dart`

Expected: PASS — the golden test's `sample()` doesn't pass `onDeleteAdjustment`, so it stays `null` and the rendered output (and therefore the golden image) is unchanged.

- [ ] **Step 6: Commit**

```bash
cd app
git add lib/presentation/widgets/payroll/payroll_staff_card.dart test/presentation/widgets/payroll/payroll_staff_card_delete_test.dart
git commit -m "feat(mobile): add onDeleteAdjustment callback to PayrollStaffCard"
```

---

### Task 2: Wire the confirmation dialog and dispatch in `payroll_page.dart`

**Files:**
- Modify: `app/lib/presentation/pages/payroll/payroll_page.dart` (add `_confirmDeleteAdjustment` method near `_payAll`, currently at line 98; pass `onDeleteAdjustment` to `PayrollStaffCard` at line 295)
- Test: `app/test/presentation/pages/payroll/payroll_adjustment_deletion_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `app/test/presentation/pages/payroll/payroll_adjustment_deletion_test.dart`:

```dart
// Regression coverage for the 2026-09-21 manual QA finding: deleting a
// payroll adjustment had no UI trigger. This covers PayrollPage's half:
// tapping the delete icon opens a confirmation dialog, "Отмена" dispatches
// nothing, "Удалить" dispatches RemoveAdjustment with the correct ids and
// closes the dialog.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/payroll_adjustment.dart';
import 'package:dukonpro/domain/entities/payroll_entry.dart';
import 'package:dukonpro/domain/entities/payroll_period.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/payroll/payroll_bloc.dart';
import 'package:dukonpro/presentation/blocs/payroll/payroll_event.dart';
import 'package:dukonpro/presentation/blocs/payroll/payroll_state.dart';
import 'package:dukonpro/presentation/pages/payroll/payroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayrollBloc extends MockBloc<PayrollEvent, PayrollState>
    implements PayrollBloc {}

void main() {
  late _MockPayrollBloc payrollBloc;

  const adjustment = PayrollAdjustment(
    id: 'adj-1',
    type: 'BONUS',
    amount: 200,
    description: 'Премия за план',
  );
  final entry = const PayrollEntry(
    id: 'e1',
    staffId: 'staff-1',
    staffName: 'Ali Valiev',
    totalAmount: 1200,
    adjustments: [adjustment],
  );
  final period = PayrollPeriod(
    id: 'period-1',
    month: 4,
    year: 2026,
    status: 'CALCULATED',
    totalAmount: 1200,
    staffCount: 1,
    payrolls: [entry],
  );

  setUp(() {
    payrollBloc = _MockPayrollBloc();
    when(() => payrollBloc.state)
        .thenReturn(PayrollPeriodDetailLoaded(period: period));
  });

  tearDown(() {
    payrollBloc.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: BlocProvider<PayrollBloc>.value(
          value: payrollBloc,
          child: const PayrollPage(storeId: 'store-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'tapping the delete icon opens a confirmation dialog showing the '
      'adjustment description and amount', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Удалить корректировку?'), findsOneWidget);
    expect(find.textContaining('Премия за план'), findsOneWidget);
    expect(find.textContaining('+200'), findsOneWidget);
  });

  testWidgets('tapping "Отмена" closes the dialog without dispatching anything',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verifyNever(() => payrollBloc.add(any(that: isA<RemoveAdjustment>())));
  });

  testWidgets(
      'tapping "Удалить" dispatches RemoveAdjustment with the correct ids '
      'and closes the dialog', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verify(() => payrollBloc.add(const RemoveAdjustment(
          storeId: 'store-1',
          periodId: 'period-1',
          adjustmentId: 'adj-1',
        ))).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/presentation/pages/payroll/payroll_adjustment_deletion_test.dart`

Expected: FAIL — `PayrollStaffCard` is never passed `onDeleteAdjustment` from `payroll_page.dart`, so no delete icon renders and `find.byIcon(Icons.delete_outline)` finds nothing.

- [ ] **Step 3: Add `_confirmDeleteAdjustment` and wire it up**

In `app/lib/presentation/pages/payroll/payroll_page.dart`, add this method directly after `_payAll` (which ends right before line 111's closing brace — insert after the method's closing `}`):

```dart
  void _confirmDeleteAdjustment(String periodId, PayrollAdjustment adjustment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить корректировку?'),
        content: Text(
          '"${adjustment.description}" '
          '${adjustment.type == 'BONUS' ? '+' : '-'}'
          '${adjustment.amount.toStringAsFixed(0)} TJS',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<PayrollBloc>().add(RemoveAdjustment(
                storeId: widget.storeId,
                periodId: periodId,
                adjustmentId: adjustment.id,
              ));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Удалить', style: TextStyle(color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }
```

Add the import at the top of the file (alongside the other domain entity imports — check the existing import block for the exact insertion point; it needs `PayrollAdjustment` for the method signature above):

```dart
import '../../../domain/entities/payroll_adjustment.dart';
```

Then update the `PayrollStaffCard` usage (currently lines 295-301) from:

```dart
                  child: PayrollStaffCard(
                    entry: entry,
                    onTap: busy ? null : () => context.push('/staff/${entry.staffId}', extra: widget.storeId),
                    onPay: (entry.isPaid || busy)
                        ? null
                        : () => _payIndividual(period.id, entry.id),
                  ),
```

to:

```dart
                  child: PayrollStaffCard(
                    entry: entry,
                    onTap: busy ? null : () => context.push('/staff/${entry.staffId}', extra: widget.storeId),
                    onPay: (entry.isPaid || busy)
                        ? null
                        : () => _payIndividual(period.id, entry.id),
                    onDeleteAdjustment: busy
                        ? null
                        : (adj) => _confirmDeleteAdjustment(period.id, adj),
                  ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/presentation/pages/payroll/payroll_adjustment_deletion_test.dart`

Expected: PASS (3 tests)

- [ ] **Step 5: Break-then-fix verification**

```bash
cd app
git stash push -- lib/presentation/pages/payroll/payroll_page.dart lib/presentation/widgets/payroll/payroll_staff_card.dart
flutter test test/presentation/pages/payroll/payroll_adjustment_deletion_test.dart test/presentation/widgets/payroll/payroll_staff_card_delete_test.dart
```

Expected: both test files FAIL (compile error on `onDeleteAdjustment` not being a recognized parameter, or the delete icon never being found).

```bash
git stash pop
flutter test test/presentation/pages/payroll/payroll_adjustment_deletion_test.dart test/presentation/widgets/payroll/payroll_staff_card_delete_test.dart
```

Expected: both files PASS again.

- [ ] **Step 6: Run the full payroll test suite to confirm no regressions**

Run: `cd app && flutter test test/presentation/pages/payroll/ test/presentation/widgets/payroll/`

Expected: all tests PASS, including the pre-existing `payroll_page_reload_test.dart`, `payroll_page_golden_test.dart`, `payroll_adjustment_navigation_test.dart`, `payroll_adjustment_reload_test.dart`, and `payroll_staff_card_golden_test.dart`.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/pages/payroll/payroll_page.dart test/presentation/pages/payroll/payroll_adjustment_deletion_test.dart
git commit -m "feat(mobile): add delete-adjustment confirmation dialog to PayrollPage

Wires the previously-orphaned RemoveAdjustment Bloc event (backend,
repository, and Bloc handler already existed) to a delete icon on each
payroll adjustment row plus a confirmation dialog, matching this
file's existing _payAll dialog convention. Found during the
2026-09-21 manual QA pass — the whole delete chain was implemented
except for a UI trigger."
```

---

### Task 3: Live verification on the emulator

**Files:** None (manual verification only).

- [ ] **Step 1: Rebuild and install the debug APK**

```bash
cd app
flutter build apk --debug
adb -s emulator-5554 shell am force-stop com.itlsolutions.dukonpro
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am start -n com.itlsolutions.dukonpro/.MainActivity
```

- [ ] **Step 2: Log in if the session has expired**

Phone: `+992900111222`, password: `test1234`. Use `adb shell uiautomator dump /sdcard/window_dump.xml` and read back the bounds of each field/button before tapping — do not estimate tap coordinates from a screenshot preview (the preview is scaled 900×2000 from the real 1080×2400 device resolution; using preview-pixel coordinates directly on the real device is off by a factor of 1.2x and will mis-tap, as happened repeatedly during the manual QA pass this plan originated from).

- [ ] **Step 3: Navigate to a payroll period with at least one adjustment**

"Ещё" → "Зарплата" → tap a calculated/paid period → if it has no adjustments yet, tap the "+" (Добавить корректировку) icon in the header, fill in a staff ID + amount + description, and add one first.

- [ ] **Step 4: Verify the delete icon and dialog**

Confirm a small delete icon now appears next to the adjustment's amount on the staff card. Tap it — confirm the "Удалить корректировку?" dialog shows the correct description and signed amount.

- [ ] **Step 5: Verify "Отмена" does not delete**

Tap "Отмена". Confirm the dialog closes and the adjustment is still listed with the same total.

- [ ] **Step 6: Verify "Удалить" deletes and recalculates**

Tap the delete icon again, then "Удалить". Confirm the adjustment row disappears and the staff member's "Итого" and the period's overall total both recalculate to exclude that adjustment's amount.

- [ ] **Step 7: Update the QA report**

Add a short confirmation note to `qa/2026-09-07-manual-test-run/REPORT.md`'s existing Section 11.3 finding about missing adjustment-delete UI (search for "удаление корректировки отсутствует в UI"), marking it ИСПРАВЛЕНО with the commit SHAs from Tasks 1 and 2, and noting the live verification steps above were completed successfully.

```bash
git add qa/2026-09-07-manual-test-run/REPORT.md
git commit -m "docs(qa): mark payroll adjustment deletion UI finding as fixed"
```

---

## Self-Review Notes

- **Spec coverage:** all three spec components (PayrollStaffCard callback, payroll_page.dart dialog + wiring, tests) map to Task 1/Task 2; live verification maps to Task 3; permissions and paid-period behavior require no code (spec explicitly says so) and are exercised implicitly by Task 3's live check landing on a real period regardless of its paid status.
- **No placeholders:** every step shows complete, exact code — no "add error handling" or "similar to Task N" shortcuts.
- **Type consistency:** `onDeleteAdjustment` is `void Function(PayrollAdjustment)?` everywhere it appears (widget field, page usage, test); `RemoveAdjustment(storeId, periodId, adjustmentId)` field names match the existing event class exactly (verified against `payroll_event.dart`).
