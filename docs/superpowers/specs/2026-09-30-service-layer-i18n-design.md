# Service-layer i18n (ADR-0002 Track 2b) — Design

**Status:** approved 2026-09-30
**Predecessor:** ADR-0002 Track 2 (merged `4d4c007`, 61 files in `lib/presentation`, ARB 736 → 1173 keys)
**Successor:** Sub-project B — the error-code refactor (not this spec, see Out of Scope)

## Problem

Track 2 localized `lib/presentation`. It did not touch `lib/core`, `lib/data` or
`lib/domain`, because `tool/check_i18n.dart` hardcodes its scan root to
`lib/presentation` and the whole 29-task plan was keyed to that scanner's
allowlist. **71 user-facing Russian literals remain outside that tree, unlinted.**

The problem is not merely that they are unmigrated. **44 of the 71 duplicate ARB
values Track 2 just created.** The moment `app_tg.arb`/`app_uz.arb` are filled in,
the same string renders localized on one surface and Russian on another — most
visibly, a sale's on-screen total localizes while the printed receipt total does
not, because `totalCaps` and `thermal_printer_service.dart:175`'s hardcoded
`'ИТОГО'` are different sources for the same label.

This makes the work a precondition for translating, not a follow-on to it.

## Scope

**57 literals across 7 files**, all translatable. Counts are from a wide-class
(`[Ѐ-ԯ]`) multi-match scan of code lines, excluding comments. Cross-check:
57 in scope + 14 out of scope = the 71 literals measured outside `lib/presentation`.

| File | Literals | Nature |
|---|---:|---|
| `lib/core/services/thermal_printer_service.dart` | 16 | ESC/POS receipt column headers, total rows, payment names, footer |
| `lib/core/services/receipt_pdf_service.dart` | 15 | The same receipt content, PDF renderer |
| `lib/core/constants/enums.dart` | 12 (8 translatable) | `displayName` extensions on `Currency`, `StoreCategory`, `ProductUnit` |
| `lib/core/services/debt_reminder_service.dart` | 8 | Scheduled push-notification titles and bodies |
| `lib/data/datasources/remote/currency_remote_datasource.dart` | 4 | Currency display names |
| `lib/core/services/receipt_share_service.dart` | 1 | Share-sheet receipt caption |
| `lib/domain/entities/z_report.dart` | 1 | A pre-formatted duration string |

`enums.dart`'s 12 are `'сом.'`, the 6 `StoreCategory` names (`'Продукты'`,
`'Одежда'`, `'Электроника'`, `'Стройматериалы'`, `'Аптека'`, `'Другое'`) and the 5
`ProductUnit` names (`'шт'`, `'кг'`, `'л'`, `'м'`, `'уп'`). `Currency.usd`'s `'$'`
and `Currency.rub`'s `'₽'` are symbols, not Cyrillic, so the scanner never matches
them and they need no key — but the `displayName` methods that return them still
gain the `l10n` parameter, since one switch serves all three cases.

### Out of scope — Sub-project B

`lib/core/errors/error_messages.dart` (11) and
`lib/data/repositories/debt_repository_impl.dart` (3). Both belong to the error
path, which is an architectural change rather than a string migration:

- `mapErrorToUserMessage` has **124 call sites across 29 Bloc files**, and its
  result lands in state objects that roughly **66 UI sites** read as `.message`.
  Converting it to error codes touches more sites than all 61 files of Track 2.
- `debt_repository_impl`'s 3 literals are *exception constructor arguments*.
  `mapErrorToUserMessage` dispatches on exception **type** and HTTP status and
  never reads `.message`, so these strings do not reach users today. They must
  move together with the error mechanism, not ahead of it.
- Track 3's 19 Bloc-state strings sit in the same `emit(...)` statements and need
  the same mechanism, so B should absorb them.

Also out of scope: filling in the tg/uz translation backlog (809 keys per locale).

## Architecture

**Rule: any function outside `lib/presentation` that produces user-facing text
takes `AppLocalizations` as a parameter.** Resolution happens at the UI call
site, which always has a `BuildContext`.

No service stores a locale. That is the load-bearing property: `ReceiptPdfService`,
`ThermalPrinterService`, `ReceiptShareService` and `DebtReminderService` are all
registered as **lazy singletons** in `injection.dart`, so a locale captured at
construction would go stale the moment the user switches language — reintroducing
the bug this work exists to remove.

Receipts follow the **app UI language** (product decision, 2026-09-30). No
per-store receipt-language setting is introduced.

### Why a parameter rather than a value object

A core-owned `ReceiptStrings` value object would keep `lib/core` free of the
generated `AppLocalizations`, but:

- `lib/core/services` already imports `package:flutter/foundation.dart` and
  `package:flutter/services.dart`, so it is not framework-pure; the boundary the
  value object would defend does not exist.
- There is no KMP module (`shared/`, `androidApp/`, `iosApp/` are absent; the only
  Kotlin/Swift is Flutter's own platform scaffolding), so the portability argument
  is hypothetical. The `.claude/rules/kmp-architecture.md` rules are aspirational.
- Track 2 established the parameter signature eight times over
  (`_formatDuration(AppLocalizations, …)`, `_categoryOptions(AppLocalizations)`,
  `permissionLabel(BuildContext, …)`), each reviewed and approved.

A 16-field bundle is real code for isolation nothing currently needs. If
`lib/core` is ever extracted into a package, revisit.

### No Track 3 entanglement

`PrinterBloc` (no `BuildContext`) calls only `scanDevices`, `connect`,
`disconnect`, `testPrint`, `setDefaultPrinter`, `getDefaultPrinterName`,
`getDefaultPrinterAddress`. **None contains Cyrillic** — verified: `testPrint()`
(lines 74–104) has zero Cyrillic literals.

The 16 literals live in `_buildReceiptBytes` (120–215) and `_paymentTypeName`
(216–222), reachable only via `printReceipt()` and `buildReceiptBytesForTest()`,
whose only callers are `receipt_preview_page.dart:49` and
`sale_success_page.dart:81` — both UI with a context. So the receipt path can take
an `l10n` parameter without touching any Bloc.

## Components

**Signature changes.** `printReceipt`, `buildReceiptBytesForTest`,
`_buildReceiptBytes`, `_paymentTypeName` (thermal); the equivalent PDF builders;
`shareReceipt`; `scheduleDebtReminder` and `showLowStockAlert`; and the three
`displayName` getters become methods. Each gains a `required AppLocalizations l10n`
parameter. Call sites in `receipt_preview_page.dart` and `sale_success_page.dart`
resolve it from their existing context.

**`currency_remote_datasource.dart`** holds a `static const _labels` map of
currency names. `static const` cannot call `AppLocalizations.of`, so the map is
removed and the name resolved where the rate is rendered, reusing the
`currencyUsd`/`currencyRub`/`currencyEur`/`currencyCny` keys Task 24 minted for
exactly this (they were minted knowing this duplicate existed).

**`z_report.dart`** currently stores `duration` as pre-formatted text
(`'${diff.inHours}ч ${diff.inMinutes % 60}м'`) inside a domain entity. Rather than
pushing `AppLocalizations` into the domain layer, the entity exposes the numeric
components and the UI formats them via the existing `shiftsDurationFormat`
(`"{hours}ч {minutes}м"`). This is the only change that alters an entity contract;
it is small and it keeps the domain layer free of l10n.

**`DebtReminderService` is dead code** — registered in `injection.dart` and never
resolved anywhere. Its 8 literals are migrated regardless: it is cheap, carries no
regression risk precisely because nothing calls it, and it leaves the service
correct for whoever wires it up. Its body also hardcodes `'сом.'` and `'шт'`,
duplicating `enums.dart`, so migrating it removes two more divergences.

## Key reuse

Roughly 44 of the 57 literals already exist as ARB values and must be **reused,
not re-minted** — that reuse is the point of the sub-project. Confirmed pairs
include:

| Literal | Existing key |
|---|---|
| `'ИТОГО'` | `totalCaps` |
| `'Товар'` | `product` |
| `'Скидка'` | `discount` |
| `'Подытог'` | `subtotal` |
| `'Сдача'` | `change` |
| `'Оплачено'` | `paidAmount` |
| `'Оплата'` | `payment` |
| `'Спасибо за покупку!'` | `receiptPreviewDefaultFooter` |
| `'Наличные'` / `'Карта'` / `'В долг'` / `'Смешанная'` | `cash` / `card` / `debt` / `paymentMixedShort` |
| `'Доллар США'` etc. | `currencyUsd` / `currencyRub` / `currencyEur` / `currencyCny` |
| `'шт'` / `'кг'` / `'л'` / `'м'` / `'уп'` | existing unit keys (verify per key) |

Every reuse must be verified **character-for-character** against `app_ru.arb`
before use, and near-misses must not be conflated — the discipline that caught
16+ plan errors during Track 2. Expect roughly **10–15 genuinely new keys**,
mostly the receipt-specific loyalty lines (`'Начислено баллов: +N'`,
`'Ваш баланс: N баллов'`), the `'Кол'` column abbreviation, and the notification
titles.

## Linter scope extension

Change `check_i18n.dart`'s scan root from `lib/presentation` to `lib`, **excluding
`lib/l10n/`** — the generated `app_localizations_ru.dart` is entirely Russian and
would swamp the output with thousands of false positives.

Seed Sub-project B's 14 error-path literals into `tool/i18n-allowlist.txt` under a
comment naming B as their owner, so the extended scan lands green. After this, the
gap cannot silently regrow: a new hardcoded string anywhere in `lib` fails CI.

The scanner was already hardened in `269e497` (`firstMatch` → `allMatches`,
`[а-яА-ЯёЁ]` → `[Ѐ-ԯ]`) with regression tests verified to fail against the prior
implementation, so no further scanner work is needed beyond the root change.

## Testing

**Existing coverage.** The UI call sites are exercised by existing golden tests
for `receipt_preview_page` and `sale_success_page`. Values stay byte-identical, so
goldens must not move — a golden change signals a wrong value, exactly as in
Track 2.

**Service tests need a localizations instance.** `receipt_pdf_service_test.dart`
and `thermal_printer_service_test.dart` construct services directly, with no
widget tree. They obtain one via
`await AppLocalizations.delegate.load(const Locale('ru'))` in `setUpAll`. Note
both files deliberately assert Tajik-character handling (`'Чойи сабз ҳамчун ёд'`,
`'Дӯкон'`) — those assertions are about encoding, not localization, and must keep
passing unchanged.

**New test.** One regression test that the extended linter actually flags a
hardcoded literal in `lib/core`, proving the scope extension is non-vacuous rather
than passing because the allowlist swallows everything. This mirrors the
reintroduce-a-literal proof used throughout Track 2's reviews.

**Acceptance.** `dart run tool/check_i18n.dart` clean and proven non-vacuous;
`flutter analyze` clean; full `flutter test` failing set unchanged from the
documented baseline of 18 golden failures (see
`flutter-golden-baseline-failures` memory — a 19th intermittent failure in
`subscription_bloc_test.dart` was fixed in `efbdc96`, so the set should be a clean
18); `flutter gen-l10n` producing zero diff.

## Risks

**A golden that cannot signal.** Three of the 18 baseline golden failures are
pages Track 2 touched, and several share an identical pixel delta from common
chrome — meaning those goldens are weak content signals. Value-preservation must
therefore be verified by comparing each ARB value byte-for-byte against the
literal it replaces, not by trusting a green golden. This is how Track 2's final
review caught what per-task reviews could not.

**Reuse of a same-spelling, different-meaning key.** The highest-risk mistake is
reusing a key whose Russian happens to match but whose meaning differs — Track 2
hit this repeatedly (`paid` the payroll status vs `paidAmount` the receipt row;
`expense` the ledger entry vs `outflowType` the stock movement). Every reuse needs
its meaning checked against the existing key's `@description` and call sites, not
just its value.

**Entity contract change.** `z_report.dart` is the only change touching a domain
entity's shape. Its consumers must be enumerated before the change, not after.
