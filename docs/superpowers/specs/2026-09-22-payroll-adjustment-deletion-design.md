# Payroll Adjustment Deletion (mobile UI) — Design

**Context.** Found during the 2026-09-21/22 manual QA pass
(`qa/2026-09-07-manual-test-run/REPORT.md`, Section 11.3): the ability to
delete a payroll adjustment is fully implemented end-to-end on the mobile
side — `RemoveAdjustment` event, `PayrollBloc._onRemoveAdjustment`,
`PayrollRepository.removeAdjustment`, `PayrollRemoteDatasource.removeAdjustment`,
and the backend `DELETE /stores/:storeId/payroll/:periodId/adjustments/:id`
endpoint — but there is no UI anywhere that dispatches `RemoveAdjustment`.
A staff member's mistakenly-added bonus or deduction currently cannot be
undone from the app.

**Goal.** Add the missing UI trigger only. No new backend or Bloc work.

## Architecture

Deletion happens in place on `PayrollPage` (period detail view), not via a
separate route — so the shared-`PayrollBloc` navigation-reload issue that
affected "add adjustment" (fixed earlier this session, commit `e20b2bf`)
does not apply here. `_onRemoveAdjustment` already emits `PayrollLoading`
then re-dispatches `LoadPayrollPeriod` on success; `PayrollPage`'s existing
`busy: true` handling (added for the same earlier fix) already keeps the
period detail visible with actions disabled while that reload is in
flight, so no additional Bloc or page-level state-preservation work is
needed.

## Components

1. **`PayrollStaffCard`** (`lib/presentation/widgets/payroll/payroll_staff_card.dart`)
   — add an optional `void Function(PayrollAdjustment)? onDeleteAdjustment`
   constructor parameter. When non-null, each adjustment row (currently a
   `Row` with a type icon, description, and signed amount) gets a trailing
   delete icon button (`Icons.delete_outline`, small, muted color) that
   calls `onDeleteAdjustment(adj)`. When null (the default), rendering is
   unchanged — this keeps the widget usable in contexts that don't want
   the delete affordance (none currently, but keeps the parameter honest
   about being optional rather than always-on).

2. **`payroll_page.dart`** (`_buildPeriodDetail`) — pass
   `onDeleteAdjustment: busy ? null : (adj) => _confirmDeleteAdjustment(period.id, adj)`
   to each `PayrollStaffCard`.

3. **`payroll_page.dart`** — new private method:
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
   This mirrors the existing `_payAll` dialog's structure in the same file
   (`showDialog` + `AlertDialog` + `Navigator.pop(ctx)` in both actions),
   for consistency with the file's own conventions.

## Permissions

No new permission check. The "Добавить корректировку" button is already
only reachable by users whose role has `payroll.manage` (gated by the
existing role/permissions system and by the backend endpoint itself); the
delete icon inherits the same reachability since it lives on the same
screen. The backend's `DELETE .../adjustments/:id` endpoint already
enforces `payroll.manage` independently, so there's no client-side
bypass risk even if this assumption were ever wrong.

## Paid periods

Deletion is allowed unconditionally, including on periods already marked
`PAID`. This is not new behavior: the backend's `removeAdjustment` already
recalculates `Payroll.totalAmount` and the period total via
`recalculatePayroll`/`recalculatePeriod` regardless of paid status — the
mobile UI simply exposes an existing, already-correct backend capability.
No confirmation-dialog copy changes based on paid status; the standard
"Удалить корректировку?" + description/amount is sufficient context for
this decision.

## Testing

1. **Widget test** (`test/presentation/widgets/payroll/payroll_staff_card_test.dart`,
   new or extended if it exists): delete icon is absent when
   `onDeleteAdjustment` is null, present and tappable when provided;
   tapping it invokes the callback with the correct `PayrollAdjustment`.
2. **Page-level regression test** (extend `payroll_page_reload_test.dart`
   or add a new file following its `MockPayrollBloc` + `whenListen`
   pattern): tapping the delete icon on a period-detail's adjustment row
   opens the confirmation dialog; tapping "Отмена" dispatches nothing;
   tapping "Удалить" dispatches `RemoveAdjustment` with the correct
   `storeId`/`periodId`/`adjustmentId` and closes the dialog.
3. Break-then-fix verification per this session's established discipline:
   stash the `PayrollStaffCard`/`payroll_page.dart` changes, confirm the
   new tests fail, restore, confirm they pass.
4. Live verification on the emulator: open a period with at least one
   adjustment, delete it, confirm the row disappears and the period/staff
   totals recalculate, confirm "Отмена" leaves the adjustment intact.

## Out of scope

- Bulk delete / multi-select.
- Undo (snackbar with "Отменить" action) — not requested, would need a
  new design decision if wanted later.
- Any change to `PayrollAdjustment`, `RemoveAdjustment`, `PayrollBloc`, the
  repository, datasource, or backend — all already correct and untouched.
