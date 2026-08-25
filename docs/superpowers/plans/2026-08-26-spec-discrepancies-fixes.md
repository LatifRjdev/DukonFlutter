# Fix 41 SPEC.md Functional Discrepancies — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close all 41 functional discrepancies documented in
`qa/2026-08-25-mobile-functional-spec/SPEC.md`'s "Сводный список найденных
расхождений", in severity order (Critical → High → Medium), each as an
isolated, reviewed, tested commit.

**Architecture:** All 41 fixes live in `app/` (Flutter). No backend changes
are required anywhere in this plan — every fix either calls an
already-existing repository/API method that the UI currently fails to
invoke, or corrects purely client-side logic (validation, state clamping,
navigation, error display).

**Tech Stack:** Flutter/Dart, `flutter_bloc`, `go_router`, existing test
conventions (`flutter_test`, golden tests where already present,
`integration_test` for the two live-QA-extension tasks at the end).

---

## Standing conventions for every task in this plan

Read once, apply to every task below — not repeated per-task.

1. **Read the target file(s) in full before editing.** SPEC.md's research
   (and this plan's task descriptions) describe the confirmed bug and the
   exact bloc events/methods/routes involved, but always verify against the
   current file content before writing the fix — do not assume the
   plan's snippet is byte-for-byte current.
2. **Error display convention:** this app has an established
   `mapErrorToUserMessage(e)` helper and `AppSnackbar.error(context, message)`
   widget used consistently across the codebase. Any task that adds error
   handling must route through both, not a raw `e.toString()` or a
   hardcoded string — unless the task explicitly says otherwise.
3. **Confirmation-dialog convention:** this app already has an established
   `AlertDialog` pattern for irreversible-action confirmation (see
   category deletion in `categories_page.dart` or product deletion in
   `product_detail_page.dart` for the exact shape to match — title, body
   text, "Отмена"/destructive-action button pair).
4. **l10n convention:** any NEW user-facing string this plan introduces
   must go through `AppLocalizations`/`app_ru.arb`, following
   `.claude/rules/mobile-l10n.md` exactly (check for an existing equivalent
   key before minting a new one; Russian-only for now, tg/uz fall back per
   the project's already-established decision — do not translate to
   tg/uz).
5. **Every task ends with:** `flutter analyze <touched files>` clean, the
   relevant existing test(s) passing (run `find app/test -iname "*<page>*"`
   to locate them), and a commit. If a task adds genuinely new testable
   behavior with no existing coverage, add a focused test using the
   break-then-fix discipline: temporarily revert your fix, confirm the new
   test fails for the right reason, restore the fix, confirm it passes.
6. **Commit message format:** `fix(mobile): <short description> (SPEC.md #<N>)`
   — the `#<N>` reference is required on every commit in this plan, it's
   how the final SPEC.md-update task cross-references what closed each
   finding.
7. **Review discipline:** Tasks 1–4 (Critical) get two-stage review
   (spec-compliance, then code-quality — dispatch as two separate reviewer
   subagents per `superpowers:subagent-driven-development`). Tasks 5
   onward get single-stage combined review by default; escalate any
   specific task to two-stage if the implementer's report reveals it
   touched more structural logic than its description implied.

---

## CRITICAL (two-stage review)

### Task 1: Fix product edit creating a duplicate instead of updating (#1)

**Files:**
- Modify: `app/lib/presentation/pages/product/add_product_step1_page.dart`
- Modify: `app/lib/presentation/blocs/product_form/product_form_bloc.dart` (exact path — confirm via `find app/lib -iname "product_form_bloc.dart"`)
- Test: `app/test/presentation/pages/product/add_product_step1_page_test.dart` (create if none exists covering this)

**Confirmed bug:** `ProductFormLoadProduct` is a defined bloc event that,
when dispatched, would set `editingProductId` (which `state.isEditing`
reads) — but no screen in the app ever dispatches it. `AddProductStep1Page`
receives `extra: {'product': product, 'isEditing': true}` from
`ProductDetailPage`'s edit button, reads `product`/`isEditing` in
`didChangeDependencies`, and prefills the text fields — but never tells
`ProductFormBloc` that this is an edit. By the time `AddProductStep3Page`
calls `ProductFormSubmit`, `state.isEditing` is `false`, so it calls
`createProduct` instead of `updateProduct`, creating a duplicate.

- [ ] **Step 1: Read `product_form_bloc.dart` in full** to confirm the
  exact shape of `ProductFormLoadProduct`, `editingProductId`, and how
  `state.isEditing` is derived. Confirm whether `ProductFormLoadProduct`
  fetches the product by ID from the server, or whether it can be seeded
  directly from an already-in-hand `Product` object without a redundant
  network round trip.

- [ ] **Step 2: Fix `add_product_step1_page.dart`'s edit-mode entry.** In
  the `didChangeDependencies` (or equivalent) block that currently reads
  `product`/`isEditing` from `extra` and only prefills text fields, also
  dispatch the bloc event that correctly marks the form as editing that
  product's ID — prefer seeding `ProductFormBloc`'s `editingProductId`
  directly from the already-passed `product.id` (no extra fetch) over
  dispatching `ProductFormLoadProduct` if that event triggers a redundant
  server round-trip for data you already have in hand.

- [ ] **Step 3: Verify `ProductFormSubmit`'s branch selection.** Confirm
  that with the fix in place, `state.isEditing` is `true` when submitting
  from an edit-mode entry, and that the submit path calls `updateProduct`
  (not `createProduct`).

- [ ] **Step 4: Manual verification via widget test.** Write or extend a
  test that: constructs `AddProductStep1Page` with `isEditing: true` and a
  fake `product`, drives through all 3 steps with the bloc mocked/faked,
  and asserts the bloc's final dispatched submit event has `isEditing: true`
  (or equivalent — assert on whatever field controls the create/update
  branch). Use the break-then-fix discipline.

- [ ] **Step 5: Run `flutter analyze` on both touched files.** Expected:
  no issues.

- [ ] **Step 6: Commit.**
  ```
  git add app/lib/presentation/pages/product/add_product_step1_page.dart app/lib/presentation/blocs/product_form/product_form_bloc.dart app/test/presentation/pages/product/add_product_step1_page_test.dart
  git commit -m "fix(mobile): product edit now updates instead of creating a duplicate (SPEC.md #1)"
  ```

---

### Task 2: Clear the cart after a successful sale (#2)

**Files:**
- Modify: `app/lib/presentation/pages/pos/sale_success_page.dart`
- Reference (read-only, confirm event shape): `app/lib/presentation/blocs/pos/cart_bloc.dart`
- Test: `app/test/presentation/pages/pos/sale_success_page_test.dart` (create if none exists)

**Confirmed bug:** `CartCleared` is a defined `CartBloc` event that's never
dispatched anywhere in the app. After a successful sale, the cart retains
its prior contents indefinitely.

**Judgment call (per the approved design doc):** clear the cart
immediately once the sale succeeds — not deferred until "Новая продажа" is
tapped — since that's the more conservative choice and matches standard
POS UX (no window where a stale cart could be resubmitted).

- [ ] **Step 1: Read `sale_success_page.dart` in full** to find where
  `sale.total`/success state is first available (the point right after
  `CheckoutProcessPayment` resolves successfully — likely in the
  `BlocListener` that first detects `saleResult != null`, in whichever
  screen transitions to `/pos/success`, or at the very top of
  `SaleSuccessPage`'s own `initState`/`build`).

- [ ] **Step 2: Dispatch `CartCleared`** at that point, reading `CartBloc`
  via `context.read<CartBloc>()`. Confirm this is a one-time dispatch (not
  re-fired on every rebuild) — guard with `initState` or an equivalent
  single-shot mechanism.

- [ ] **Step 3: Confirm no other screen in the checkout flow (cash
  payment, credit sale) needs the same fix** — since all payment methods
  route through `SaleSuccessPage` on success (confirmed in SPEC.md's POS
  section), a single fix point here should cover cash, card, and debt sales
  uniformly. Verify this is actually true by re-reading the navigation
  code for all three payment paths before assuming one fix covers all.

- [ ] **Step 4: Add/extend a widget test** that pumps `SaleSuccessPage`
  with a populated `CartBloc`, and asserts the cart is empty after the
  page settles. Use the break-then-fix discipline.

- [ ] **Step 5: Run `flutter analyze`.** Expected: no issues.

- [ ] **Step 6: Commit.**
  ```
  git add app/lib/presentation/pages/pos/sale_success_page.dart app/test/presentation/pages/pos/sale_success_page_test.dart
  git commit -m "fix(mobile): clear cart after a successful sale (SPEC.md #2)"
  ```

---

### Task 3: Fix the "Забыли пароль" flow so it actually resets the password (#3)

**Files:**
- Modify: `app/lib/presentation/pages/auth/otp_page.dart`
- Modify: `app/lib/presentation/pages/auth/forgot_password_page.dart`
- Reference (read-only): `app/lib/presentation/blocs/auth/auth_bloc.dart`, `app/lib/presentation/pages/auth/create_password_page.dart`
- Test: `app/test/presentation/pages/auth/otp_page_test.dart` (create if none exists covering both purposes)

**Confirmed bug:** `OtpPage` always calls `AuthVerifyOtpRequested`, which
`AuthBloc` treats as an OTP-login (saves tokens, authenticates, redirects
to `/home`). `ForgotPasswordPage` navigates to `/otp` after sending a reset
code, but verifying that code on `OtpPage` logs the user in directly
instead of routing to `CreatePasswordPage` — which already fully
implements phone+code→new-password via the already-existing
`AuthResetPasswordRequested` event and `resetPassword(...)` repository
method. `CreatePasswordPage` is currently unreachable dead code.

- [ ] **Step 1: Read `otp_page.dart`, `forgot_password_page.dart`, and
  `create_password_page.dart` in full.** Confirm the exact constructor
  signature `OtpPage` currently has (it takes `phone` via `extra`) and
  what `CreatePasswordPage` expects (`Map<String, String>` with `phone`
  and `otp` keys, per SPEC.md's research).

- [ ] **Step 2: Add a `purpose` distinction to `OtpPage`'s navigation.**
  In `forgot_password_page.dart`, change the `context.push('/otp', extra: state.phone)`
  call to pass enough information for `OtpPage` to know this is a
  password-reset flow, not a login flow — e.g. change `extra` to a small
  map `{'phone': state.phone, 'purpose': 'passwordReset'}`, and update
  `OtpPage`'s `extra` parsing (and the router's registration in
  `app_router.dart` if it does any type-casting on `extra`) accordingly.
  Confirm no other caller of `/otp` exists that would break from this
  signature change (SPEC.md's research found `ForgotPasswordPage` is the
  *only* caller — re-verify with `grep -rn "'/otp'" app/lib/` before
  assuming this is safe).

- [ ] **Step 3: Branch `OtpPage`'s "Подтвердить" handler on `purpose`.**
  When `purpose == 'passwordReset'`: after the OTP is confirmed (either via
  a lighter-weight verification path if `AuthBloc` has one, or by treating
  a successful `AuthVerifyOtpRequested` response as "code is valid" without
  persisting the resulting login tokens), navigate to
  `context.push('/create-password', extra: {'phone': widget.phone, 'otp': _otp})`
  instead of waiting for `AuthAuthenticated`. When `purpose` is absent/`login`
  (the default, preserving current behavior for any future login-OTP use),
  keep the existing behavior unchanged.

- [ ] **Step 4: Read `AuthBloc`'s `_onVerifyOtpRequested` handler closely**
  to determine whether `authRepository.verifyOtp(phone, code)` has any
  side effect (token persistence) that needs to be avoided for the
  password-reset path. If `verifyOtp` unconditionally logs the user in
  server-side (not just client-side token storage), do not call it for the
  password-reset purpose at all — instead, treat successful code entry on
  this screen as sufficient to proceed to `CreatePasswordPage`, and let
  `resetPassword(phone, code, newPassword)` be the actual point where the
  code is validated server-side (it already takes `code` as a parameter,
  confirmed in SPEC.md's research) — this avoids depending on OTP
  double-validation semantics that may not exist server-side.

- [ ] **Step 5: Verify `CreatePasswordPage`'s existing form still works
  unchanged** — it should require no changes.

- [ ] **Step 6: Add/extend a test** covering both `OtpPage` purposes:
  asserts login-purpose still calls `AuthVerifyOtpRequested`, and
  password-reset-purpose navigates to `/create-password` with the correct
  `extra`.

- [ ] **Step 7: Run `flutter analyze`** on all touched files.

- [ ] **Step 8: Commit.**
  ```
  git add app/lib/presentation/pages/auth/otp_page.dart app/lib/presentation/pages/auth/forgot_password_page.dart app/test/presentation/pages/auth/otp_page_test.dart
  git commit -m "fix(mobile): forgot-password OTP now routes to password reset instead of logging in (SPEC.md #3)"
  ```

---

### Task 4: Add a working Save action to the Roles page (#4)

**Files:**
- Modify: `app/lib/presentation/pages/roles/roles_page.dart`
- Reference (read-only): `app/lib/presentation/blocs/roles/roles_bloc.dart`
- Test: `app/test/presentation/pages/roles/roles_page_test.dart` (create if none exists)

**Confirmed bug (already live-reproduced in this session — see
`qa/2026-08-25-mobile-functional-spec/COMPARISON.md`):** toggling a
permission switch only calls `UpdatePermission`, which updates in-memory
bloc state. `SavePermissions` exists on the bloc and actually persists to
the server, but nothing on `RolesPage` ever dispatches it.

- [ ] **Step 1: Read `roles_page.dart` and `roles_bloc.dart` in full.**
  Confirm `SavePermissions`'s exact signature (likely `storeId`, and
  either the full permissions map or nothing if the bloc already tracks
  pending changes internally).

- [ ] **Step 2: Add a "Сохранить" action to `RolesPage`.** Follow the
  existing app convention for a save button on a settings-style page (see
  `loyalty_settings_page.dart` or `zakat_settings_page.dart` for the
  established shape — button in the body or `AppBar`, loading state while
  saving, success/error snackbar on completion). Wire it to dispatch
  `SavePermissions` with whatever the bloc currently expects. Add the new
  button label to `app_ru.arb` if the phrase "Сохранить" isn't already a
  reusable key (it almost certainly already exists — check before
  minting a new key, per the standing l10n convention above).

- [ ] **Step 3: Add a success/error `BlocListener`** matching the pattern
  used elsewhere (e.g. `AppSnackbar.success`/`AppSnackbar.error`) so the
  user gets feedback that the save actually happened.

- [ ] **Step 4: Add/extend a widget test** that: toggles a permission,
  taps Save, and asserts `SavePermissions` was dispatched with the
  expected payload. Use the break-then-fix discipline.

- [ ] **Step 5: Live-QA note for later** — this fix should be re-verified
  against the same live reproduction steps already used in
  `app/integration_test/live_qa_verification_test.dart`'s STEP 3 (toggle →
  navigate away → navigate back → confirm the toggle now survives). This
  re-verification happens in the dedicated Task 42 at the end of this
  plan, not here — just leave the fix correct and tested at the unit level
  for now.

- [ ] **Step 6: Run `flutter analyze`.**

- [ ] **Step 7: Commit.**
  ```
  git add app/lib/presentation/pages/roles/roles_page.dart app/test/presentation/pages/roles/roles_page_test.dart
  git commit -m "fix(mobile): roles page permission changes now actually save (SPEC.md #4)"
  ```

---

## HIGH (single-stage review by default)

### Task 5: Fix the broken staff-edit route (#5)

**Files:**
- Modify: `app/lib/presentation/pages/staff/staff_detail_page.dart`
- Reference (read-only): `app/lib/presentation/pages/staff/add_staff_page.dart`, `app/lib/core/router/app_router.dart`

**Confirmed bug:** the edit icon on `StaffDetailPage` pushes
`/edit-staff/:storeId/:staffId`, which is not registered as a `GoRoute`
anywhere. `AddStaffPage` already fully supports edit mode via a
`staffMember` constructor parameter — it's simply never invoked that way.

- [ ] **Step 1: Read `staff_detail_page.dart`'s edit-icon handler and
  `add_staff_page.dart`'s constructor** to confirm the exact
  `staffMember`-driven edit-mode shape (what type it expects — likely the
  same `Staff`/`StaffMember` entity the detail page already has loaded).

- [ ] **Step 2: Replace the broken `context.push('/edit-staff/...')` call**
  with `context.push('/staff/add', extra: {'storeId': storeId, 'staffMember': staff})`
  (or whatever `extra` shape `AddStaffPage` actually expects once
  confirmed in Step 1) — pointing at the existing, working screen instead
  of a dead route.

- [ ] **Step 3: Confirm `add_staff_page.dart`'s `_isEditing`/`staffMember`
  branch actually calls `updateStaff` (not `createStaff`) on submit** —
  SPEC.md's research flagged this branch as previously unreachable, so it
  may itself have a latent, never-exercised bug. Read the submit handler
  closely; fix if the update branch is broken.

- [ ] **Step 4: Run existing tests for both files** (`find app/test -iname
  "*staff*"`).

- [ ] **Step 5: Run `flutter analyze`.**

- [ ] **Step 6: Commit.**
  ```
  git add app/lib/presentation/pages/staff/staff_detail_page.dart app/lib/presentation/pages/staff/add_staff_page.dart
  git commit -m "fix(mobile): staff-edit icon now opens the working edit form (SPEC.md #5)"
  ```

---

### Task 6: Clamp cart quantity to available stock (#6)

**Files:**
- Modify: `app/lib/presentation/pages/pos/pos_checkout_page.dart`

- [ ] **Step 1: Read the cart-item stepper's `+` handler in full.**

- [ ] **Step 2: Clamp the increment** so it cannot exceed the item's known
  `product.quantity`. When the clamp is hit, show a lightweight snackbar
  (e.g. "Больше нет в наличии" — check `app_ru.arb` for an existing
  equivalent key first) rather than silently doing nothing.

- [ ] **Step 3: Add a widget test** asserting the `+` stepper stops
  incrementing at the product's stock quantity.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/pos/pos_checkout_page.dart
  git commit -m "fix(mobile): cart quantity can no longer exceed stock on hand (SPEC.md #6)"
  ```

---

### Task 7: Clamp cart discount so total can't go negative (#7)

**Files:**
- Modify: `app/lib/presentation/blocs/pos/cart_bloc.dart`
- Reference (read-only, match the existing clamp shape): `app/lib/presentation/blocs/pos/checkout_bloc.dart`

- [ ] **Step 1: Read both blocs' total-calculation logic.** Confirm the
  exact clamp `CheckoutBloc` already applies (`max(0, subtotal - discount)`
  or equivalent).

- [ ] **Step 2: Apply the identical clamp in `CartBloc`'s total getter/
  calculation.**

- [ ] **Step 3: Add a bloc test** asserting a discount larger than the
  subtotal produces a total of exactly 0, not a negative number.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/blocs/pos/cart_bloc.dart
  git commit -m "fix(mobile): cart total can no longer go negative from an oversized discount (SPEC.md #7)"
  ```

---

### Task 8: Add a confirmation step before processing card payments (#8)

**Files:**
- Modify: `app/lib/presentation/pages/pos/pos_checkout_page.dart`

**Confirmed bug:** cash and debt payments both route through a dedicated
confirmation screen before the sale is actually submitted; card payment
alone processes instantly on tapping the checkout CTA, with no chance to
review/cancel.

- [ ] **Step 1: Read the `CARD` branch of the checkout CTA handler.**

- [ ] **Step 2: Add a lightweight confirmation** before dispatching
  `CheckoutPaidAmountChanged`+`CheckoutProcessPayment` for `CARD` — a
  simple `AlertDialog` showing the total and payment method with
  "Отмена"/"Подтвердить" is sufficient; a full dedicated screen (like cash
  payment has) is not required for parity, just *a* confirmation step
  matching the spirit of the other two payment methods.

- [ ] **Step 3: Add a widget test** asserting the card-payment path shows
  a confirmation before `CheckoutProcessPayment` fires, and that
  cancelling it does not process the sale.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/pos/pos_checkout_page.dart
  git commit -m "fix(mobile): card payment now asks for confirmation before processing (SPEC.md #8)"
  ```

---

### Task 9: Wire sales-history period/date-range filters into the actual query (#9)

**Files:**
- Modify: `app/lib/presentation/pages/sales/sales_history_page.dart`
- Modify: `app/lib/presentation/blocs/sales/sales_history_bloc.dart` (confirm exact path/name)
- Modify: `app/lib/presentation/blocs/sales/sales_history_event.dart` (if `SalesHistoryLoadRequested` needs new fields)

- [ ] **Step 1: Read `sales_history_page.dart`'s period-chip and
  date-range-picker handlers, and `SalesHistoryLoadRequested`'s current
  fields.**

- [ ] **Step 2: Add `dateFrom`/`dateTo` fields to `SalesHistoryLoadRequested`
  if not already present**, and have the bloc's handler actually apply
  them to the query instead of ignoring them.

- [ ] **Step 3: Thread the selected period/custom range into the event**
  from both the period chips and the date-range picker's `onSelected`
  callback.

- [ ] **Step 4: Add a bloc test** asserting `SalesHistoryLoadRequested`
  with a date range produces a request with those exact dates.

- [ ] **Step 5: Run `flutter analyze`.**

- [ ] **Step 6: Commit.**
  ```
  git add app/lib/presentation/pages/sales/sales_history_page.dart app/lib/presentation/blocs/sales/sales_history_bloc.dart app/lib/presentation/blocs/sales/sales_history_event.dart
  git commit -m "fix(mobile): sales-history period and custom date-range filters now actually filter (SPEC.md #9)"
  ```

---

### Task 10: Wire the status filter from SalesFilterSheet into the query (#10)

**Files:**
- Modify: `app/lib/presentation/widgets/pos/sales_filter_sheet.dart`
- Modify: `app/lib/presentation/pages/sales/sales_history_page.dart`
- Modify: `app/lib/presentation/blocs/sales/sales_history_bloc.dart` / event file (same files touched in Task 9 — do this task immediately after Task 9 to avoid re-opening the same files twice; if working through this plan out of order for any reason, do these two together)

- [ ] **Step 1: Read `SalesFilterSheet`'s `onApply` callback and
  `SalesFilter`'s `status` field.**

- [ ] **Step 2: Add a `status` parameter to `SalesHistoryLoadRequested`**
  (if Task 9 didn't already add a general "extra filter fields" mechanism
  that covers this), and apply it in the bloc's query construction,
  mirroring how payment-method filtering already works.

- [ ] **Step 3: Pass `filter.status` through from `sales_history_page.dart`'s
  `onApply` handler** into the event dispatch.

- [ ] **Step 4: Add a bloc test** asserting a status filter produces a
  request carrying that status.

- [ ] **Step 5: Run `flutter analyze`.**

- [ ] **Step 6: Commit.**
  ```
  git add app/lib/presentation/widgets/pos/sales_filter_sheet.dart app/lib/presentation/pages/sales/sales_history_page.dart app/lib/presentation/blocs/sales/sales_history_bloc.dart
  git commit -m "fix(mobile): sales-history status filter now actually filters (SPEC.md #10)"
  ```

---

### Task 11: Disable "Возврат" on already-refunded sales (#11)

**Files:**
- Modify: `app/lib/presentation/pages/sales/transaction_detail_page.dart`

- [ ] **Step 1: Read the "Возврат" button's `onPressed` and `sale.status`'s
  possible values.**

- [ ] **Step 2: Hide or disable the button when `sale.status == 'REFUNDED'`**
  (match SPEC.md's exact confirmed status string) — hiding is preferable
  to a disabled-but-visible button unless the app has an established
  disabled-button visual convention elsewhere for this kind of case; check
  one or two other screens first and match whichever convention already
  exists.

- [ ] **Step 3: Add a widget test** asserting the button is absent/disabled
  for a `REFUNDED` sale and present/enabled otherwise.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/sales/transaction_detail_page.dart
  git commit -m "fix(mobile): hide Refund action on already-refunded sales (SPEC.md #11)"
  ```

---

### Task 12: Surface refund failures to the user (#12)

**Files:**
- Modify: `app/lib/presentation/pages/sales/refund_page.dart`
- Modify: `app/lib/presentation/blocs/sales/sales_history_bloc.dart` (the `_onRefundSale` handler's `catch` block, confirmed in SPEC.md's research to currently swallow errors)

- [ ] **Step 1: Read `_onRefundSale`'s `catch` block and `RefundPage`'s
  `BlocListener`.**

- [ ] **Step 2: Emit an error state/signal from the bloc on refund
  failure** instead of only resetting `isRefunding`, and have
  `RefundPage`'s listener show `AppSnackbar.error(mapErrorToUserMessage(e))`
  on it — matching the existing success-path handling already in the same
  listener.

- [ ] **Step 3: Add a bloc/widget test** asserting a failed refund produces
  a visible error and does NOT pop the screen (unlike success, which
  should still pop).

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/sales/refund_page.dart app/lib/presentation/blocs/sales/sales_history_bloc.dart
  git commit -m "fix(mobile): show an error when a refund fails instead of silently doing nothing (SPEC.md #12)"
  ```

---

### Task 13: Wire the Settings hub's 5 hardcoded fields to real data (#13)

**Files:**
- Modify: `app/lib/presentation/pages/settings/settings_page.dart`
- Reference (read-only, match existing calls): `app/lib/presentation/pages/settings/telegram_bot_settings_page.dart`, `app/lib/presentation/pages/settings/offline_mode_page.dart`, `app/lib/presentation/pages/settings/language_settings_page.dart`

This is the largest single task in the High tier — 5 independent sub-fixes
in one file. Do them as 5 sequential edits within this one task/commit
(they're too small individually to warrant separate tasks, and they all
touch the same file).

- [ ] **Step 1: Role badge.** Read how the profile's real role is already
  available (likely already loaded via `SettingsBloc`'s profile state, or
  derivable from the authenticated user object). Replace the hardcoded
  "Владелец" text with the real role, mapped to a display label the same
  way `staff_list_page.dart`/`roles_page.dart` already map role codes to
  Russian labels (reuse that mapping rather than writing a new one).

- [ ] **Step 2: Telegram-bot status.** Make the same
  `GET /telegram-bot/status` call `telegram_bot_settings_page.dart` already
  makes (reuse the datasource/repository method, don't duplicate the HTTP
  call), and show the real connected/disconnected state instead of the
  hardcoded "Подключён" bejde.

- [ ] **Step 3: Language display.** Read the saved language preference from
  `SharedPreferences` (the same key `language_settings_page.dart` already
  reads/writes) and display its real value instead of the hardcoded
  "Русский".

- [ ] **Step 4: Offline/sync status.** Make the same `GET /sync/status`
  call `offline_mode_page.dart` already makes, and reflect the real
  pending-operations count instead of the hardcoded "Синхронизировано".

- [ ] **Step 5: Subscription plan display.** `SubscriptionBloc` is already
  loaded in `initState` per SPEC.md's research — use its already-loaded
  state (plan name, expiry date) instead of the hardcoded
  "БИЗНЕС до 30.03.2026" string.

- [ ] **Step 6: Add/extend a widget test** covering at least the role and
  subscription-plan fields (the two with the clearest, easiest-to-mock
  data sources), asserting they render the mocked bloc's real values, not
  the old hardcoded strings.

- [ ] **Step 7: Run `flutter analyze`.**

- [ ] **Step 8: Commit.**
  ```
  git add app/lib/presentation/pages/settings/settings_page.dart
  git commit -m "fix(mobile): settings hub now shows real role/Telegram/language/sync/subscription status instead of hardcoded values (SPEC.md #13)"
  ```

---

## MEDIUM (single-stage review by default)

### Task 14: Make language selection actually apply on next start (#14)

**Files:**
- Modify: `app/lib/presentation/pages/settings/language_settings_page.dart`
- Modify: `app/lib/main.dart` or `app/lib/app.dart` (wherever `MaterialApp`'s `locale`/`supportedLocales` is configured — confirm exact file via `grep -rn "MaterialApp(" app/lib/`)

**Scope note (judgment call from the approved design doc):** this task
makes the *already-promised* "restart to apply" behavior real — it does
NOT implement a live, no-restart locale swap. The existing UI copy stays
as-is; it becomes true instead of false.

- [ ] **Step 1: Read `main.dart`/`app.dart`'s current `MaterialApp`
  construction** to confirm whether `locale` is hardcoded, omitted (letting
  the system locale win), or already reads from somewhere.

- [ ] **Step 2: At app startup (before `runApp`), read the saved language
  preference from `SharedPreferences`** (same key
  `language_settings_page.dart` writes) and pass it as `MaterialApp`'s
  `locale:` parameter.

- [ ] **Step 3: Confirm `AppLocalizations.supportedLocales` already
  includes `ru`/`tg`/`uz`** (it should, per this session's earlier l10n
  work) so the passed `Locale` resolves correctly.

- [ ] **Step 4: Add a test** (or, if app-startup locale selection isn't
  practically unit-testable in this codebase's test setup, a clear manual
  verification note in the commit) confirming the saved preference is read
  and applied.

- [ ] **Step 5: Run `flutter analyze`.**

- [ ] **Step 6: Commit.**
  ```
  git add app/lib/main.dart app/lib/presentation/pages/settings/language_settings_page.dart
  git commit -m "fix(mobile): saved language preference now actually applies on next app start (SPEC.md #14)"
  ```

---

### Task 15: Make "Очистить кэш" actually clear something real (#15)

**Files:**
- Modify: `app/lib/presentation/pages/settings/offline_mode_page.dart`
- Reference (read-only): `app/lib/data/datasources/local/` (product/sale/category local datasources — confirm exact files)

- [ ] **Step 1: Read `offline_mode_page.dart`'s `_clearCache` method and
  the local datasource layer** to identify which local tables are safe to
  wipe (i.e. hold only server-mirrored data with no unsynced local writes
  pending) versus which must never be touched by this button (e.g.
  anything in the sync queue itself).

- [ ] **Step 2: Extend `_clearCache` to actually clear the safe local
  tables** (likely `product`/`category` local cache — NOT `sync_queue`,
  NOT anything holding offline-queued writes not yet confirmed by the
  server), in addition to the existing timestamp reset. If, after reading
  the local datasource layer, no table turns out to be safely clearable
  without risking data loss, leave the button's behavior as-is but rename
  its label to accurately describe what it does (e.g. "Сбросить статус
  синхронизации" instead of "Очистить кэш") — do not ship a button whose
  label overpromises.

- [ ] **Step 3: Add a test** covering whichever resolution Step 2 lands on.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/settings/offline_mode_page.dart
  git commit -m "fix(mobile): clear-cache button now matches what it actually does (SPEC.md #15)"
  ```

---

### Task 16: Fix shift history always being empty (#16)

**Files:**
- Modify: `app/lib/presentation/pages/shifts/shifts_page.dart`
- Reference (read-only): `app/lib/presentation/blocs/shift/shift_bloc.dart`

- [ ] **Step 1: Read `shifts_page.dart`'s `initState`** to confirm only
  `LoadCurrentShift` is dispatched.

- [ ] **Step 2: Also dispatch `LoadShifts`** (or fold both into a single
  combined event if the bloc supports emitting one state carrying both
  current-shift and history data — check `ShiftState`'s shape first and
  do whichever requires less bloc-side change).

- [ ] **Step 3: Confirm the shift-history section renders correctly** once
  `state.shifts` is actually populated (SPEC.md's research found the UI
  code for rendering history already exists — this is purely a
  missing-dispatch bug, not a rendering bug).

- [ ] **Step 4: Add a bloc/widget test** asserting `LoadShifts` is
  dispatched on page load and history renders when present.

- [ ] **Step 5: Run `flutter analyze`.**

- [ ] **Step 6: Commit.**
  ```
  git add app/lib/presentation/pages/shifts/shifts_page.dart
  git commit -m "fix(mobile): shift history now actually loads (SPEC.md #16)"
  ```

---

### Task 17: Block negative cash amounts when closing a shift (#17)

**Files:**
- Modify: `app/lib/presentation/pages/shifts/shifts_page.dart` (the close-shift `AlertDialog`)

- [ ] **Step 1: Read the close-shift dialog's amount-parsing logic.**

- [ ] **Step 2: Add a `>= 0` check** matching the one already used on
  `open_shift_page.dart`'s amount field — show an inline error (or keep
  the dialog open with a visible message) instead of the current silent
  no-op on invalid/negative input.

- [ ] **Step 3: Add a test** asserting a negative amount does not close
  the shift.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/shifts/shifts_page.dart
  git commit -m "fix(mobile): block negative cash amounts when closing a shift (SPEC.md #17)"
  ```

---

### Task 18: Make "Поделиться расчётом" (zakat) actually share (#18)

**Files:**
- Modify: `app/lib/presentation/pages/zakat/zakat_calculator_page.dart`

- [ ] **Step 1: Read the current `Clipboard.setData` call and find an
  existing `Share.share(...)` usage elsewhere in the app** (e.g. the
  sale-success screen's Telegram/WhatsApp/SMS sheet) for the exact import
  and call convention already in use.

- [ ] **Step 2: Replace `Clipboard.setData` with `Share.share(...)`**,
  keeping the same summary text currently being copied. Update the
  post-action snackbar text/key if "Расчёт скопирован" no longer matches
  what happened (check `app_ru.arb` for whether a more accurate existing
  key, like a generic "поделились"-style message, already exists before
  minting a new one).

- [ ] **Step 3: Run `flutter analyze`.**

- [ ] **Step 4: Commit.**
  ```
  git add app/lib/presentation/pages/zakat/zakat_calculator_page.dart
  git commit -m "fix(mobile): zakat share button now opens the real share sheet (SPEC.md #18)"
  ```

---

### Task 19: Persist the two dropped zakat-settings toggles (#19)

**Files:**
- Modify: `app/lib/presentation/pages/zakat/zakat_settings_page.dart`

- [ ] **Step 1: Read `_save`'s payload construction.**

- [ ] **Step 2: Include `_reminderEnabled` and `_includeSupplierDebts`
  in the `ZakatSettingsUpdated` data map**, using whatever field names the
  backend/bloc already expects for them (check `ZakatSettingsUpdated`'s
  event definition and, if needed, how the loaded settings response maps
  these two fields back in on load — the load side may already read these
  fields even though save never sent them, which would confirm the field
  names to use).

- [ ] **Step 3: Add a test** asserting both toggles appear in the saved
  payload.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/zakat/zakat_settings_page.dart
  git commit -m "fix(mobile): zakat reminder and supplier-debt-deduction toggles now actually save (SPEC.md #19)"
  ```

---

### Task 20: Implement real filtering for the customer-list chips (#20)

**Files:**
- Modify: `app/lib/presentation/pages/customer/customer_list_page.dart`

- [ ] **Step 1: Read the four filter chips' current no-op `setState`
  handlers and the `Customer` entity's available fields.**

- [ ] **Step 2: Implement client-side filtering** against the already-loaded
  list: "С долгом" → `debt > 0`; "VIP" → the same heuristic already used
  for the VIP badge (`loyaltyPoints > 1000 || totalSpent > 50000`, per
  SPEC.md's research); "Новые" → `createdAt` within some recency window
  (check whether the backend/entity already has a concept of "new" — if
  not, define a reasonable window, e.g. last 30 days, and note the choice
  in the commit message); "Все" → no filter.

- [ ] **Step 3: Add a widget test** asserting each chip actually changes
  the rendered list to the expected subset.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/customer/customer_list_page.dart
  git commit -m "fix(mobile): customer-list filter chips now actually filter (SPEC.md #20)"
  ```

---

### Task 21: Route quick-create dialog errors through the shared error mapper (#21)

**Files:**
- Modify: `app/lib/presentation/pages/customer/customer_list_page.dart`
- Modify: `app/lib/presentation/pages/supplier/supplier_list_page.dart`

- [ ] **Step 1: Read both quick-create dialogs' `catch` blocks.**

- [ ] **Step 2: Replace `'Ошибка: $e'` with `mapErrorToUserMessage(e)`**
  in both files' `SnackBar`/`AppSnackbar` calls.

- [ ] **Step 3: Run `flutter analyze`.**

- [ ] **Step 4: Commit.**
  ```
  git add app/lib/presentation/pages/customer/customer_list_page.dart app/lib/presentation/pages/supplier/supplier_list_page.dart
  git commit -m "fix(mobile): quick-create dialogs show a proper error message instead of a raw exception (SPEC.md #21)"
  ```

---

### Task 22: Add a supplier-edit screen (#22)

**Files:**
- Modify: `app/lib/presentation/pages/supplier/supplier_detail_page.dart`
- Reference (read-only, match the shape): `app/lib/presentation/pages/customer/customer_form_page.dart`
- Create or modify: a supplier form page — check first whether one already exists but is simply unreachable (`find app/lib -iname "*supplier_form*"`); if none exists, create `app/lib/presentation/pages/supplier/supplier_form_page.dart` mirroring `customer_form_page.dart`'s structure (name/phone/address/notes fields, create-vs-edit branch)
- Modify: `app/lib/core/router/app_router.dart` (register the new route if one is created)

- [ ] **Step 1: Confirm no supplier-form page already exists** unreachable
  in the codebase (SPEC.md's research found none, but re-verify).

- [ ] **Step 2: Create `supplier_form_page.dart`**, mirroring
  `customer_form_page.dart`'s structure and the existing
  `SupplierListBloc`'s create/update events (check whether
  `updateSupplier` already exists on the repository — SPEC.md's research
  implies suppliers only ever go through quick-create, so this may need a
  new bloc event if `updateSupplier` isn't already wired to anything;
  check the repository interface first since the backend method itself is
  confirmed to already exist per this plan's scope note).

- [ ] **Step 3: Add an "Изменить" action to `supplier_detail_page.dart`**,
  matching `customer_detail_page.dart`'s equivalent button, pushing the
  new form pre-filled with the current supplier.

- [ ] **Step 4: Register the route** in `app_router.dart` if not already
  present.

- [ ] **Step 5: Add a widget test** for the new form's create and edit
  modes.

- [ ] **Step 6: Run `flutter analyze`.**

- [ ] **Step 7: Commit.**
  ```
  git add app/lib/presentation/pages/supplier/ app/lib/core/router/app_router.dart
  git commit -m "fix(mobile): add a real supplier-edit screen (SPEC.md #22)"
  ```

---

### Task 23: Show inline validation on debt-payment forms instead of a silent no-op (#23)

**Files:**
- Modify: whichever file defines the shared `PaymentForm` widget used by both `customer_debts_page.dart` and `supplier_debts_page.dart` (confirm via `grep -rn "class PaymentForm" app/lib/`)

- [ ] **Step 1: Read `PaymentForm`'s submit handler and amount validation.**

- [ ] **Step 2: Add an inline error** (e.g. under the amount field) when
  the entered amount is `<= 0` or `> maxAmount`, instead of the current
  silent no-op on the submit button.

- [ ] **Step 3: Add a widget test** asserting an invalid amount shows the
  error and does not call the submit callback.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add <payment form file>
  git commit -m "fix(mobile): debt-payment forms now show a validation error instead of silently doing nothing (SPEC.md #23)"
  ```

---

### Task 24: Make stock-intake respect the product passed via `extra` (#24)

**Files:**
- Modify: `app/lib/presentation/pages/stock/stock_intake_page.dart`

- [ ] **Step 1: Read `StockIntakePage`'s constructor and confirm it
  currently ignores `GoRouterState.extra`.**

- [ ] **Step 2: Add an optional `product` parameter to the constructor**,
  read it from `extra` at the router-registration call site in
  `app_router.dart` (matching how other pages already read `extra`), and
  in `initState`, if a product was passed, dispatch
  `StockIntakeSelectProduct(product)` immediately, skipping the search
  step.

- [ ] **Step 3: Add a widget test** asserting a passed-in product
  pre-selects the intake form.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/stock/stock_intake_page.dart app/lib/core/router/app_router.dart
  git commit -m "fix(mobile): stock intake now respects the product passed from the product-detail screen (SPEC.md #24)"
  ```

---

### Task 25: Implement real photo upload on the add-product flow (#25)

**Files:**
- Modify: `app/lib/presentation/pages/product/add_product_step1_page.dart`
- Modify: `app/lib/presentation/pages/product/add_product_step3_page.dart`
- Modify: `app/lib/presentation/blocs/product_form/product_form_bloc.dart`
- Reference (read-only, match the multipart-upload shape): `app/lib/presentation/pages/settings/subscription_page.dart` (receipt upload)

- [ ] **Step 1: Read `subscription_page.dart`'s receipt-upload flow in
  full** to confirm the exact multipart-upload pattern already established
  in this codebase (which repository method, what the request shape is).

- [ ] **Step 2: Confirm whether a product-image-upload endpoint/repository
  method already exists** (check `ProductRepository`/`ProductRemoteDatasource`
  for something like `uploadProductImage`). If one exists, wire step 1's
  picked image into it. If genuinely none exists, this task is
  larger than its Medium-priority sizing implies — flag this explicitly to
  the plan owner instead of inventing a new backend contract; do not
  guess at an endpoint shape.

- [ ] **Step 3 (only if Step 2 confirms an existing endpoint): implement
  the upload** — call it once the image is picked (either eagerly on
  pick, or deferred until final submit, matching whichever pattern
  `subscription_page.dart` uses), and include the resulting image
  URL/ID in the product payload sent by `ProductFormSubmit`.

- [ ] **Step 4: Add a test** covering the picked-image-to-payload path.

- [ ] **Step 5: Run `flutter analyze`.**

- [ ] **Step 6: Commit.**
  ```
  git add app/lib/presentation/pages/product/add_product_step1_page.dart app/lib/presentation/pages/product/add_product_step3_page.dart app/lib/presentation/blocs/product_form/product_form_bloc.dart
  git commit -m "fix(mobile): product photo picker now actually uploads and attaches the image (SPEC.md #25)"
  ```

---

### Task 26: Fix EmptyProductsPage passing an empty storeId to import (#26)

**Files:**
- Modify: `app/lib/presentation/pages/product/empty_products_page.dart`

- [ ] **Step 1: Read the current "Импорт из Excel" button's navigation
  call.**

- [ ] **Step 2: Read `storeId` from `StoreBloc`** (matching how
  `product_list_page.dart`'s equivalent button already does it) instead of
  omitting `extra` entirely.

- [ ] **Step 3: Run `flutter analyze`.**

- [ ] **Step 4: Commit.**
  ```
  git add app/lib/presentation/pages/product/empty_products_page.dart
  git commit -m "fix(mobile): empty-products import button now passes the real storeId (SPEC.md #26)"
  ```

---

### Task 27: Handle the `ImportError` state on the import-products screen (#27)

**Files:**
- Modify: `app/lib/presentation/pages/product/import_products_page.dart`

- [ ] **Step 1: Read the `build` method's state-switch/builder.**

- [ ] **Step 2: Add an `ImportError` branch** that renders an error view
  (matching the shape of `_InitialView`/`_PreviewView` but with the error
  message and a retry action), instead of falling through to
  `_InitialView` by default.

- [ ] **Step 3: Add a widget test** asserting `ImportError` renders visible
  error content.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/product/import_products_page.dart
  git commit -m "fix(mobile): import-products screen now shows import errors instead of reverting to the initial view (SPEC.md #27)"
  ```

---

### Task 28: Fix the operator-precedence bug in delivery-detail total parsing (#28)

**Files:**
- Modify: `app/lib/presentation/pages/delivery/delivery_detail_page.dart`

- [ ] **Step 1: Locate the exact line**: `total: (j['amount'] ?? j['total'] as num?)?.toDouble() ?? 0`.

- [ ] **Step 2: Fix the parenthesization**: `total: ((j['amount'] ?? j['total']) as num?)?.toDouble() ?? 0`.

- [ ] **Step 3: Add a unit test** for the parsing function/model
  constructor with a fixture JSON that has `total` but no `amount`,
  asserting it parses without throwing and produces the expected value.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/delivery/delivery_detail_page.dart
  git commit -m "fix(mobile): fix operator-precedence bug that could throw when a delivery has no amount field (SPEC.md #28)"
  ```

---

### Task 29: Localize `create_delivery_page.dart` (#29)

**Files:**
- Modify: `app/lib/presentation/pages/delivery/create_delivery_page.dart`
- Modify: `app/lib/l10n/app_ru.arb`

Follow `.claude/rules/mobile-l10n.md` and the exact 10-step extraction
procedure this session already used successfully across 34 other files in
the earlier l10n migration plan (`docs/superpowers/plans/2026-08-12-l10n-and-retry-after.md`,
"L10n extraction — process specification" section) — reuse that procedure
verbatim rather than reinventing it here.

- [ ] **Step 1: Read the file, identify every hardcoded Russian string
  literal.**

- [ ] **Step 2: Check `app_ru.arb` for existing equivalent keys** before
  minting new ones (this screen sits alongside the already-migrated
  `delivery_list_page.dart`/`delivery_detail_page.dart`, which likely
  already have several directly reusable keys — e.g. "Заказ", "Адрес",
  "Курьер", "Примечания", generic `save`-style keys).

- [ ] **Step 3: Add any genuinely new keys to `app_ru.arb`, run
  `flutter gen-l10n`, replace the literals with `AppLocalizations` calls.**

- [ ] **Step 4: Run `flutter analyze` and any existing test for this
  file.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/delivery/create_delivery_page.dart app/lib/l10n/app_ru.arb app/lib/l10n/app_localizations*.dart app/l10n_untranslated.json
  git commit -m "fix(mobile): localize create-delivery page (SPEC.md #29)"
  ```

---

### Task 30: Refresh the delivery list after creating a new delivery (#30)

**Files:**
- Modify: `app/lib/presentation/pages/delivery/create_delivery_page.dart`
- Modify: `app/lib/presentation/pages/delivery/delivery_list_page.dart`

- [ ] **Step 1: Read `create_delivery_page.dart`'s success handling** (does
  it currently `pop()` with no result, or `pop(true)`?).

- [ ] **Step 2: Have it `pop(true)` on success**, and have
  `delivery_list_page.dart`'s FAB navigation `await` the push result and
  reload the list when it's `true` — matching the pattern already used in
  `add_investment_page.dart`/`investment_list_page.dart` for the same
  problem.

- [ ] **Step 3: Add a widget test** asserting the list reloads after a
  successful creation.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/delivery/create_delivery_page.dart app/lib/presentation/pages/delivery/delivery_list_page.dart
  git commit -m "fix(mobile): delivery list now refreshes after creating a new delivery (SPEC.md #30)"
  ```

---

### Task 31: Add confirmation dialogs before deleting an expense or a discount (#31)

**Files:**
- Modify: `app/lib/presentation/pages/finance/expense_list_page.dart`
- Modify: `app/lib/presentation/pages/settings/discounts_page.dart`

- [ ] **Step 1: Read both files' current delete handlers.**

- [ ] **Step 2: Add an `AlertDialog` confirmation** before dispatching the
  delete event in both files, matching the exact shape already used for
  category/product deletion (title, body, "Отмена"/destructive-action
  button pair) — reuse the same wording style, do not invent a new
  confirmation-dialog convention.

- [ ] **Step 3: Add widget tests** for both, asserting the delete event is
  NOT dispatched until the dialog's destructive button is tapped, and IS
  dispatched after.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/finance/expense_list_page.dart app/lib/presentation/pages/settings/discounts_page.dart
  git commit -m "fix(mobile): confirm before deleting an expense or a discount (SPEC.md #31)"
  ```

---

### Task 32: Surface expense-deletion errors (#32)

**Files:**
- Modify: `app/lib/presentation/pages/finance/expense_list_page.dart`
- Modify: `app/lib/presentation/blocs/finance/expense_bloc.dart` (confirm exact path)

**Note:** touches the same page file as Task 31 — do this task
immediately after Task 31 (or combine into the same commit if that reads
more naturally once both are in hand; keep them as separately described
tasks here since they're independently reviewable, but an implementer
doing both back-to-back on the same file is expected and fine).

- [ ] **Step 1: Read `ExpenseDeleteRequested`'s failure path.**

- [ ] **Step 2: Emit an error state on failure** and add error handling
  to the page's `BlocListener`/`BlocConsumer`, showing
  `AppSnackbar.error(mapErrorToUserMessage(e))`.

- [ ] **Step 3: Add a bloc test** asserting a failed delete produces a
  visible error and does not silently drop the item from the list state
  it shouldn't have been removed from.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/finance/expense_list_page.dart app/lib/presentation/blocs/finance/expense_bloc.dart
  git commit -m "fix(mobile): show an error when expense deletion fails (SPEC.md #32)"
  ```

---

### Task 33: Route report-export errors through the shared error mapper (#33)

**Files:**
- Modify: `app/lib/presentation/pages/finance/reports_page.dart`

- [ ] **Step 1: Locate the server-export error handler** (`'Ошибка
  экспорта: {e}'`, per SPEC.md's research — the one place in this file
  that bypasses `mapErrorToUserMessage`).

- [ ] **Step 2: Replace it with the same `mapErrorToUserMessage`+
  `AppSnackbar.error` pattern used everywhere else in this file.**

- [ ] **Step 3: Run `flutter analyze`.**

- [ ] **Step 4: Commit.**
  ```
  git add app/lib/presentation/pages/finance/reports_page.dart
  git commit -m "fix(mobile): report-export errors now use the shared error-message mapper (SPEC.md #33)"
  ```

---

### Task 34: Fix the hardcoded notification-load error text (#34)

**Files:**
- Modify: `app/lib/presentation/pages/notifications/notifications_page.dart`

- [ ] **Step 1: Locate the hardcoded `'Не удалось загрузить уведомления'`
  literal.**

- [ ] **Step 2: Replace it with `mapErrorToUserMessage(e)`**, and route the
  string through `AppLocalizations` if the surrounding code already does
  so for other strings on this page (check for an existing convention on
  this specific file first, since SPEC.md's research flagged this file as
  one of the ones bypassing the app's normal architecture — confirm
  whether `AppLocalizations` is even imported here yet).

- [ ] **Step 3: Run `flutter analyze`.**

- [ ] **Step 4: Commit.**
  ```
  git add app/lib/presentation/pages/notifications/notifications_page.dart
  git commit -m "fix(mobile): notification-load error now uses the shared mapper instead of a hardcoded string (SPEC.md #34)"
  ```

---

### Task 35: Surface notification-settings load errors (#35)

**Files:**
- Modify: `app/lib/presentation/pages/notifications/notification_settings_page.dart`

- [ ] **Step 1: Read the `catch (_) {}` block around the settings-load
  call.**

- [ ] **Step 2: Show an error** (snackbar, matching the pattern used
  elsewhere in this same file for the save-error path) instead of silently
  falling back to default values with no indication anything went wrong.

- [ ] **Step 3: Run `flutter analyze`.**

- [ ] **Step 4: Commit.**
  ```
  git add app/lib/presentation/pages/notifications/notification_settings_page.dart
  git commit -m "fix(mobile): notification-settings load errors are no longer silently hidden (SPEC.md #35)"
  ```

---

### Task 36: Validate numeric threshold fields instead of silently defaulting (#36)

**Files:**
- Modify: `app/lib/presentation/pages/notifications/notification_settings_page.dart`
- Modify: `app/lib/presentation/pages/settings/loyalty_settings_page.dart`

- [ ] **Step 1: Read both files' numeric-field parsing** (`int.tryParse`/
  `double.tryParse` with a silent `?? default` fallback, per SPEC.md's
  research).

- [ ] **Step 2: Add inline validation** (wrap the relevant fields in a
  `Form`/`TextFormField` with a `validator` if not already using `Form`,
  or add a manual check before save that blocks submission and shows an
  error if parsing fails) — do not silently substitute a default value the
  user never chose.

- [ ] **Step 3: Add widget tests** for both files asserting invalid input
  blocks save with a visible error.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/notifications/notification_settings_page.dart app/lib/presentation/pages/settings/loyalty_settings_page.dart
  git commit -m "fix(mobile): numeric threshold fields now validate instead of silently defaulting (SPEC.md #36)"
  ```

---

### Task 37: Persist the KKM "auto-print" toggle (#37)

**Files:**
- Modify: `app/lib/presentation/pages/settings/kkm_settings_page.dart`
- Reference (read-only, match the shape): `app/lib/presentation/pages/settings/scanner_settings_page.dart`

- [ ] **Step 1: Read `scanner_settings_page.dart`'s `SharedPreferences`
  read/write pattern for its own toggles.**

- [ ] **Step 2: Apply the same pattern to `kkm_settings_page.dart`'s
  "Автопечать при продаже" toggle** — read the saved value in `initState`,
  write it on change (or on an explicit save action if this screen already
  has one for other fields — match whatever's already established on this
  specific page).

- [ ] **Step 3: Run `flutter analyze`.**

- [ ] **Step 4: Commit.**
  ```
  git add app/lib/presentation/pages/settings/kkm_settings_page.dart
  git commit -m "fix(mobile): KKM auto-print toggle now actually persists (SPEC.md #37)"
  ```

---

### Task 38: Fix the zakat gold-price refresh button (#38)

**Files:**
- Modify: `app/lib/presentation/pages/zakat/zakat_settings_page.dart`

- [ ] **Step 1: Read the `!_initialized` guard** that currently blocks
  re-applying fetched settings to the form fields.

- [ ] **Step 2: Fix it** — either remove the guard specifically for the
  refresh-button-triggered reload path (keep it for the initial-load path
  if it's serving some other legitimate purpose there, e.g. avoiding
  clobbering in-progress user edits on first load), or explicitly reset
  the gold-price/related controllers directly in the refresh button's
  `onPressed` instead of relying on the general `ZakatSettingsLoaded`
  listener.

- [ ] **Step 3: Add a widget test** asserting the refresh button updates
  the visible field value.

- [ ] **Step 4: Run `flutter analyze`.**

- [ ] **Step 5: Commit.**
  ```
  git add app/lib/presentation/pages/zakat/zakat_settings_page.dart
  git commit -m "fix(mobile): gold-price refresh button now actually updates the form (SPEC.md #38)"
  ```

---

### Task 39: Remove dead/unreachable routes (#39)

**Files:**
- Modify: `app/lib/core/router/app_router.dart`
- Modify: `app/lib/core/router/route_names.dart`
- Delete: `app/lib/presentation/pages/sales/empty_sales_page.dart` (confirm still genuinely unreachable first)
- Delete or fix: `app/lib/presentation/pages/product/empty_products_page.dart` (confirm whether this one is genuinely dead too, or reachable via some path SPEC.md's research didn't find — re-verify with a fresh `grep -rn "empty_products\|/products/empty"` before deleting)

- [ ] **Step 1: Re-verify each of `/sales/empty`, `/products/empty`, `/pos`
  is genuinely never navigated to anywhere in the app** — `grep -rn`
  every literal path string and every `RouteNames.*` constant that maps to
  them, across all of `app/lib/`. Do not delete anything this grep finds
  a real caller for.

- [ ] **Step 2: For each confirmed-dead route**, remove its `GoRoute`
  registration from `app_router.dart`, its constant from `route_names.dart`,
  and (for `/sales/empty` specifically, confirmed dead) delete
  `empty_sales_page.dart` entirely since nothing else references it.

- [ ] **Step 3: For `/pos`**, since `RouteNames.pos` is a genuinely unused
  dead constant (POS is only ever reached via the bottom-nav tab, never
  via `context.go(RouteNames.pos)`), remove the constant too.

- [ ] **Step 4: Run `flutter analyze` across the whole `app/lib/` tree**
  (not just touched files) to catch any now-broken reference this cleanup
  might have missed.

- [ ] **Step 5: Run the full existing test suite** (`flutter test`) to
  confirm nothing depended on the removed routes/files.

- [ ] **Step 6: Commit.**
  ```
  git add app/lib/core/router/app_router.dart app/lib/core/router/route_names.dart
  git rm app/lib/presentation/pages/sales/empty_sales_page.dart
  git commit -m "fix(mobile): remove dead/unreachable routes and the page they never rendered (SPEC.md #39)"
  ```

---

### Task 40: Wire the dashboard's custom date-range picker into the query (#40)

**Files:**
- Modify: `app/lib/presentation/pages/dashboard/dashboard_page.dart`
- Modify: `app/lib/presentation/blocs/dashboard/dashboard_event.dart` (add date fields to `DashboardPeriodChanged` if not present)
- Modify: `app/lib/presentation/blocs/dashboard/dashboard_bloc.dart`

- [ ] **Step 1: Read the calendar icon's `showDateRangePicker` handler and
  `DashboardPeriodChanged`'s current fields.**

- [ ] **Step 2: Add `startDate`/`endDate` fields to the event** and have
  the bloc apply them when `period == 'custom'`, instead of ignoring them.

- [ ] **Step 3: Thread the picker's selected range into the event
  dispatch.**

- [ ] **Step 4: Add a bloc test** asserting a custom range produces a
  request carrying those exact dates.

- [ ] **Step 5: Run `flutter analyze`.**

- [ ] **Step 6: Commit.**
  ```
  git add app/lib/presentation/pages/dashboard/dashboard_page.dart app/lib/presentation/blocs/dashboard/dashboard_event.dart app/lib/presentation/blocs/dashboard/dashboard_bloc.dart
  git commit -m "fix(mobile): dashboard custom date-range picker now actually filters (SPEC.md #40)"
  ```

---

### Task 41: Surface dashboard pull-to-refresh errors (#41)

**Files:**
- Modify: `app/lib/presentation/pages/dashboard/dashboard_page.dart`
- Modify: `app/lib/presentation/blocs/dashboard/dashboard_bloc.dart`

- [ ] **Step 1: Read `DashboardRefreshRequested`'s error handling** —
  SPEC.md's research found that when refresh fails after an initial
  successful load, the error is swallowed and the state stays unchanged
  with no signal to the user.

- [ ] **Step 2: Emit a distinguishable error signal on refresh failure**
  (without discarding the still-good `DashboardLoaded` data underneath
  it — e.g. a transient error flag/event the page's listener can react to
  with a snackbar, rather than replacing the whole state with
  `DashboardError` and losing the already-rendered stats).

- [ ] **Step 3: Show `AppSnackbar.error(mapErrorToUserMessage(e))`** in the
  page on that signal.

- [ ] **Step 4: Add a bloc test** asserting a failed refresh after a
  successful load produces a visible error while keeping the prior stats
  in state.

- [ ] **Step 5: Run `flutter analyze`.**

- [ ] **Step 6: Commit.**
  ```
  git add app/lib/presentation/pages/dashboard/dashboard_page.dart app/lib/presentation/blocs/dashboard/dashboard_bloc.dart
  git commit -m "fix(mobile): dashboard pull-to-refresh now shows an error instead of failing silently (SPEC.md #41)"
  ```

---

## Task 42: Live-QA re-verification of the 4 Critical fixes

**Files:**
- Modify: `app/integration_test/live_qa_verification_test.dart`

Per the approved design doc's testing section — extend the existing
live-QA test (which already live-confirmed finding #4's *bug*) to now
confirm the *fix* for #4, plus add coverage for #1 and #2 (the two
Criticals most amenable to a quick live check). #3 is not covered here —
verifying it live requires driving a real SMS/OTP round trip against the
seeded QA phone number, which is a bigger environment-setup lift than this
task's scope; #3's unit/widget test coverage from Task 3 is the
verification bar for this plan.

- [ ] **Step 1: Update STEP 3's assertion** (roles-permission persistence
  probe) — it currently prints a "SPEC FINDING CONFIRMED LIVE" message when
  the toggle reverts. After Task 4's fix, the test should instead assert
  the toggle now DOES persist across navigate-away-and-back, and fail loudly
  if it doesn't (turn the informational `debugPrint` branch into a real
  `expect(...)`).

- [ ] **Step 2: Add a new probe for finding #1** (product edit no longer
  duplicates): after the existing steps, navigate to Products, note the
  current product count, add a test product, edit it (change the name),
  save, and assert the product count increased by exactly 1 (not 2).

- [ ] **Step 3: Add a new probe for finding #2** (cart clears after sale):
  add a product to the cart, complete a cash checkout, tap "Новая
  продажа", return to the POS tab, and assert the cart is empty.

- [ ] **Step 4: Run the extended test against a real emulator + dev API**
  (same setup as the original live QA session: `docker compose up -d` in
  `api/`, `npm run start:dev`, `flutter emulators --launch duckon`, build+
  install+grant-permission, `flutter test integration_test/live_qa_verification_test.dart
  -d <emulator-id> --dart-define=API_BASE_URL=http://10.0.2.2:4455/api`).
  Iterate on any widget-finding issues the same way the original session
  did (scroll-into-view, real in-app navigation paths, etc.) — expect this
  to take a few iterations, budget for it.

- [ ] **Step 5: Commit** once the extended test passes cleanly.
  ```
  git add app/integration_test/live_qa_verification_test.dart
  git commit -m "test(mobile): extend live QA test to confirm the 4 Critical fixes (SPEC.md #1, #2, #4)"
  ```

---

## Task 43: Update SPEC.md's discrepancy list

**Files:**
- Modify: `qa/2026-08-25-mobile-functional-spec/SPEC.md`

- [ ] **Step 1: Go through every one of the 41 numbered items in "Сводный
  список найденных расхождений."** For each, add a short strikethrough or
  a trailing "✅ Исправлено в `<commit-sha>`" note (pick whichever
  formatting keeps the document most readable — check how similar
  before/after tracking is done elsewhere in this project's `qa/`
  directory, if any precedent exists, otherwise use a simple bold
  "**[ИСПРАВЛЕНО]**" prefix per line).

- [ ] **Step 2: If any finding turned out, during implementation, to be a
  false positive or to need a different fix than originally described**
  (e.g. #14's scope was narrowed per this plan's judgment call, #15 or
  #25 might have resolved differently than first assumed depending on
  what Steps 2 of their respective tasks found), note that explicitly next
  to the item — do not silently mark it "fixed" if the actual resolution
  diverged from the original finding's description.

- [ ] **Step 3: Commit.**
  ```
  git add qa/2026-08-25-mobile-functional-spec/SPEC.md
  git commit -m "docs(qa): mark all 41 SPEC.md discrepancies as resolved"
  ```

---

## After all tasks: final review and merge

Once Tasks 1–43 are complete, dispatch a final whole-branch code reviewer
(matching this session's standing practice for every prior branch), then
invoke `superpowers:finishing-a-development-branch` and present the
standard 4 options (merge locally / push+PR / keep / discard) — do not
assume which one the user wants even though they've chosen "merge locally"
every time so far this session.
