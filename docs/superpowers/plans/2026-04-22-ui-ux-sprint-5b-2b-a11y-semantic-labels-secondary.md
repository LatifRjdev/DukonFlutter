# Sprint 5B.2.b — Semantic Labels (Secondary Paths) Implementation Plan

> **For agentic workers:** Use `subagent-driven-development` skill to execute task-by-task. Same pattern as Sprint 5B.2.a — hardcoded Russian labels, hybrid API: `IconButton(tooltip:)` + `Semantics(label, button: true)` for custom tappables. In-`AppBar.leading` back buttons are auto-labeled by `MaterialLocalizations.ru` → skip them.

**Goal:** Apply the 5B.2.a semantic-label pattern to secondary-path pages (settings, finance, CRM, shifts/sales, misc) so screen readers announce controls consistently across the whole app.

**Scope (post-audit):** 5 clusters, 34 files touched, ~63 candidate sites (31 IconButton + 32 GestureDetector/InkWell). After skipping AppBar auto-labeled back buttons and decorative-only Semantics wraps, effective count will drop to ~40 labels.

**Spec reference:** Label conventions from `docs/superpowers/specs/2026-04-21-ui-ux-sprint-5b-2a-a11y-semantic-labels-critical-design.md` §3 apply verbatim. New labels below follow the same style (verb + noun, capitalized first letter, no period).

---

## Label Convention Additions (Sprint 5B.2.b)

Prior 5B.2.a covered: Назад, Поделиться, Редактировать товар, Удалить категорию, Сканировать штрихкод, Загрузить фото, etc.

New labels introduced in 5B.2.b — prefer these before inventing new phrasing:

| Widget / Action | Label |
|---|---|
| Add / create (FAB or IconButton) | `Добавить <entity>` (e.g. "Добавить клиента", "Добавить поставщика", "Добавить сотрудника") |
| Edit entity IconButton | `Редактировать <entity>` (e.g. "Редактировать клиента") |
| Delete entity IconButton | `Удалить <entity>` |
| Filter / sort IconButton | `Фильтр`, `Сортировка` |
| Search IconButton | `Поиск` |
| Refresh IconButton | `Обновить` |
| Settings row (GestureDetector/InkWell navigation card) | `Открыть настройки <feature>` (e.g. "Открыть настройки принтера") |
| Dashboard stat card (GestureDetector) | `Открыть <section>` (e.g. "Открыть отчёты", "Открыть остатки") |
| Language chip (InkWell) | `Выбрать язык <lang>` |
| Subscription plan card | `Выбрать тариф <name>` |
| Toggle currency / switch item | `Выбрать валюту <code>`, `Переключить на <name>` |

**Rule:** if a `GestureDetector`/`InkWell` child already contains a visible `Text(label)` AND the widget is purely decorative navigation (row pushes a route), leaving it unlabeled is acceptable — Flutter auto-exposes Text in its subtree. Only wrap in `Semantics` when the tap target lacks visible text (icon-only cards) or the visible text is ambiguous out of context.

---

## Task Structure

Each cluster is one task. Within a task:
1. Read each file listed.
2. Add `tooltip:` to IconButton sites (skip if inside `AppBar.leading`).
3. Wrap custom `GestureDetector`/`InkWell` in `Semantics(label, button: true)` **only** where the tap target is icon-only or has ambiguous visible text.
4. `flutter analyze <cluster-dir>` → 0 issues.
5. Commit with message `feat(a11y): semantic labels for <cluster>`.

---

## Task 1 — Settings cluster (6 files, ~10 effective widgets)

| File | IconButton | Gesture/InkWell |
|---|---|---|
| `settings/edit_profile_page.dart` | 1 | 0 |
| `settings/my_stores_page.dart` | 1 | 1 |
| `settings/subscription_page.dart` | 0 | 2 |
| `settings/discounts_page.dart` | 2 | 0 |
| `settings/language_settings_page.dart` | 0 | 1 |
| `settings/settings_page.dart` | 0 | 2 |

Commit: `feat(a11y): semantic labels for settings cluster`

---

## Task 2 — Finance cluster (7 files, ~11 effective widgets)

| File | IconButton | Gesture/InkWell |
|---|---|---|
| `finance/add_expense_page.dart` | 0 | 1 |
| `finance/add_investment_page.dart` | 0 | 2 |
| `finance/currencies_page.dart` | 0 | 1 |
| `finance/expense_list_page.dart` | 0 | 1 |
| `finance/finance_dashboard_page.dart` | 1 | 1 |
| `finance/investment_list_page.dart` | 0 | 1 |
| `finance/reports_page.dart` | 1 | 2 |

Commit: `feat(a11y): semantic labels for finance cluster`

---

## Task 3 — CRM cluster (4 files, ~9 effective widgets)

| File | IconButton | Gesture/InkWell |
|---|---|---|
| `customer/customer_detail_page.dart` | 0 | 1 |
| `customer/customer_list_page.dart` | 2 | 2 |
| `supplier/supplier_detail_page.dart` | 0 | 1 |
| `supplier/supplier_list_page.dart` | 2 | 1 |

Commit: `feat(a11y): semantic labels for CRM (customer + supplier) cluster`

---

## Task 4 — Shifts/Sales cluster (4 files, ~7 effective widgets)

| File | IconButton | Gesture/InkWell |
|---|---|---|
| `shifts/shifts_page.dart` | 1 | 1 |
| `sales/sales_history_page.dart` | 2 | 1 |
| `sales/transaction_detail_page.dart` | 1 | 0 |
| `sales/refund_page.dart` | 1 | 0 |

Commit: `feat(a11y): semantic labels for shifts and sales history cluster`

---

## Task 5 — Misc cluster (13 files, ~26 effective widgets)

Biggest cluster. Split into two commits if subagent hits context limits.

| File | IconButton | Gesture/InkWell |
|---|---|---|
| `staff/staff_list_page.dart` | 2 | 1 |
| `staff/staff_detail_page.dart` | 1 | 0 |
| `payroll/payroll_page.dart` | 2 | 1 |
| `payroll/add_adjustment_page.dart` | 0 | 1 |
| `notifications/notifications_page.dart` | 1 | 1 |
| `inventory/inventory_count_page.dart` | 1 | 0 |
| `stock/stock_intake_page.dart` | 1 | 0 |
| `zakat/zakat_calculator_page.dart` | 3 | 0 |
| `zakat/zakat_history_page.dart` | 1 | 0 |
| `zakat/zakat_settings_page.dart` | 2 | 1 |
| `debt/customer_debts_page.dart` | 1 | 0 |
| `delivery/delivery_list_page.dart` | 0 | 1 |
| `dashboard/dashboard_page.dart` | 0 | 4 |

Commit: `feat(a11y): semantic labels for staff/payroll/zakat/misc clusters`

---

## Task 6 — Final checks + commit

1. `flutter analyze lib/` → 0 issues (whole `lib`, not just touched files).
2. `flutter test` → same pass rate as baseline (12 golden-drift failures are pre-existing, documented in 5B.2.a plan).
3. Update this plan file with a "Sprint 5B.2.b Complete" block.
4. Final commit `docs(sprint-5b-2b): mark complete`.

---

## Execution notes

- **Do not** add tooltip to `AppBar.leading` back button — `MaterialLocalizations.ru` auto-announces "Назад".
- **Do not** wrap `GestureDetector` in `Semantics` if its direct child subtree contains a visible `Text` label that is clear on its own. Example: a whole-card navigation row with `Text('Настройки принтера')` → redundant to wrap in `Semantics(label: 'Настройки принтера')`.
- **Do** wrap when the tap target is icon-only or uses an Icon + chevron with no inline text identifier.
- Golden tests: `Semantics` and `tooltip:` do not change rendered pixels — do NOT regen goldens unless a specific test reports a diff you can trace to your change.
- Prefer `tooltip: 'X'` over `Semantics(label: 'X', child: IconButton(...))` for IconButton — the tooltip parameter is dual-purpose (visual hover + semantic label) and more idiomatic.
