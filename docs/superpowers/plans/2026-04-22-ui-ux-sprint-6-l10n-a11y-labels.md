# Sprint 6 — L10n for Sprint 5B.2.a/b Accessibility Labels

> **For agentic workers:** Controller adds arb keys; subagents migrate call-sites per cluster.

**Goal:** Localize the hardcoded Russian `tooltip:` and `Semantics(label: ...)` strings added in Sprint 5B.2.a/b into `app_ru.arb` / `app_tg.arb` / `app_uz.arb` and route call-sites through `AppLocalizations.of(context)!`.

**Architecture:**
- **Phase 1** — extend all three `.arb` files with ~29 new keys (some overlapping with existing keys are re-used).
- **Phase 2** — migrate ~39 call-sites across ~30 files to `AppLocalizations.of(context)!.<key>` or `l10n.<key>`.
- **Phase 3** — `flutter gen-l10n`, analyze, test, commit.

**Non-goals:** SnackBar `AppSnackbar.success/error/info(context, 'сообщение')` messages remain hardcoded — those pre-date the a11y sprints and represent ~91 additional strings that need a separate l10n sprint.

---

## Audit — 39 unique strings → key map

### Tooltips (26 unique)

| Russian | Key | Exists in arb? |
|---|---|---|
| Назад | `back` | ✓ |
| Закрыть | `close` | ✓ |
| Поделиться | `share` | NEW |
| Обновить | `refresh` | NEW |
| Фильтр | `filter` | NEW |
| Фильтры | `filters` | NEW |
| Сканировать штрихкод | `scanBarcode` | ✓ |
| Добавить товар | `addProduct` | ✓ |
| Редактировать товар | `editProduct` | ✓ |
| Удалить товар | `deleteProduct` | NEW |
| Добавить клиента | `addClient` | NEW (existing `addCustomer` = "Добавить покупателя" — different word!) |
| Позвонить клиенту | `callClient` | NEW |
| Выбрать клиента | `selectClient` | NEW |
| Добавить поставщика | `addSupplier` | ✓ |
| Добавить сотрудника | `addEmployee` | ✓ |
| Редактировать сотрудника | `editEmployee` | ✓ |
| Редактировать магазин | `editStore` | NEW |
| Редактировать скидку | `editDiscount` | NEW |
| Удалить скидку | `deleteDiscount` | NEW |
| Редактировать категорию | `editCategory` | NEW |
| Удалить категорию | `deleteCategory` | NEW |
| Открыть отчёты | `openReports` | NEW |
| Скачать отчёт | `downloadReport` | NEW |
| История расчётов | `calculationHistory` | NEW |
| Настройки закята | `zakatSettings` | ✓ |
| Увеличить количество | `increaseQuantity` | NEW |
| Уменьшить количество | `decreaseQuantity` | NEW |

### Semantics labels (13 unique — 6 simple, 7 with placeholders)

| Russian | Key | Placeholder |
|---|---|---|
| Без сдачи | `withoutChange` | NEW |
| Выбрать период | `selectPeriod` | NEW |
| Загрузить фото | `uploadPhoto` | NEW |
| Добавить товар | `addProduct` (reuse) | — |
| Открыть Z-отчёт | `openZReport` | NEW |
| Отметить как прочитанное | `markAsRead` | NEW |
| Редактировать профиль | `editProfile` | NEW |
| Быстрая сумма {amount} | `quickAmount` | `{amount}` |
| Выбрать валюту {code} | `selectCurrency` | `{code}` |
| Выбрать магазин {name} | `selectStore` | `{name}` |
| Выбрать язык {language} | `chooseLanguage` | `{language}` |
| Открыть товар {name} | `openProduct` | `{name}` |
| Платёж {plan} | `paymentOf` | `{plan}` |

**Total new keys across ru/tg/uz:** 29 × 3 = 87 arb entries + 7 placeholder ICU specs.

---

## Phase 1 — Arb extension

Add keys to the three `.arb` files under `app/lib/l10n/`. Preserve alphabetical grouping, add `@key` metadata for new keys, match formatting of existing entries.

Translation strategy:
- **ru:** use the exact Russian phrase from the audit.
- **tg:** use common Tajik vocabulary consistent with existing entries in `app_tg.arb`. For compound phrases, follow patterns like "editProduct" = "Редактировать товар" → use similar verb+noun order in Tajik.
- **uz:** follow Latin-script Uzbek consistent with existing `app_uz.arb` patterns.

Placeholders: ICU-style `{name}`, defined in `@key.placeholders` block.

---

## Phase 2 — Call-site migration

Dispatch subagents per cluster. Each subagent:

1. Identifies exactly which hardcoded Russian `tooltip:` / `label:` strings exist in each file.
2. Replaces with `AppLocalizations.of(context)!.<key>` (or `final l10n = AppLocalizations.of(context)!;` + `l10n.<key>` if multiple strings per widget).
3. For placeholder strings: `l10n.selectStore(name)`.
4. Keeps untouched any Russian strings outside a11y-sprint scope (AppSnackbar messages, heading Text, etc).
5. `flutter analyze <cluster>` → 0 issues.
6. Commits per cluster.

Clusters (same as 5B.2.a/b split):
- **Task 2.1** — Bottom nav + POS (bottom nav tabs are already l10n'd, POS has 2 custom Semantics labels)
- **Task 2.2** — Product CRUD (7 files, ~9 tooltips + 2 labels)
- **Task 2.3** — Settings (6 files, ~5 tooltips + 4 labels)
- **Task 2.4** — Finance (7 files, ~3 tooltips + 1 label)
- **Task 2.5** — CRM + Shifts/Sales (8 files, ~5 tooltips + 1 label)
- **Task 2.6** — Zakat/Debt/Delivery/Staff/Payroll/Misc (11 files, ~10 tooltips + 2 labels)

---

## Phase 3 — Wrap-up

1. `flutter gen-l10n` (auto-runs on build, but explicit for safety).
2. `flutter analyze lib/` → 0 issues.
3. `flutter test` → 363/363 pass baseline maintained.
4. Update this plan with completion block.
5. Final commit.

---

## Execution notes

- **AppLocalizations imports:** `import 'package:dokonpro/l10n/app_localizations.dart';` — many files in the codebase already import it; grep before adding.
- **Context availability:** tooltip/Semantics inside `build()` have context. For tooltips assigned to IconButton inside helper methods (`_Widget`, `_Card`), pass l10n down as parameter or use `Builder` pattern.
- **Interpolation:** when current code uses `${var.field}`, arb uses `{var}` and call-site passes value: `l10n.selectStore(name)`.
- **Translation quality:** tg and uz translations are best-effort based on existing arb patterns. Mark with `// TODO(l10n-review)` comment in arb if uncertain.
- **Tests:** existing bottom nav test (`critical_paths_semantics_test.dart`) asserts literal Russian strings like "Главная". Since `_host` already uses `locale: Locale('ru')`, the test continues to pass — l10n still resolves to Russian in ru locale. No test change required.
