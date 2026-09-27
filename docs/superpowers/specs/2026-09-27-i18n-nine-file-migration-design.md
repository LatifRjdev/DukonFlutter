# i18n: Migrate 9 Files + Content-Based Allow-list — Design

**Context.** Following the allow-list resync (`2026-09-27-i18n-allowlist-resync-design.md`),
9 files were identified as having genuinely new hardcoded Cyrillic strings
added since the allow-list was last regenerated (2026-08-22). Attempting
to isolate exactly which lines are "new" via `git log` proved unreliable —
commits that refactor/move code (e.g. `my_stores_page.dart`'s
`9d4bc46 fix(mobile): validate store name...`) show many lines as
"added" in the diff even though the string itself already existed
before, just at a different line. Rather than risk misclassifying
new-vs-moved, this project fully migrates every currently-hardcoded
Cyrillic string in these 9 files, so each becomes unambiguously clean
(zero `check_i18n.dart` offenders) regardless of how it got there.

**Goal.** (1) Migrate every current hardcoded Cyrillic string in the 9
files below into `app_ru.arb` + `AppLocalizations`, per
`.claude/rules/mobile-l10n.md`. (2) Fix `check_i18n.dart`'s allow-list to
key violations by file+content instead of file+line, so unrelated edits
elsewhere in a file can never desync it again (the exact failure mode
that caused this whole investigation, and that ADR-0002 already
documents happening once before).

## Files in scope (current offender count, from `check_i18n.dart`)

- `lib/presentation/pages/customer/customer_list_page.dart` — 20
- `lib/presentation/pages/finance/expense_list_page.dart` — 4
- `lib/presentation/pages/payroll/payroll_page.dart` — 35
- `lib/presentation/pages/settings/discounts_page.dart` — 14
- `lib/presentation/pages/settings/my_stores_page.dart` — 18
- `lib/presentation/pages/settings/settings_page.dart` — 41
- `lib/presentation/pages/shifts/shifts_page.dart` — 22
- `lib/presentation/pages/supplier/supplier_detail_page.dart` — 1
- `lib/presentation/widgets/payroll/payroll_staff_card.dart` — 10

Total: ~165. Each file's task is done when re-running
`dart run tool/check_i18n.dart` reports zero offenders inside that
specific file (other files may still have pre-existing, out-of-scope
offenders — this project does not touch any file outside this list).

## Per-file migration methodology

For each file, in order:

1. Run `dart run tool/check_i18n.dart` and read the offender lines
   belonging to this file (the regex it uses —
   `['"][^'"]*[а-яА-ЯёЁ][^'"]*['"]` — is the authoritative definition of
   "a hardcoded Cyrillic string" for this project; anything it doesn't
   flag is out of scope, even if adjacent).
2. For each offending literal, `grep` `lib/l10n/app_ru.arb` for the
   exact same Russian text already existing under a different key
   (case-sensitive exact match first; if none, consider near-duplicates
   the convention calls out — e.g. "Сохранить" already exists as
   `save`). If found, reuse that key — do not mint a new one.
3. If no reuse candidate exists: is the string specific to this one
   screen, or plausibly reusable elsewhere (a generic label like
   "Активный", "Повторить", a form field label, a confirmation body)?
   Generic → unprefixed key name (`retry`, `active`, `phoneLabel` —
   check the ARB's existing unprefixed key style first). Screen-specific
   → prefixed with the screen's existing key prefix if one is already
   established in the ARB for that screen (check first — several of
   these files already have partial ARB coverage from prior migrations),
   otherwise mint a new prefix matching the file's feature area
   (`customerList*`, `expenseList*`, `payrollPage*`, `discountsPage*`,
   `myStoresPage*`, `settingsPage*`, `shiftsPage*`, `supplierDetail*`,
   `payrollStaffCard*`).
4. Interpolated strings (`'$var в очереди'`, `'Вы уверены, что хотите
   удалить "$name"?'`) become one full-sentence key with a `String`
   placeholder (pre-format the value at the call site, per the file's
   existing convention — never `int`/`num`, never ICU plural/select).
5. Add an `@key` description in the ARB only where the meaning isn't
   obvious from the key name alone, or where it's a near-duplicate of an
   existing key that needs to state how they differ (per convention).
6. After all of a file's keys are added to `app_ru.arb`, run
   `flutter gen-l10n`, then replace each literal at its call site with
   `AppLocalizations.of(context)!.yourKey` (or the interpolated-value
   equivalent), matching whatever accessor pattern the file already uses
   elsewhere (several of these files already call `AppLocalizations.of
   (context)!` for other strings — reuse that binding, don't add a
   second one).
7. Verify: `dart run tool/check_i18n.dart` shows zero offenders for this
   file; `flutter analyze` clean; re-run this file's existing test(s)
   (golden and/or widget tests, wherever they exist) — visible text is
   unchanged, so they must still pass unmodified.

**Deliberate exception — language and tariff proper nouns
(`settings_page.dart` only):** "Ўзбекча", "Тоҷикӣ", "Русский" (language
switcher labels) and "Старт", "Бизнес", "Премиум" (subscription plan
names, matching the `SubscriptionPlan` enum `START`/`BUSINESS`/`PREMIUM`
used throughout the admin panel) are proper nouns/brand names, not
ordinary UI text — a language's own name doesn't change based on which
locale is currently displayed, and tariff names are product brands. These
stay hardcoded, added to the new allow-list (see below) with a comment
explaining why, not migrated to `app_ru.arb`.

## Worked example: `customer_list_page.dart` (fully resolved, use as the template)

This file already partially uses `AppLocalizations` (`l10n.back`,
`l10n.a11yAddClient` — reuse the same `final l10n =
AppLocalizations.of(context)!;` binding already declared in `build()`).
Confirmed via `grep` against the current `app_ru.arb`:

| String | Decision |
|---|---|
| `'Отмена'` | reuse existing `cancel` |
| `'Добавить'` | reuse existing (check `add`/`createButton`-style key — several exist, pick the one already used for a same-meaning "confirm add" action elsewhere) |
| `'Клиентов пока нет'` | new: `customerListEmptyTitle` |
| `'Добавьте первого клиента, чтобы отслеживать продажи и долги'` | new: `customerListEmptySubtitle` |
| `'Добавить клиента'` | new: `customerListEmptyButton` (distinct from the generic add-button reuse above — this is empty-state CTA copy, worth its own key per the "state explicitly how they differ" rule if it ends up textually identical to another `add`-flavored key) |
| `'Нет клиентов по этому фильтру'` | new: `customerListFilterEmptyTitle` |
| `'Попробуйте выбрать другой фильтр'` | new: `customerListFilterEmptySubtitle` (check for reuse against any other list page's identical filter-empty-state copy first — if `supplier_list_page.dart` or `product_list_page.dart` already migrated the same phrase, reuse that key instead) |
| `'Сбросить фильтр'` | new: `customerListResetFilterButton` (same reuse check as above) |
| `'Новый клиент'` (dialog title) | new: `customerListAddDialogTitle` |
| `'Имя'` | reuse existing generic name-field label if one exists (check `itemName`/similar first — likely needs its own `customerNameLabel` if the existing `itemName` key's description ties it specifically to products) |
| `'Введите имя клиента'` | new: `customerListNameHint` |
| `'Телефон'` | reuse existing `phoneLabel` |
| `'Клиенты'` (header) | new: `customerListTitle` |
| `'Поиск клиента'` | new: `customerListSearchHint` |
| `'Все'` / `'С долгом'` / `'VIP'` / `'Новые'` (filter chips) | `'Все'` likely reuses an existing generic `all` key if present; the other three are customer-filter-specific — `customerListFilterDebt`, `customerListFilterVip`, `customerListFilterNew` |

The remaining ~4 of this file's 20 offenders are in the stats line
(`'${customers.length} клиентов  |  Долг: ...'`) and are a
label+separator+value composite — per convention, one full-sentence key
with `String` placeholders for the count and formatted debt amount, not
two bare labels manually concatenated.

The other 8 files are not pre-resolved to this level of detail in this
spec — the implementation plan gives each its own task following the
identical 7-step methodology above; exact key names are decided during
that task (per step 2-3), not fixed in advance, since several depend on
what's already in `app_ru.arb` by the time that task runs (earlier tasks
in this same project may add reusable keys later tasks should find via
step 2's grep).

## `check_i18n.dart` allow-list mechanism change

Replace the `file:line` allow-list key with `file::content` (the exact
matched Cyrillic-containing substring, not the whole line — so trailing
whitespace/indentation changes around it still match).

```dart
// Before:
final key = '$rel:${i + 1}';
// ...
if (allowlist.contains(key)) continue;

// After:
final match = cyrillicInString.firstMatch(line)!;
final content = match.group(0)!;
final key = '$rel::$content';
// ...
if (allowlist.contains(key)) continue;
```

`offenders.add(...)` and the `--dump-allowlist` write path change
identically (write `key`, not `'$rel:${i + 1}'`). Sorting/dedup logic is
unchanged — `toSet()` already collapses identical `file::content` pairs,
which is correct: two identical strings in one file only need one
allow-list entry now, where the old scheme needed one per line.

`tool/i18n-allowlist.txt` gets fully regenerated in the new format via
`--dump-allowlist` as the last step of this project (after all 9 files
are migrated, so the file only lists genuinely-still-hardcoded strings,
including the settings_page.dart language/tariff exceptions with a
comment header).

## Testing

- New unit test for `check_i18n.dart` itself
  (`tool/check_i18n_test.dart` or similar — check whether `tool/` has
  any existing test convention first): write a temp `.dart` file with a
  known Cyrillic literal, add its `file::content` key to a temp
  allow-list, assert it's silently skipped; assert an unlisted literal
  in the same temp file is still reported; assert moving the *same*
  content to a different line number in the temp file is still
  recognized as allow-listed (this is the regression test proving the
  actual bug is fixed).
- Per migrated file: `flutter analyze` clean, `dart run
  tool/check_i18n.dart` reports zero for that file, and that file's
  existing test(s) (golden/widget, wherever present) still pass
  unmodified — visible text doesn't change, only its source.
- Full suite at the end: `flutter test --reporter expanded` — no new
  failures beyond whatever pre-existing ones already exist unrelated to
  this project (e.g. the macOS-only golden tolerance gap, already
  documented as not a real CI signal).

## Out of scope

- Any file outside the 9 listed above, including the rest of
  ADR-0002 Track 2's backlog.
- tg/uz translation of the new keys — per the ADR's existing
  reconciliation note, tg/uz continue falling back to Russian for all
  keys, new and old alike; this is a standing, separate product
  decision already made, not revisited here.
- The 3 admin-panel lint findings and the delete-user "last admin"
  guard — separate items the user explicitly declined to include in
  this cycle.
