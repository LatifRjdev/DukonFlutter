# ADR-0002 Track 2 — Remaining i18n Migration Design

## Context

`docs/adr/0002-i18n-rollout-plan.md` (Track 2) calls for migrating all remaining
hardcoded Cyrillic string literals in `app/lib/presentation/` to
`AppLocalizations`, in batches. A prior branch (`feat/i18n-nine-file-migration`,
merged) already migrated 9 files (~165 strings) and fixed the `check_i18n.dart`
lint tool's allow-list to key by `file::content` instead of `file:line`. This
project picks up the rest of Track 2.

As of this design, `app/tool/i18n-allowlist.txt` (the grandfathered-offenders
list `check_i18n.dart` enforces against) contains **797 entries across 68
files**. Of those:

- 6 entries are the deliberate, already-decided proper-noun exceptions in
  `settings_page.dart` (language names, tariff brand names) — that file is
  **fully done**, not part of this project's scope.
- 6 files (`printer_bloc.dart`, `expense_bloc.dart`, `zakat_bloc.dart`,
  `settings_bloc.dart`, `subscription_bloc.dart`, `debt_bloc.dart`, ~19 strings
  total) store raw Russian strings directly in Bloc state
  (`state.error`/`state.successMessage`) — Blocs have no `BuildContext`, so
  `AppLocalizations.of(context)` cannot be called there. This is exactly the
  ADR's separately-designated **"Track 3 — the error-message layer"**, which
  needs its own mechanism (e.g., Blocs emitting an error code/enum that the UI
  layer — which does have `BuildContext` — maps to a localized string via
  `AppLocalizations`). That is a different kind of problem than literal
  replacement and is **explicitly out of scope for this project**, deferred as
  its own future brainstorm.

**This project's actual scope: 61 files, 772 offender strings.**

## Decisions from brainstorming

1. **Full remaining scope, not a smaller batch.** Unlike the ADR's original
   "~30 strings per PR" suggestion, this project covers all 61 files in one
   plan/branch, following the same subagent-driven-development process as the
   prior 9-file project, just with more tasks.
2. **tg/uz stays deferred.** Per the ADR's own 2026-08-22 reconciliation note,
   native-speaker tg/uz review continues to be an explicit, deliberate product
   deferral — not an oversight. New keys added by this project follow the same
   pattern as every key added so far: `app_ru.arb` is authored, `flutter
   gen-l10n` regenerates all three locale files, and tg/uz simply inherit
   whatever `flutter gen-l10n` produces for them (their own `.arb` files remain
   separately, manually maintained and behind — this project does not touch
   `app_tg.arb`/`app_uz.arb` directly, matching the prior project's practice).
   `l10n_untranslated.json` continues to be regenerated and committed as the
   tracked backlog artifact.
3. **Track 3 (Bloc-level errors) is out of scope**, deferred to its own future
   design, per the ADR's own separation of tracks.
4. **Task grouping:** large files get their own task; small files are bundled
   by directory/feature proximity into multi-file tasks, to keep the total
   task count manageable (29 tasks instead of 61 one-file tasks).

## Scope: task breakdown

### Individual-file tasks (18 tasks, 442 strings — files with ≥15 offenders)

| # | File | Offenders |
|---|---|---|
| 1 | `pages/settings/subscription_page.dart` | 61 |
| 2 | `pages/finance/reports_page.dart` | 56 |
| 3 | `pages/product/product_detail_page.dart` | 37 |
| 4 | `pages/settings/receipt_template_page.dart` | 27 |
| 5 | `pages/pos/pos_checkout_page.dart` | 26 |
| 6 | `pages/sales/transaction_detail_page.dart` | 23 |
| 7 | `pages/zakat/zakat_settings_page.dart` | 21 |
| 8 | `pages/zakat/zakat_calculator_page.dart` | 21 |
| 9 | `pages/finance/finance_dashboard_page.dart` | 21 |
| 10 | `pages/sales/sales_history_page.dart` | 19 |
| 11 | `widgets/pos/sales_filter_sheet.dart` | 18 |
| 12 | `pages/customer/customer_detail_page.dart` | 18 |
| 13 | `pages/product/product_list_page.dart` | 17 |
| 14 | `pages/notifications/notification_settings_page.dart` | 17 |
| 15 | `pages/sales/refund_page.dart` | 15 |
| 16 | `pages/payroll/add_adjustment_page.dart` | 15 |
| 17 | `pages/finance/add_investment_page.dart` | 15 |
| 18 | `pages/finance/add_expense_page.dart` | 15 |

(All paths relative to `app/lib/presentation/`.)

### Bundled tasks (10 tasks, 330 strings — files with <15 offenders each)

| # | Bundle | Files (offenders) | Total |
|---|---|---|---|
| 19 | Settings misc A | `settings/offline_mode_page.dart`(14), `settings/kkm_settings_page.dart`(14), `settings/scanner_settings_page.dart`(13) | 41 |
| 20 | Settings misc B | `settings/edit_profile_page.dart`(10), `settings/telegram_bot_settings_page.dart`(9), `settings/language_settings_page.dart`(7) | 26 |
| 21 | Product misc | `product/categories_page.dart`(14), `product/add_product_step3_page.dart`(13), `product/add_product_step1_page.dart`(13) | 40 |
| 22 | Staff misc | `widgets/staff/permission_toggle_row.dart`(14), `staff/staff_detail_page.dart`(14), `staff/staff_list_page.dart`(10), `widgets/staff/staff_card.dart`(5) | 43 |
| 23 | POS misc | `widgets/pos/receipt_widget.dart`(10), `pos/sale_success_page.dart`(7), `pos/cash_payment_page.dart`(7), `pos/receipt_preview_page.dart`(3) | 27 |
| 24 | Finance misc | `finance/currencies_page.dart`(12), `widgets/finance/expense_card.dart`(7), `finance/investment_list_page.dart`(6), `widgets/finance/period_selector.dart`(4), `widgets/finance/profit_summary_card.dart`(3), `widgets/finance/stat_summary_row.dart`(2) | 34 |
| 25 | Zakat + shifts misc | `zakat/zakat_history_page.dart`(9), `widgets/zakat/zakat_breakdown_card.dart`(8), `widgets/shifts/current_shift_card.dart`(9), `shifts/open_shift_page.dart`(7), `widgets/shifts/shift_card.dart`(4) | 37 |
| 26 | Supplier/stock/debt misc | `supplier/supplier_list_page.dart`(12), `stock/stock_intake_page.dart`(12), `debt/customer_debts_page.dart`(8), `widgets/debt/payment_form.dart`(5) | 37 |
| 27 | Notifications + payroll widget + dashboard widget | `notifications/notifications_page.dart`(13), `widgets/payroll/month_selector.dart`(12), `widgets/dashboard/sale_list_item.dart`(3) | 28 |
| 28 | Common widgets misc | `widgets/common/offline_banner.dart`(6), `widgets/common/barcode_scanner_sheet.dart`(3), `widgets/common/app_dialog.dart`(2), `widgets/home/impersonation_banner.dart`(2), `widgets/common/phone_input_field.dart`(1), `widgets/common/app_search_bar.dart`(1), `widgets/common/app_error_widget.dart`(1), `widgets/common/app_bottom_sheet.dart`(1) | 17 |

### Final task (29): allow-list regeneration + full verification

Same shape as the prior project's Task 11: `dart run tool/check_i18n.dart
--dump-allowlist`, confirm the settings_page.dart proper-noun comment block
survives (re-add if `--dump-allowlist` drops it, same as last time), verify
`check_i18n.dart`/`flutter analyze`/`flutter test` are clean, per-file zero-offender
checks for all 61 files.

## Conventions carried over unchanged from the prior project

These are all already established and proven; this project does not
re-litigate them, just applies them at larger scale:

- **`.claude/rules/mobile-l10n.md`**: `app_ru.arb` is the template locale;
  never hand-edit generated `app_localizations*.dart`; keys live in contiguous
  feature-prefix blocks; reuse an existing key when the *meaning* matches
  regardless of render location; grep the ARB before minting; label+separator
  composites get one full-sentence key; `@key` descriptions for
  non-obvious/near-duplicate keys; placeholders are always `String`-typed,
  pre-formatted at the call site.
- **Mandatory value verification before reuse.** Every task must confirm a
  candidate reused key's ARB value matches character-for-character before
  using it — this branch's predecessor shipped two real bugs (`f54d5fd`,
  `bb6a1cc`) from skipping this check. Every implementer prompt states this
  explicitly.
- **Golden-test pre-existing-failure verification.** `test/flutter_test_config.dart`
  gives Linux CI 100% tolerance vs. ~0.2% on macOS — a local golden mismatch is
  not automatically a regression. When a golden test fails after a migration,
  verify via a throwaway `git worktree` at the parent commit (created outside
  the project's own worktree, removed after) whether the same failure
  pre-exists there.
- **Two-stage review per task** (spec-compliance, then code-quality),
  dispatched via subagent-driven-development, same as before. For bundled
  tasks, the review covers all files in that bundle together (one
  spec-compliance + one code-quality pass per bundle, not per file).
- **Orchestrator fixes small, well-scoped review findings directly** (as
  established for the prior project: wrong-value key reuse, duplicate keys,
  orphaned keys) rather than re-dispatching an implementer for a one-line fix.
- **Final whole-branch review** before merge, same as before, specifically
  re-checking for cross-task ARB key duplication (the biggest real risk at
  this scale — 29 independently-dispatched tasks each running their own ARB
  grep against a moving target).

## Out of scope (explicitly, for this project)

- `settings_page.dart`'s 6 proper-noun exceptions — already handled, left
  untouched.
- The 6 Bloc files (Track 3) — deferred to a future, separate
  brainstorm/design, since it requires an actual architectural mechanism
  decision (error-code-to-localized-string mapping), not literal replacement.
- tg/uz native-speaker translation review — remains an explicit, standing
  product deferral per the ADR.
- Any refactoring not required to extract the strings (e.g., restructuring a
  page's widget tree) — same "don't fix unrelated things" discipline as
  established throughout this branch's predecessor.
