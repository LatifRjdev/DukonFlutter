# Design: Fix the 41 functional discrepancies found in SPEC.md

**Date:** 2026-08-26
**Status:** Approved by user, ready for implementation planning.

## Background

`qa/2026-08-25-mobile-functional-spec/SPEC.md` documents expected behavior
for all 79 screens of the Dukon mobile app, derived from reading the actual
source code. That read-through surfaced 41 concrete discrepancies between
documented/expected behavior and what the code actually does — 4 Critical,
9 High, 28 Medium. One Critical finding (#4, roles-page permissions never
persisting) was independently reproduced live against a real running app
and real dev API (`qa/2026-08-25-mobile-functional-spec/COMPARISON.md`).

This document is the design for fixing all 41.

## Goal

Fix all 41 documented discrepancies in a single branch, in one
implementation plan, ordered by severity (Critical → High → Medium — the
same order as `SPEC.md`'s own numbering). Each fix is scoped, reviewed, and
tested individually; the branch is merged once every finding is closed and
`SPEC.md` is updated to reflect the fixed state.

## Scope

All 41 findings, all in `app/` (Flutter mobile app). No backend (`api/`)
changes are required — for every finding, the underlying API
call/repository method the fix needs already exists; the mobile app simply
never invokes it correctly (or at all). Findings that require a genuine
product/UX judgment call (not just a code fix) are included in scope and
resolved using best engineering judgment, per explicit user instruction —
each such judgment call is called out below and will be documented again,
briefly, in its implementation task.

## Findings, grouped by fix pattern

Most of the 41 findings reduce to a handful of repeatable fix shapes. Listing
them this way (rather than as 41 unrelated one-offs) is what lets this be
one coherent plan instead of 41 disconnected mini-projects.

### Pattern A — a needed event/action is never dispatched

| # | Finding | File(s) | Approach |
|---|---|---|---|
| 1 | Editing a product creates a duplicate instead of updating | `add_product_step1_page.dart`, `product_form_bloc.dart` | `ProductFormLoadProduct` is defined but never dispatched. Either dispatch it when entering edit mode, or (simpler, less state to manage) have step 1 seed `ProductFormBloc`'s state directly from the `product` passed via `extra` instead of relying on a fetch-by-id round trip. |
| 2 | Cart isn't cleared after a successful sale | `sale_success_page.dart`, `cart_bloc.dart` | `CartCleared` is defined but never dispatched. Dispatch it when "Новая продажа" is tapped (and/or right after `saleResult` is captured, whichever better matches user expectations — see judgment call below). |
| 4 | Roles-page permission toggles never persist | `roles_page.dart` | `SavePermissions` exists on the bloc but nothing on the page dispatches it. Add an explicit "Сохранить" action (matching the pattern already used on every other settings-style screen in the app) that dispatches it. |
| 16 | Shift history is always empty | `shifts_page.dart` | Only `LoadCurrentShift` is dispatched; `LoadShifts` (which populates history) never is. Dispatch both, or fold history-loading into a combined bloc event if that's cleaner. |
| 30 | Delivery list doesn't refresh after creating a new delivery | `delivery_list_page.dart`, `create_delivery_page.dart` | On successful creation, either return a success flag through `pop(true)` (mirroring the pattern already used in `add_investment_page.dart`) and reload on the list side, or have the list re-fetch on `didPopNext`/route re-entry. |

**Judgment call (#2):** the spec doesn't prescribe exactly *when* the cart
should clear — right after a successful sale (before "Новая продажа" is
even tapped) is the more conservative, less-surprising choice, since it
matches what almost every real POS app does and removes any window where a
half-stale cart could be accidentally re-submitted. This is the approach
that will be implemented.

### Pattern B — missing client-side validation/clamping

| # | Finding | File(s) | Approach |
|---|---|---|---|
| 6 | No stock-quantity check when incrementing cart quantity | `pos_checkout_page.dart` | Clamp the `+` stepper to the product's known `quantity`, matching the read-only stock display already shown elsewhere in the same file. |
| 7 | Discount can exceed subtotal, driving total negative | `cart_bloc.dart` | Clamp `total` to `max(0, subtotal - discount)`, matching the clamp already present in `CheckoutBloc` for the equivalent calculation. |
| 17 | Negative cash amount allowed when closing a shift | `shifts_page.dart` (close-shift dialog) | Add the same `>= 0` check already used on the open-shift screen's amount field. |
| 36 | Numeric threshold fields (notifications, loyalty settings) silently fall back to defaults on bad input | `notification_settings_page.dart`, `loyalty_settings_page.dart` | Add a validator that shows an inline error instead of silently substituting a default. |

### Pattern C — swallowed errors / missing user feedback

| # | Finding | File(s) | Approach |
|---|---|---|---|
| 12 | Refund failures show nothing to the user | `refund_page.dart`, `sales_history_bloc.dart` | Emit an error state on refund failure and show it via the same `AppSnackbar.error` pattern used elsewhere in the file. |
| 21 | Quick-create dialogs (customer/supplier) show a raw exception string | `customer_list_page.dart`, `supplier_list_page.dart` | Route the caught exception through `mapErrorToUserMessage` before displaying. |
| 23 | Debt payment forms silently no-op on invalid amount | `customer_debts_page.dart`, `supplier_debts_page.dart` (`PaymentForm`) | Show an inline validation error instead of a silent no-op. |
| 32 | Expense deletion errors are invisible | `expense_list_page.dart` | Add error-state handling with a snackbar, matching the pattern on every other list-with-delete screen. |
| 34 | Notification-list load error uses a hardcoded literal, not `AppLocalizations`/the shared error-mapper | `notifications_page.dart` | Route through `mapErrorToUserMessage` and `AppLocalizations`, matching every other screen. |
| 35 | Notification settings load error is completely hidden | `notification_settings_page.dart` | Surface it (snackbar or inline), matching the sibling notifications screen once #34 is fixed. |

### Pattern D — broken/missing navigation route

| # | Finding | File(s) | Approach |
|---|---|---|---|
| 5 | Staff-edit icon pushes an unregistered route | `staff_detail_page.dart` | `AddStaffPage` already has full edit-mode support (`staffMember` param) that's simply never invoked. Point the edit icon at `AddStaffPage(staffMember: ...)` instead of the dead `/edit-staff/...` route, rather than registering a new route for a screen that already exists. |

### Pattern E — UI control with no real effect

| # | Finding | File(s) | Approach |
|---|---|---|---|
| 9 | Sales-history period chips / custom date range don't affect the query | `sales_history_page.dart`, `sales_history_bloc.dart` | Thread the selected `from`/`to` into `SalesHistoryLoadRequested`. |
| 10 | Status filter in `SalesFilterSheet` is chosen but discarded | `sales_history_page.dart`, `sales_history_bloc.dart` | Add a status parameter to the load event and apply it, mirroring how payment-method filtering already works. |
| 18 | "Поделиться расчётом" (zakat) only copies to clipboard | `zakat_calculator_page.dart` | Use `Share.share(...)` (already imported/used elsewhere in the app, e.g. sale-success screen) instead of `Clipboard.setData`. |
| 19 | Two zakat-settings toggles ("Напоминание", "Долги поставщикам") don't save | `zakat_settings_page.dart` | Include both in the payload sent to `ZakatSettingsUpdated`. |
| 20 | Customer-list filter chips (Все/С долгом/VIP/Новые) don't filter | `customer_list_page.dart` | Implement real client-side filtering against the loaded list (the four categories are all derivable from fields already present: `debt > 0`, the existing VIP heuristic, `createdAt` recency). |
| 38 | Zakat gold-price refresh button doesn't update the form | `zakat_settings_page.dart` | Remove the `!_initialized` guard that blocks re-applying fetched values, or explicitly reset the relevant controllers on refresh. |
| 40 | Dashboard custom date-range picker doesn't affect the query | `dashboard_page.dart`, `dashboard_bloc.dart` | Thread the picked range into `DashboardPeriodChanged`. |
| 14 | Language selection doesn't change the app's locale | `language_settings_page.dart`, `main.dart`/`app.dart` (locale plumbing) | The most involved Medium-priority item — see judgment call below. |
| 37 | KKM "auto-print" toggle isn't persisted anywhere | `kkm_settings_page.dart` | Persist to `SharedPreferences`, matching the pattern used by `scanner_settings_page.dart` for its own toggles. |

**Judgment call (#14):** making language selection actually take effect
requires wiring a `Locale` through `MaterialApp` (reading the saved
preference at startup, and either hot-swapping it via a top-level
`ValueNotifier`/`InheritedWidget` or accepting the existing
"restart required" messaging as the real, permanent behavior instead of
aspirational copy). Given tg/uz translations are already deliberately
deferred project-wide (per this session's earlier l10n work), the fix here
is scoped narrowly: make the *Russian↔already-supported-locale* switch
actually apply on next app start (which is what the UI already promises,
word for word) rather than doing nothing. Implementing a live, no-restart
locale swap is out of scope — the existing UI copy ("перезапустите
приложение") becomes true instead of false, which is the actual bug being
fixed.

### Pattern F — hardcoded/fake data instead of real state

| # | Finding | File(s) | Approach |
|---|---|---|---|
| 13 | Settings hub shows 5 hardcoded fields (role, Telegram status, language, offline status, subscription plan) | `settings_page.dart` | Wire each independently: role from the already-loaded profile; Telegram status from `GET /telegram-bot/status` (same call `telegram_bot_settings_page.dart` already makes); language from the saved `SharedPreferences` value; offline/sync status from the same `GET /sync/status` call `offline_mode_page.dart` already makes; subscription plan from `SubscriptionBloc`, which is already loaded in `initState` but currently unused for display. |
| 15 | "Очистить кэш" doesn't clear any real cache | `offline_mode_page.dart` | Either make it real (clear the local SQLite tables that are safe to redownload) or rename/rescope the button to what it actually does (reset the sync-status timestamp) — resolved case-by-case per what's actually safe to wipe; default to making it real unless a table turns out to hold data with no server-side source of truth. |

### Pattern G — missing confirmation before an irreversible action

| # | Finding | File(s) | Approach |
|---|---|---|---|
| 31 | Expense/discount deletion has no confirmation dialog | `expense_list_page.dart`, `discounts_page.dart` | Add an `AlertDialog` confirmation, matching the pattern already used for category and product deletion elsewhere in the app. |

### Remaining findings (case-by-case, smaller/isolated)

| # | Finding | File(s) | Approach |
|---|---|---|---|
| 3 | "Forgot password" OTP flow doesn't lead to a password reset | `otp_page.dart`, `auth_bloc.dart` | `OtpPage` currently always calls `AuthVerifyOtpRequested` (login semantics). Give `OtpPage` an explicit `purpose` (`login` vs `passwordReset`), threaded through from `ForgotPasswordPage`'s navigation call; on `passwordReset`, after verifying, route to `CreatePasswordPage` with the phone+code instead of treating verification as a login. `CreatePasswordPage` and `resetPassword(...)` already exist and are fully implemented — this closes the gap that makes them unreachable. |
| 8 | Card payment skips the confirmation step other payment methods get | `pos_checkout_page.dart` | Add a lightweight confirmation (reuse the cash-payment screen's structure minus the received-amount field, or a simple confirm dialog) before firing `CheckoutProcessPayment` for `CARD`. |
| 11 | Refund allowed on an already-fully-refunded sale | `transaction_detail_page.dart` | Hide/disable the "Возврат" button when `sale.status == 'REFUNDED'`. |
| 22 | No supplier-edit screen exists at all | `supplier_detail_page.dart` | Add an edit action + form, mirroring `customer_form_page.dart`'s edit mode. |
| 24 | Stock-intake screen ignores the product passed via `extra` | `stock_intake_page.dart` | Read `extra` in `initState` and pre-select that product, skipping the search step when it's present. |
| 25 | Product photo picking is a no-op on all three add-product steps | `add_product_step1_page.dart`, `add_product_step3_page.dart` | Actually upload the picked image (multipart, matching the pattern already used for receipt uploads in `subscription_page.dart`) and include it in the product payload. |
| 26 | `EmptyProductsPage`'s import button passes an empty `storeId` | `empty_products_page.dart` | Read `storeId` from `StoreBloc` instead of assuming it's absent, matching how the equivalent button on `product_list_page.dart` does it. |
| 27 | Import-error state (`ImportError`) isn't handled by the screen's builder | `import_products_page.dart` | Add the missing `ImportError` branch to the state switch, matching the treatment of `ImportPreviewLoaded`. |
| 28 | Possible `TypeError` in delivery-detail `total` parsing | `delivery_detail_page.dart` | Fix the operator-precedence bug: `(j['amount'] ?? j['total']) as num?`. |
| 29 | `create_delivery_page.dart` uses hardcoded Russian strings | `create_delivery_page.dart` | Extract to `AppLocalizations`, following the exact conventions in `.claude/rules/mobile-l10n.md` established during this session's l10n migration. |
| 33 | Report-export errors bypass `mapErrorToUserMessage` | `reports_page.dart` | Route through the shared mapper like every other error path in the file. |
| 39 | `/sales/empty`, part of `/products/empty`, and `/pos` are dead/unreachable routes | `app_router.dart`, `empty_sales_page.dart`, `empty_products_page.dart` | Either wire them in properly where an empty-state screen is genuinely missing (none currently are — both list pages render their empty state inline), or remove the dead routes/constants. Default: remove, since keeping dead code that *looks* wired-in is itself a small maintenance trap — matches the precedent set by this session's earlier "delete or reconcile the dead `AppDatabase` class" recommendation from the code-quality audit. |
| 41 | Dashboard pull-to-refresh error is silently swallowed | `dashboard_page.dart`, `dashboard_bloc.dart` | Surface a snackbar on refresh failure instead of leaving the state unchanged with no signal. |

## Review discipline

- **Two-stage review** (spec-compliance, then code-quality — matching the
  discipline used for the first 10 tasks of this session's l10n plan): the
  4 Critical findings (#1–#4), since each changes bloc/state logic, not just
  UI wiring.
- **Single-stage combined review** (the discipline this session's l10n plan
  converged on after Task 10, once it was clear the split rarely caught
  anything the combined pass wouldn't): everything else — Highs and
  Mediums are overwhelmingly point fixes to a single file's `onPressed`
  handler, validator, or event payload.
- Any task that turns out, once an implementer actually opens the file, to
  be more structurally involved than its one-line description here
  suggests gets escalated to two-stage review rather than forced through
  single-stage — matching how this session has handled every prior
  surprise mid-plan.

## Testing

- `flutter test` run after every task; no task is considered done with a
  red suite.
- New targeted widget tests added where a fix changes genuinely testable
  behavior and no existing test covers it (e.g. #7's clamp, #11's
  disabled-refund-button, #20's client-side filter) — following this
  session's established break-then-fix discipline (temporarily revert the
  fix, confirm the new test fails, restore the fix, confirm it passes).
- After all 4 Critical findings are fixed and merged into the branch, a
  short re-run of `app/integration_test/live_qa_verification_test.dart`
  (the test that already live-confirmed finding #4) against a real
  emulator + dev API, extended to also probe #1 and #2 — the two Criticals
  most amenable to a quick live check (create→edit→recount products;
  checkout→success→new-sale→recheck cart).

## Done criteria

- All 41 findings have a corresponding commit.
- `flutter test` and `flutter analyze` are clean on the final branch state.
- `qa/2026-08-25-mobile-functional-spec/SPEC.md`'s "Сводный список
  найденных расхождений" is updated: every item marked fixed (with commit
  reference), or, for the rare case a "finding" turns out on closer
  implementation-time inspection to have been a false positive, marked as
  such with the reasoning — not silently dropped.
- Final whole-branch review (matching this session's standing practice),
  then the standard finishing-a-development-branch options presented
  (merge locally / PR / keep / discard).
