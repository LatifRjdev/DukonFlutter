# Sprint 5B.2.c — Live Regions (SemanticsService.announce) Implementation Plan

> **For agentic workers:** Use `subagent-driven-development` skill for Phase 2 (per-cluster migration). Phase 1 is a single controller-edit.

**Goal:** Make dynamic toasts/snackbars audible for screen-reader users via `SemanticsService.announce()`. SnackBar on its own does NOT steal focus, so TalkBack/VoiceOver skip transient messages unless explicitly announced.

**Architecture:** Two-phase approach.

- **Phase 1** (controller-inline, trivial) — add a single `SemanticsService.announce(message, TextDirection.ltr)` call to the two centralized helpers (`AppSnackbar._show`, `ContextExtensions.showSnackBar`). This covers ~0 present call-sites (AppSnackbar is currently unused outside itself) + 2 `extensions.dart` sites, but it sets up the announcement contract for Phase 2 migration.
- **Phase 2** (per-cluster, subagent-driven) — migrate 91 inline `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), ...))` call-sites across 50 files to `AppSnackbar.success(context, msg)` / `AppSnackbar.error(...)` / `AppSnackbar.info(...)`. This is a DRY cleanup AND a11y win in one pass.

**Tech Stack:** `SemanticsService` from `package:flutter/semantics.dart`, existing `AppSnackbar`.

---

## Audit (2026-04-22)

- `AppSnackbar.success/error/info` — defined in `lib/presentation/widgets/common/app_snackbar.dart`. Currently 0 usage outside own file.
- `ContextExtensions.showSnackBar(msg, {isError})` — defined in `lib/core/utils/extensions.dart`. 2 usages.
- Inline `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` — **91 occurrences across 50 files**.

Cluster breakdown (same split as 5B.2.b for continuity):

| Cluster | Files | Inline sites |
|---|---|---|
| Auth (login, register, otp, forgot_password, create_password) | 5 | ~6 |
| POS (pos_checkout, cash_payment, credit_sale, sale_success, receipt_preview) | 5 | ~11 |
| Product CRUD (add_product_step3, product_detail, import_products) | 3 | ~4 |
| Settings (13 pages) | 13 | ~27 |
| Finance (add_expense, add_investment, investment_list) | 3 | ~6 |
| CRM (customer_form, customer_detail, customer_list, supplier_list) | 4 | ~5 |
| Shifts/Sales (open_shift, shifts_page, refund) | 3 | ~6 |
| Staff/Payroll (add_staff, payroll, add_adjustment) | 3 | ~5 |
| Zakat/Debt/Delivery/Misc (zakat_calculator, zakat_settings, customer_debts, supplier_debts, create_delivery, inventory_count, stock_intake, store, notifications_settings) | 11 | ~21 |

Total: 91 inline sites across 9 logical clusters.

---

## Phase 1 — Announce in centralized helpers

### Step 1: Edit `AppSnackbar._show`

Add import:
```dart
import 'package:flutter/semantics.dart';
```

At end of `_show`, after `messenger.showSnackBar(...)`:
```dart
SemanticsService.announce(message, Directionality.of(context));
```

### Step 2: Edit `ContextExtensions.showSnackBar`

Same: add import + `SemanticsService.announce(message, Directionality.of(this));` after the `ScaffoldMessenger.showSnackBar` call.

### Step 3: Commit

```
feat(a11y): announce snackbar messages via SemanticsService for screen readers

AppSnackbar._show and ContextExtensions.showSnackBar now call
SemanticsService.announce() after displaying a SnackBar so that
TalkBack/VoiceOver read out the message. SnackBar alone does not steal
focus, so transient messages were silent for screen-reader users.

Phase 1 of Sprint 5B.2.c (live regions). Phase 2 will migrate the 91
inline ScaffoldMessenger call-sites to use these centralized helpers.
```

---

## Phase 2 — Per-cluster migration

One subagent per cluster. Each subagent:

1. Opens each file in the cluster.
2. For each `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('X'), ...))`:
   - Replace with `AppSnackbar.success(context, 'X')` for success-like messages, `AppSnackbar.error(context, 'X')` for error-like (check `backgroundColor: AppColors.error` or message text for "ошибка"/"неверн"/"не удалось"), `AppSnackbar.info(context, 'X')` otherwise.
   - If the inline SnackBar has a custom `action:` (e.g. "Повторить"), **DO NOT migrate** — leave inline and add one line `SemanticsService.announce(msg, Directionality.of(context));` directly before `showSnackBar`. Leave a `// TODO(a11y): migrate when AppSnackbar supports actions` comment.
   - Remove unused `SnackBar` / `AppColors` imports if no longer referenced.
3. Add `import '<relative>/widgets/common/app_snackbar.dart';` if any AppSnackbar.* added.
4. `flutter analyze <cluster-dir>` → 0 issues.
5. Commit per cluster: `refactor(a11y): migrate <cluster> snackbars to AppSnackbar`.

Clusters per task (~6 commits for Phase 2):

- Task 2.1 — Auth (5 files)
- Task 2.2 — POS (5 files)
- Task 2.3 — Product + Settings-core (16 files)
- Task 2.4 — Finance + CRM (7 files)
- Task 2.5 — Shifts/Sales + Staff/Payroll (6 files)
- Task 2.6 — Zakat/Debt/Delivery/Misc (11 files)

---

## Phase 3 — Wrap-up

1. `flutter analyze lib/` → 0 issues.
2. `flutter test` → unchanged baseline (351 pass + 12 pre-existing Impeller golden drift).
3. Update this plan with completion block.
4. Final commit `docs(sprint-5b-2c): mark complete`.

---

## Execution notes

- **Directionality:** always use `Directionality.of(context)` (not a hard-coded `TextDirection.ltr`) so RTL locales (e.g. Arabic) would work if added later.
- **Duplicate announce:** announcing BOTH on showSnackBar AND from the call-site creates duplicate speech. Only announce once — at the central helper level.
- **Migration scope of `AppSnackbar`:** the helper currently has 3 variants (success/error/info). Do NOT add action-supporting variants in this sprint — action-bearing snackbars (~5 sites with "Повторить"/"Отменить" actions) stay inline with a manual `SemanticsService.announce` one-liner.
- **Imports:** removing `showSnackBar` / `SnackBar` usage often frees a `material.dart` import — leave material.dart alone (it's required for almost everything). Only remove `AppColors` import if it was only used for snackbar background color.
- **Tests:** unit tests rarely assert on SnackBar content, so migration is unlikely to break tests. Golden tests do not render SnackBars.
- **Commit hygiene:** Phase 2 commits are `refactor(a11y)` — no visual diff; Phase 1 commit is `feat(a11y)` — new behavior.
