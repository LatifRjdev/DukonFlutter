# Service-layer i18n (ADR-0002 Track 2b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Localize the 56 user-facing Russian literals in `lib/core`, `lib/data` and `lib/domain`, then extend `check_i18n.dart` to scan all of `lib` so the gap cannot regrow.

**Architecture:** Any function outside `lib/presentation` that produces user-facing text takes a `required AppLocalizations l10n` parameter, resolved at the UI call site. No service stores a locale — all affected services are lazy singletons in `injection.dart`, so a captured locale would go stale on language switch.

**Tech Stack:** Flutter, `flutter_localizations` / `gen-l10n`, ARB (`app/lib/l10n/app_ru.arb`), `tool/check_i18n.dart`.

**Spec:** `docs/superpowers/specs/2026-09-30-service-layer-i18n-design.md`

---

## Deviations from the spec, already approved

1. **`Currency.symbol` stays hardcoded and gets allowlisted.** `'сом.'` is the somoni abbreviation — the same category as `'$'` and `'₽'`, which are not translatable. Localizing it would force an `l10n` parameter through `Formatters.price()` and all **32** of its call sites, which the spec did not account for. Decided 2026-09-30. Scope drops 57 → **56**.
2. **`Formatters.quantity()` is dead code** (0 call sites) and is left alone. Its `unit.displayName` use therefore needs no threading; only the 4 UI call sites of `.displayName` do.

## Reuse verified against live `app_ru.arb`

All of these were confirmed **character-exact** while writing this plan. Reuse them; do not re-mint.

| Literal | Key |
|---|---|
| `'Товар'` | `product` |
| `'Сумма'` | `amount` |
| `'Подытог'` | `subtotal` |
| `'Скидка'` | `discount` |
| `'ИТОГО'` | `totalCaps` |
| `'Оплата'` | `payment` |
| `'Оплачено'` | `paidAmount` |
| `'Сдача'` | `change` |
| `'Долг'` | `debtLabel` |
| `'Спасибо за покупку!'` | `receiptPreviewDefaultFooter` |
| `'Кол.'` (with period — PDF only) | `receiptQtyAbbrev` |
| `'Наличные'` / `'Карта'` / `'В долг'` / `'Смешанная'` | `cash` / `card` / `debt` / `paymentMixedShort` |
| `'Чек {receiptNo}'` | `transactionDetailReceiptTitle` |
| `'Доллар США'` / `'Российский рубль'` / `'Евро'` / `'Китайский юань'` | `currencyUsd` / `currencyRub` / `currencyEur` / `currencyCny` |
| `'Продукты'` / `'Одежда'` / `'Электроника'` / `'Стройматериалы'` / `'Аптека'` / `'Другое'` | `grocery` / `clothing` / `electronics` / `hardware` / `pharmacy` / `other` |
| `'шт'` / `'кг'` / `'л'` / `'уп'` | `pcs` / `kg` / `liter` / `pack` |
| `'{hours}ч {minutes}м'` | `shiftsDurationFormat` |
| `'Напоминание о долге'` | `notificationSettingsDebtReminderTitle` |

### NEAR-MISS — do not conflate

`receiptQtyAbbrev` is **`'Кол.'` with a trailing period**. `thermal_printer_service.dart:150` prints **`'Кол'` without one**. Reusing the key there would add a character to printed receipts. Mint a separate key (Task 1). Do **not** "fix" either spelling — that is a product change, not an extraction.

### Genuinely new keys (9)

`receiptQtyAbbrevShort` (`'Кол'`), `meter` (`'м'`), `receiptPointsEarnedLine`, `receiptPointsBalanceLine`, `debtReminderDueTomorrowBody`, `debtReminderDueTodayTitle`, `debtReminderDueTodayBody`, `debtReminderOverdueTitle`, `debtReminderOverdueBody`, `lowStockAlertTitle`, `lowStockAlertBody`. (11 listed; `debtReminderDueTomorrowBody` and the three due-today/overdue pairs are counted individually.)

## File structure

| File | Literals | Responsibility after the change |
|---|---:|---|
| `app/lib/l10n/app_ru.arb` | — | Source of truth; gains 11 keys |
| `app/lib/core/services/thermal_printer_service.dart` | 16 | ESC/POS receipt builder; takes `l10n` |
| `app/lib/core/services/receipt_pdf_service.dart` | 15 | PDF receipt builder; takes `l10n` |
| `app/lib/core/constants/enums.dart` | 11 | `displayName` becomes a method; `symbol` unchanged. A scan of this file reports **12** — the 12th is `'сом.'`, which Deviation 1 allowlists rather than migrates, so 11 is the correct migration count. |
| `app/lib/core/services/debt_reminder_service.dart` | 8 | Notification scheduler; takes `l10n` |
| `app/lib/data/datasources/remote/currency_remote_datasource.dart` | 4 | Drops its `_labels` map |
| `app/lib/core/services/receipt_share_service.dart` | 1 | Takes `l10n` |
| `app/lib/domain/entities/z_report.dart` | 1 | Stops pre-formatting `duration` |
| `app/tool/check_i18n.dart` | — | Scans `lib`, excluding `lib/l10n` |
| `app/tool/i18n-allowlist.txt` | — | Gains Sub-project B's 14 + `'сом.'` |

**Task order matters:** Task 1 adds every new key up front so later tasks never hit a missing getter. Task 2 (`enums.dart`) precedes the receipt tasks because they consume `displayName`.

---

### Task 1: Add all 11 new ARB keys

**Files:**
- Modify: `app/lib/l10n/app_ru.arb`

- [ ] **Step 1: Confirm none of the 11 already exists**

Run from `app/`:
```bash
for k in receiptQtyAbbrevShort meter receiptPointsEarnedLine receiptPointsBalanceLine \
         debtReminderDueTomorrowBody debtReminderDueTodayTitle debtReminderDueTodayBody \
         debtReminderOverdueTitle debtReminderOverdueBody lowStockAlertTitle lowStockAlertBody; do
  printf '%s: ' "$k"; grep -c "\"$k\"" lib/l10n/app_ru.arb
done
```
Expected: `0` for all eleven.

- [ ] **Step 2: Add the keys**

Add `receiptQtyAbbrevShort` immediately after the existing `"@receiptQtyAbbrev"` line, and `meter` immediately after `"liter"`:

```json
  "receiptQtyAbbrevShort": "Кол",
  "@receiptQtyAbbrevShort": { "description": "Quantity column header on the thermal (ESC/POS) receipt, with NO trailing period — distinct from `receiptQtyAbbrev` (\"Кол.\", with a period) used on the PDF receipt and in the on-screen receipt widget. The two differ by one character in the existing product copy; do not merge them without a deliberate product decision, since either change alters printed output." },
  "meter": "м",
  "@meter": { "description": "Metre unit abbreviation for ProductUnit.m — sibling of `pcs`, `kg`, `liter`, `pack`." },
```

Add the receipt loyalty lines next to `receiptPreviewDefaultFooter`:

```json
  "receiptPointsEarnedLine": "Начислено баллов: +{points}",
  "@receiptPointsEarnedLine": {
    "description": "Printed-receipt line showing loyalty points earned on this sale; points is pre-formatted at the call site.",
    "placeholders": { "points": { "type": "String" } }
  },
  "receiptPointsBalanceLine": "Ваш баланс: {points} баллов",
  "@receiptPointsBalanceLine": {
    "description": "Printed-receipt line showing the customer's loyalty balance after this sale.",
    "placeholders": { "points": { "type": "String" } }
  },
```

Add the notification block after `notificationSettingsDebtReminderSubtitle`:

```json
  "debtReminderDueTomorrowBody": "{customer} должен {amount}. Срок оплаты завтра.",
  "@debtReminderDueTomorrowBody": {
    "description": "Push notification body sent the day before a debt is due. amount is pre-formatted via Formatters.price, so it already carries the currency abbreviation.",
    "placeholders": { "customer": { "type": "String" }, "amount": { "type": "String" } }
  },
  "debtReminderDueTodayTitle": "Срок оплаты долга",
  "debtReminderDueTodayBody": "{customer} должен {amount}. Срок оплаты сегодня!",
  "@debtReminderDueTodayBody": {
    "description": "Push notification body sent on the day a debt falls due.",
    "placeholders": { "customer": { "type": "String" }, "amount": { "type": "String" } }
  },
  "debtReminderOverdueTitle": "Просроченный долг",
  "debtReminderOverdueBody": "{customer}: просрочен долг {amount}.",
  "@debtReminderOverdueBody": {
    "description": "Push notification body sent once a debt is past due.",
    "placeholders": { "customer": { "type": "String" }, "amount": { "type": "String" } }
  },
  "lowStockAlertTitle": "Мало товара на складе",
  "lowStockAlertBody": "{product}: осталось {quantity}",
  "@lowStockAlertBody": {
    "description": "Push notification body for the low-stock alert. quantity is pre-formatted at the call site and already includes the unit abbreviation.",
    "placeholders": { "product": { "type": "String" }, "quantity": { "type": "String" } }
  },
```

Note `debtReminderDueTomorrowBody` reuses the existing `notificationSettingsDebtReminderTitle` (`'Напоминание о долге'`) for its *title*, so no new title key is needed for that first case.

- [ ] **Step 3: Validate and regenerate**

Run from `app/`:
```bash
python3 -c "import json;json.load(open('lib/l10n/app_ru.arb',encoding='utf-8'));print('valid')"
flutter gen-l10n
flutter analyze
```
Expected: `valid`, gen-l10n silent, `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add app/lib/l10n/app_ru.arb app/lib/l10n/app_localizations*.dart app/l10n_untranslated.json
git commit -m "feat(l10n): add 11 keys for the service layer"
```

---

### Task 2: `enums.dart` — displayName getters become methods

**Files:**
- Modify: `app/lib/core/constants/enums.dart`
- Modify: `app/lib/core/utils/formatters.dart:38,40`
- Modify: `app/lib/presentation/pages/product/product_list_page.dart:392`
- Modify: `app/lib/presentation/pages/product/product_detail_page.dart:62`
- Modify: `app/lib/presentation/pages/stock/stock_intake_page.dart:485`
- Modify: `app/lib/presentation/pages/store/create_store_page.dart:77`

11 literals: 6 `StoreCategory` + 5 `ProductUnit`. `Currency.symbol` is **not** touched (see Deviations).

- [ ] **Step 1: Verify the reuse targets**

Run from `app/`:
```bash
python3 - <<'PY'
import json
d=json.loads(open('lib/l10n/app_ru.arb',encoding='utf-8').read())
for k,v in {'grocery':'Продукты','clothing':'Одежда','electronics':'Электроника',
            'hardware':'Стройматериалы','pharmacy':'Аптека','other':'Другое',
            'pcs':'шт','kg':'кг','liter':'л','meter':'м','pack':'уп'}.items():
    assert d.get(k)==v, (k, d.get(k), v)
print('all 11 reuse targets exact')
PY
```
Expected: `all 11 reuse targets exact`

- [ ] **Step 2: Convert both extensions to methods**

In `app/lib/core/constants/enums.dart`, add the import and replace the two `displayName` getters. Leave `CurrencyExtension` exactly as it is.

```dart
import 'package:dukonpro/l10n/app_localizations.dart';
```

```dart
extension StoreCategoryExtension on StoreCategory {
  String displayName(AppLocalizations l10n) {
    switch (this) {
      case StoreCategory.grocery: return l10n.grocery;
      case StoreCategory.clothing: return l10n.clothing;
      case StoreCategory.electronics: return l10n.electronics;
      case StoreCategory.hardware: return l10n.hardware;
      case StoreCategory.pharmacy: return l10n.pharmacy;
      case StoreCategory.other: return l10n.other;
    }
  }
}

extension ProductUnitExtension on ProductUnit {
  String displayName(AppLocalizations l10n) {
    switch (this) {
      case ProductUnit.pcs: return l10n.pcs;
      case ProductUnit.kg: return l10n.kg;
      case ProductUnit.l: return l10n.liter;
      case ProductUnit.m: return l10n.meter;
      case ProductUnit.pack: return l10n.pack;
    }
  }
}
```

- [ ] **Step 3: Update the 4 UI call sites**

| File:line | Find | Replace with |
|---|---|---|
| `product_list_page.dart:392` | `unitName = productUnit.displayName;` | `unitName = productUnit.displayName(l10n);` |
| `product_detail_page.dart:62` | `unitName = productUnit.displayName;` | `unitName = productUnit.displayName(l10n);` |
| `stock_intake_page.dart:485` | `return productUnit.displayName;` | `return productUnit.displayName(AppLocalizations.of(context)!);` |
| `create_store_page.dart:77` | `label: cat.displayName,` | `label: cat.displayName(AppLocalizations.of(context)!),` |

Before editing each, confirm an `l10n` local is already in scope in that method; if not, use `AppLocalizations.of(context)!` as shown. All four files already import `AppLocalizations` (Track 2), so no new imports are needed — verify with `grep -l app_localizations` on each.

- [ ] **Step 4: Handle the dead `Formatters.quantity`**

`Formatters.quantity()` has **0 call sites**, so it cannot take an `l10n` parameter from anywhere. Delete it rather than leave a function that will not compile:

```bash
grep -rn 'Formatters\.quantity' lib test --include='*.dart' | wc -l   # must print 0
```
If it prints `0`, delete the `quantity` method (lines ~36-41) from `app/lib/core/utils/formatters.dart`. If it prints anything else, stop and report — the plan's assumption is wrong.

- [ ] **Step 5: Verify**

Run from `app/`:
```bash
flutter analyze
flutter test test/presentation/pages/product/ test/presentation/pages/stock/ test/presentation/pages/store/ --reporter expanded
```
Expected: `No issues found!`, all tests pass. Values are byte-identical so no golden may move.

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/constants/enums.dart app/lib/core/utils/formatters.dart \
        app/lib/presentation/pages/product/product_list_page.dart \
        app/lib/presentation/pages/product/product_detail_page.dart \
        app/lib/presentation/pages/stock/stock_intake_page.dart \
        app/lib/presentation/pages/store/create_store_page.dart
git commit -m "fix(app): localize StoreCategory and ProductUnit display names"
```

---

### Task 3: `thermal_printer_service.dart` (16 literals)

**Files:**
- Modify: `app/lib/core/services/thermal_printer_service.dart`
- Modify: `app/lib/presentation/pages/pos/receipt_preview_page.dart:49`
- Modify: `app/lib/presentation/pages/pos/sale_success_page.dart:81`
- Test: `app/test/core/services/thermal_printer_service_test.dart`

- [ ] **Step 1: Thread `l10n` through the four methods**

Add `import 'package:dukonpro/l10n/app_localizations.dart';`. Add `required AppLocalizations l10n` to the parameter lists of `printReceipt` (line 49), `buildReceiptBytesForTest` (105) and `_buildReceiptBytes` (120), and change `_paymentTypeName(String type)` (216) to `_paymentTypeName(String type, AppLocalizations l10n)`. Pass `l10n` down at each internal call: `printReceipt` → `_buildReceiptBytes`, `buildReceiptBytesForTest` → `_buildReceiptBytes`, `_buildReceiptBytes` → `_paymentTypeName`.

**Do not touch `testPrint()` (lines 74-104)** — it has zero Cyrillic and is the only path `PrinterBloc` uses. Keeping it parameter-free is what avoids dragging deferred Track 3 work into this task.

- [ ] **Step 2: Replace the 16 literals**

| Line | Find | Replace with |
|---|---|---|
| 149 | `PosColumn(text: 'Товар', width: 6,` | `PosColumn(text: l10n.product, width: 6,` |
| 150 | `PosColumn(text: 'Кол', width: 2,` | `PosColumn(text: l10n.receiptQtyAbbrevShort, width: 2,` |
| 151 | `PosColumn(text: 'Сумма', width: 4,` | `PosColumn(text: l10n.amount, width: 4,` |
| 165 | `PosColumn(text: 'Подытог', width: 6),` | `PosColumn(text: l10n.subtotal, width: 6),` |
| 170 | `PosColumn(text: 'Скидка', width: 6),` | `PosColumn(text: l10n.discount, width: 6),` |
| 175 | `PosColumn(text: 'ИТОГО', width: 6,` | `PosColumn(text: l10n.totalCaps, width: 6,` |
| 182 | `PosColumn(text: 'Оплата', width: 6),` | `PosColumn(text: l10n.payment, width: 6),` |
| 186 | `PosColumn(text: 'Оплачено', width: 6),` | `PosColumn(text: l10n.paidAmount, width: 6),` |
| 191 | `PosColumn(text: 'Сдача', width: 6),` | `PosColumn(text: l10n.change, width: 6),` |
| 199 | `'Начислено баллов: +${sale.pointsEarned}',` | `l10n.receiptPointsEarnedLine(sale.pointsEarned.toString()),` |
| 203 | `'Ваш баланс: ${sale.pointsBalance} баллов',` | `l10n.receiptPointsBalanceLine(sale.pointsBalance.toString()),` |
| 209 | `generator.text('Спасибо за покупку!', styles:` | `generator.text(l10n.receiptPreviewDefaultFooter, styles:` |
| 218 | `case 'CASH': return 'Наличные';` | `case 'CASH': return l10n.cash;` |
| 219 | `case 'CARD': return 'Карта';` | `case 'CARD': return l10n.card;` |
| 220 | `case 'DEBT': return 'В долг';` | `case 'DEBT': return l10n.debt;` |
| 221 | `case 'MIXED': return 'Смешанная';` | `case 'MIXED': return l10n.paymentMixedShort;` |

Note line 150 uses the **new** `receiptQtyAbbrevShort` (`'Кол'`), not `receiptQtyAbbrev` (`'Кол.'`). Getting this wrong adds a period to every printed receipt.

- [ ] **Step 3: Update the two UI call sites**

Both are `State` methods with a context in scope.

- `receipt_preview_page.dart:49` — add `l10n: l10n,` to the `printReceipt(...)` argument list (the method already binds `l10n`; verify with `grep -n 'final l10n' receipt_preview_page.dart`, and if absent bind `final l10n = AppLocalizations.of(context)!;` at the top of `_printReceipt`).
- `sale_success_page.dart:81` — same, inside `_printReceipt()`.

- [ ] **Step 4: Give the service test a localizations instance**

In `app/test/core/services/thermal_printer_service_test.dart`, add:

```dart
import 'package:flutter/widgets.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
```

```dart
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
  });
```

Then pass `l10n: l10n` at every `buildReceiptBytesForTest(...)` / `printReceipt(...)` call in the file. **Leave the Tajik-character assertions unchanged** (`'Чойи сабз ҳамчун ёд'`, `'Дӯкон'`) — they test CP1251 encoding, not localization, and must keep passing.

- [ ] **Step 5: Verify**

Run from `app/`:
```bash
flutter analyze
flutter test test/core/services/thermal_printer_service_test.dart test/presentation/pages/pos/ --reporter expanded
python3 -c "
import re,pathlib
n=sum(1 for l in pathlib.Path('lib/core/services/thermal_printer_service.dart').read_text(encoding='utf-8').splitlines()
      if re.search(r'[Ѐ-ԯ]', l.split('//')[0]) and not l.strip().startswith('//'))
print('remaining Cyrillic literals:', n)"
```
Expected: `No issues found!`, all tests pass, `remaining Cyrillic literals: 0`

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/services/thermal_printer_service.dart \
        app/lib/presentation/pages/pos/receipt_preview_page.dart \
        app/lib/presentation/pages/pos/sale_success_page.dart \
        app/test/core/services/thermal_printer_service_test.dart
git commit -m "fix(app): localize thermal printer receipt strings"
```

---

### Task 4: `receipt_pdf_service.dart` (15 literals)

**Files:**
- Modify: `app/lib/core/services/receipt_pdf_service.dart`
- Modify: `app/lib/core/services/receipt_share_service.dart`
- Modify: `app/lib/presentation/pages/pos/receipt_preview_page.dart:28`
- Test: `app/test/core/services/receipt_pdf_service_test.dart`

Bundled with `receipt_share_service.dart` (1 literal) because `ReceiptShareService` wraps `ReceiptPdfService` and both call sites sit in the same UI method.

- [ ] **Step 1: Thread `l10n` through**

Add the `AppLocalizations` import. Add `required AppLocalizations l10n` to `generateReceipt` (line 28) and change `_paymentTypeName(String type)` (line ~134) to take `(String type, AppLocalizations l10n)`. `_totalRow` takes pre-resolved strings already, so its signature is unchanged.

In `receipt_share_service.dart`, add `required AppLocalizations l10n` to `shareReceipt` and pass it into `generateReceipt`.

- [ ] **Step 2: Replace the 15 literals**

| Line | Find | Replace with |
|---|---|---|
| 67 | `pw.Text('Товар', style: smallBold)` | `pw.Text(l10n.product, style: smallBold)` |
| 68 | `pw.Text('Кол.', style: smallBold,` | `pw.Text(l10n.receiptQtyAbbrev, style: smallBold,` |
| 69 | `pw.Text('Сумма', style: smallBold,` | `pw.Text(l10n.amount, style: smallBold,` |
| 85 | `_totalRow('Подытог',` | `_totalRow(l10n.subtotal,` |
| 87 | `_totalRow('Скидка',` | `_totalRow(l10n.discount,` |
| 89 | `_totalRow('ИТОГО',` | `_totalRow(l10n.totalCaps,` |
| 93 | `_totalRow('Оплата', _paymentTypeName(sale.paymentType), regular)` | `_totalRow(l10n.payment, _paymentTypeName(sale.paymentType, l10n), regular)` |
| 94 | `_totalRow('Оплачено',` | `_totalRow(l10n.paidAmount,` |
| 96 | `_totalRow('Сдача',` | `_totalRow(l10n.change,` |
| 98 | `_totalRow('Долг',` | `_totalRow(l10n.debtLabel,` |
| 100 | `pw.Text('Спасибо за покупку!', style: regular,` | `pw.Text(l10n.receiptPreviewDefaultFooter, style: regular,` |
| 135 | `case 'CASH': return 'Наличные';` | `case 'CASH': return l10n.cash;` |
| 136 | `case 'CARD': return 'Карта';` | `case 'CARD': return l10n.card;` |
| 137 | `case 'DEBT': return 'В долг';` | `case 'DEBT': return l10n.debt;` |
| 138 | `case 'MIXED': return 'Смешанная';` | `case 'MIXED': return l10n.paymentMixedShort;` |

Line 68 uses `receiptQtyAbbrev` (**with** the period) — the opposite of Task 3's line 150. That asymmetry is intentional and mirrors the existing product copy.

In `receipt_share_service.dart:33`, replace `subject: 'Чек ${sale.receiptNo}',` with `subject: l10n.transactionDetailReceiptTitle(sale.receiptNo.toString()),`.

- [ ] **Step 3: Update the UI call site**

`receipt_preview_page.dart:28` calls `sl<ReceiptShareService>().shareReceipt(...)` — add `l10n: l10n`, binding `final l10n = AppLocalizations.of(context)!;` in that method if not already present.

- [ ] **Step 4: Give the PDF service test a localizations instance**

Same `setUpAll` block as Task 3, Step 4, in `app/test/core/services/receipt_pdf_service_test.dart`; pass `l10n: l10n` at each `generateReceipt(...)` call. Keep its Tajik-character test unchanged.

- [ ] **Step 5: Verify**

```bash
flutter analyze
flutter test test/core/services/ test/presentation/pages/pos/ --reporter expanded
python3 -c "
import re,pathlib
for f in ['lib/core/services/receipt_pdf_service.dart','lib/core/services/receipt_share_service.dart']:
    n=sum(1 for l in pathlib.Path(f).read_text(encoding='utf-8').splitlines()
          if re.search(r'[Ѐ-ԯ]', l.split('//')[0]) and not l.strip().startswith('//'))
    print(f, 'remaining:', n)"
```
Expected: clean analyze, tests pass, `remaining: 0` for both.

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/services/receipt_pdf_service.dart \
        app/lib/core/services/receipt_share_service.dart \
        app/lib/presentation/pages/pos/receipt_preview_page.dart \
        app/test/core/services/receipt_pdf_service_test.dart
git commit -m "fix(app): localize PDF receipt and share strings"
```

---

### Task 5: `debt_reminder_service.dart` (8 literals)

**Files:**
- Modify: `app/lib/core/services/debt_reminder_service.dart`

This service is registered in `injection.dart` but **never resolved** — it has no callers. Migrating it anyway is deliberate: zero regression risk, and it leaves the service correct for whoever wires it up.

- [ ] **Step 1: Confirm it still has no callers**

```bash
grep -rn 'DebtReminderService\|scheduleDebtReminder\|showLowStockAlert' lib test --include='*.dart' \
  | grep -v 'core/services/debt_reminder_service.dart'
```
Expected: only the two `injection.dart` registration lines. If a real caller appears, add `l10n` there too and note it.

- [ ] **Step 2: Add `l10n` and replace the 8 literals**

Add the `AppLocalizations` import plus `import '../utils/formatters.dart';`. Add `required AppLocalizations l10n` to `scheduleDebtReminder` (line 9) and `showLowStockAlert` (line 51).

The bodies currently interpolate a raw amount and a hardcoded `'сом.'`. Format via `Formatters.price`, which supplies the currency abbreviation — removing two more hardcoded duplicates:

| Line | Find | Replace with |
|---|---|---|
| 22 | `title: 'Напоминание о долге',` | `title: l10n.notificationSettingsDebtReminderTitle,` |
| 23 | `body: '$customerName должен ${debtAmount.toStringAsFixed(2)} сом. Срок оплаты завтра.',` | `body: l10n.debtReminderDueTomorrowBody(customerName, Formatters.price(debtAmount)),` |
| 33 | `title: 'Срок оплаты долга',` | `title: l10n.debtReminderDueTodayTitle,` |
| 34 | `body: '$customerName должен ${debtAmount.toStringAsFixed(2)} сом. Срок оплаты сегодня!',` | `body: l10n.debtReminderDueTodayBody(customerName, Formatters.price(debtAmount)),` |
| 44 | `title: 'Просроченный долг',` | `title: l10n.debtReminderOverdueTitle,` |
| 45 | `body: '$customerName: просрочен долг ${debtAmount.toStringAsFixed(2)} сом.',` | `body: l10n.debtReminderOverdueBody(customerName, Formatters.price(debtAmount)),` |
| 58 | `title: 'Мало товара на складе',` | `title: l10n.lowStockAlertTitle,` |
| 59 | `body: '$productName: осталось $currentQuantity шт.',` | `body: l10n.lowStockAlertBody(productName, '$currentQuantity ${ProductUnit.pcs.displayName(l10n)}'),` |

Line 59 also needs `import '../constants/enums.dart';`. Note this changes the rendered text from `'... шт.'` to `'... шт'` — the unit key has no trailing period. Flag it in the commit message: it is a one-character change in a notification that currently has no callers, so nothing user-visible regresses.

- [ ] **Step 3: Verify**

```bash
flutter analyze
python3 -c "
import re,pathlib
n=sum(1 for l in pathlib.Path('lib/core/services/debt_reminder_service.dart').read_text(encoding='utf-8').splitlines()
      if re.search(r'[Ѐ-ԯ]', l.split('//')[0]) and not l.strip().startswith('//'))
print('remaining:', n)"
```
Expected: `No issues found!`, `remaining: 0`

- [ ] **Step 4: Commit**

```bash
git add app/lib/core/services/debt_reminder_service.dart
git commit -m "fix(app): localize debt reminder notification strings"
```

---

### Task 6: `currency_remote_datasource.dart` (4) + `z_report.dart` (1)

**Files:**
- Modify: `app/lib/data/datasources/remote/currency_remote_datasource.dart:27`
- Modify: `app/lib/domain/entities/z_report.dart:70`
- Modify: whichever UI renders `CurrencyRate.label` and `ZReport.duration` (enumerate in Step 1)

- [ ] **Step 1: Enumerate the consumers before changing either contract**

```bash
grep -rn '\.label' lib/presentation --include='*.dart' | grep -i curren
grep -rn '\.duration' lib/presentation --include='*.dart' | grep -i 'zreport\|z_report\|report'
```
Record every hit. Both changes alter a model's shape, so a missed consumer is a compile error — which is safe, but enumerate anyway so the edits are deliberate.

- [ ] **Step 2: Drop the `_labels` map**

`static const _labels = {...}` cannot call `AppLocalizations.of`. Remove it and the `label:` it feeds, so `CurrencyRate` carries only `code` (and `flag`, which is emoji and needs no localization). Resolve the display name at the render site with a switch mirroring `enums.dart`:

```dart
String currencyLabel(AppLocalizations l10n, String code) {
  switch (code) {
    case 'USD': return l10n.currencyUsd;
    case 'RUB': return l10n.currencyRub;
    case 'EUR': return l10n.currencyEur;
    case 'CNY': return l10n.currencyCny;
    default: return code;
  }
}
```

Place it on the widget that renders the rate list, next to its existing `_currencyLabel` if Task 24 of Track 2 already added one — in which case reuse that instead of adding a second.

- [ ] **Step 3: Stop pre-formatting `ZReport.duration`**

`z_report.dart:70` builds `duration: '${diff.inHours}ч ${diff.inMinutes % 60}м'`. Replace the `String duration` field with the two numbers and let the UI format via the existing `shiftsDurationFormat`:

```dart
  final int durationHours;
  final int durationMinutes;
```
```dart
      durationHours: diff.inHours,
      durationMinutes: diff.inMinutes % 60,
```

At the render site:
```dart
l10n.shiftsDurationFormat(report.durationHours.toString(), report.durationMinutes.toString())
```

- [ ] **Step 4: Verify**

```bash
flutter analyze
flutter test test/presentation/pages/finance/ test/presentation/pages/shifts/ --reporter expanded
```
Expected: `No issues found!`; the only acceptable failures are the documented baseline goldens for `currencies_page` (light+dark).

- [ ] **Step 5: Commit**

```bash
git add app/lib/data/datasources/remote/currency_remote_datasource.dart \
        app/lib/domain/entities/z_report.dart app/lib/presentation
git commit -m "fix(app): localize currency names and Z-report duration"
```

---

### Task 7: Extend the linter to all of `lib`

**Files:**
- Modify: `app/tool/check_i18n.dart`
- Modify: `app/tool/i18n-allowlist.txt`
- Test: `app/test/tool/check_i18n_test.dart`

- [ ] **Step 1: Write the failing regression test**

Add to `app/test/tool/check_i18n_test.dart`. It must fail now (the scanner ignores `lib/core`) and pass after Step 3.

```dart
  test('a hardcoded literal in lib/core is flagged, not just lib/presentation', () async {
    // Regression guard for the scan root. Before this, check_i18n only walked
    // lib/presentation, so every string in lib/core, lib/data and lib/domain
    // was invisible — which is how 71 user-facing literals survived Track 2.
    Directory('${tempDir.path}/lib/core/services').createSync(recursive: true);
    File('${tempDir.path}/lib/core/services/sample_service.dart')
        .writeAsStringSync("const msg = 'Ошибка сервера';\n");
    File('${tempDir.path}/tool/i18n-allowlist.txt').writeAsStringSync('');

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 1, reason: 'lib/core must be in scope');
  });

  test('generated localizations under lib/l10n are not scanned', () async {
    // lib/l10n/app_localizations_ru.dart is entirely Russian by definition;
    // scanning it would produce thousands of false positives.
    Directory('${tempDir.path}/lib/l10n').createSync(recursive: true);
    File('${tempDir.path}/lib/l10n/app_localizations_ru.dart')
        .writeAsStringSync("String get save => 'Сохранить';\n");
    File('${tempDir.path}/tool/i18n-allowlist.txt').writeAsStringSync('');

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 0, reason: 'lib/l10n must be excluded');
  });
```

- [ ] **Step 2: Run them and confirm the first fails**

```bash
flutter test test/tool/check_i18n_test.dart --reporter expanded
```
Expected: `lib/core must be in scope` FAILS (returns 0, expected 1); the `lib/l10n` test passes incidentally because nothing is scanned yet. A guard that passes before the fix is worthless — if the first test passes here, stop and work out why.

- [ ] **Step 3: Change the scan root**

In `app/tool/check_i18n.dart`, replace the `lib/presentation` directory with `lib` and skip `lib/l10n`:

```dart
  final scanRoot = Directory('$repoRoot/lib');
  if (!scanRoot.existsSync()) {
    stderr.writeln('lib not found — run from app/ directory');
    return 2;
  }
```
In the `await for` loop, immediately after the `.dart` check:
```dart
    // lib/l10n holds gen-l10n output, including app_localizations_ru.dart,
    // which is Russian by definition. Scanning it is meaningless noise.
    if (rel.startsWith('lib/l10n/')) continue;
```
Note `rel` is currently computed after the `scanned++`; move `scanned++` below this skip so the count reflects files actually scanned.

- [ ] **Step 4: Run the tests again**

```bash
flutter test test/tool/check_i18n_test.dart --reporter expanded
```
Expected: all tests pass, including the two new ones.

- [ ] **Step 5: Seed Sub-project B's literals and `'сом.'` into the allowlist**

Run `dart run tool/check_i18n.dart` — it will now report the 14 error-path literals plus `'сом.'`. Add them under a new block in `app/tool/i18n-allowlist.txt`, preserving the existing comment structure:

```
# ---------------------------------------------------------------------------
# 3. Sub-project B — the error path (deferred by design)
# ---------------------------------------------------------------------------
# error_messages.dart's mapErrorToUserMessage has 124 call sites across 29
# Bloc files, and its result lands in state objects ~66 UI sites read as
# .message. Converting it to error codes is an architectural change, specced
# separately. debt_repository_impl.dart's literals are exception constructor
# arguments that mapErrorToUserMessage never reads (it dispatches on type and
# HTTP status), so they must move with the mechanism, not ahead of it.
```
```
# ---------------------------------------------------------------------------
# 4. Currency abbreviation — not translatable
# ---------------------------------------------------------------------------
# 'сом.' is the somoni abbreviation, the same category as '$' and '₽'.
# Localizing it would thread AppLocalizations through Formatters.price and its
# 32 call sites for no translation benefit. Decided 2026-09-30.
lib/core/constants/enums.dart::'сом.'
```

Add the 14 error-path entries verbatim from the lint output under block 3.

- [ ] **Step 6: Verify, including non-vacuity**

```bash
dart run tool/check_i18n.dart; echo "EXIT=$?"
```
Expected: clean, `EXIT=0`.

Now prove the extended scan is real, not swallowed by the allowlist:
```bash
printf "\nconst probe = 'Проверка области сканирования';\n" >> lib/core/utils/formatters.dart
dart run tool/check_i18n.dart; echo "EXIT=$?"
git checkout lib/core/utils/formatters.dart
dart run tool/check_i18n.dart; echo "EXIT=$?"
```
Expected: `EXIT=1` naming `formatters.dart` in the middle run, `EXIT=0` either side. Run unpiped — `| tail` masks the exit code.

- [ ] **Step 7: Commit**

```bash
git add app/tool/check_i18n.dart app/tool/i18n-allowlist.txt app/test/tool/check_i18n_test.dart
git commit -m "feat(i18n): extend check_i18n to all of lib, excluding generated l10n"
```

---

### Task 8: Whole-branch verification

**Files:** none modified unless a defect is found.

- [ ] **Step 1: Lint, clean and proven non-vacuous**

```bash
dart run tool/check_i18n.dart; echo "EXIT=$?"
```
Expected: `EXIT=0`.

- [ ] **Step 2: Analyze**

```bash
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3: Confirm no Cyrillic literal survives outside `lib/presentation`**

```bash
python3 - <<'PY'
import re, pathlib
lit=re.compile(r"""(['"])((?:(?!\1)[^\\]|\\.)*?[Ѐ-ԯ](?:(?!\1)[^\\]|\\.)*?)\1""")
allow={l.strip() for l in pathlib.Path('tool/i18n-allowlist.txt').read_text(encoding='utf-8').splitlines()
       if l.strip() and not l.startswith('#')}
bad=[]
for p in sorted(pathlib.Path('lib').rglob('*.dart')):
    rel=str(p)
    if rel.startswith('lib/presentation/') or rel.startswith('lib/l10n/'): continue
    for line in p.read_text(encoding='utf-8').splitlines():
        s=line.strip()
        if s.startswith('//') or s.startswith('///'): continue
        for m in lit.finditer(line.split('//')[0]):
            if f'{rel}::{m.group(0)}' not in allow: bad.append((rel, m.group(0)))
print('unallowlisted literals outside lib/presentation:', len(bad))
for b in bad[:20]: print('  ', b)
PY
```
Expected: `0`.

- [ ] **Step 4: gen-l10n idempotency**

```bash
flutter gen-l10n && git status --short
```
Expected: empty output — no generated file was hand-edited.

- [ ] **Step 5: Full test suite against the documented baseline**

```bash
flutter test 2>&1 | grep -oE '[a-zA-Z_]+_test\.dart: [^\[]*\[E\]' | sed 's/ *\[E\]//' | sort -u
```
Expected: exactly the 18 known macOS golden failures — finance `balance_page`/`credits_page`/`currencies_page`/`reports_page`; delivery `create_delivery_page`/`delivery_detail_page`/`delivery_list_page` (loading/error variants); settings `discounts_page`/`my_stores_page` — light and dark each. **Compare the sorted set, never the count.** Any new name is a regression; investigate rather than regenerate a golden.

- [ ] **Step 6: Commit only if something needed fixing**

If Steps 1-5 are all clean, there is nothing to commit and this task ends. Otherwise fix the defect, re-run Steps 1-5, and commit with a message naming what was wrong.

---

## Notes for the executor

- **Values must stay byte-identical.** That property is what keeps the goldens meaningful. Two deliberate exceptions, both flagged in their tasks: `debt_reminder_service.dart:59` loses a trailing period on the unit abbreviation (no callers, so nothing user-visible changes), and `ZReport.duration` changes shape rather than text.
- **Verify every reuse, even the ones this plan lists as confirmed.** They were checked while writing, but the ARB moves. The highest-risk mistake is a key whose Russian matches but whose meaning does not — Track 2 hit that repeatedly (`paid` the payroll status vs `paidAmount` the receipt row). Check the existing key's `@description` and call sites, not just its value.
- **The two `'Кол'` / `'Кол.'` keys are deliberately different.** Thermal has no period, PDF does. Do not normalize them.
- **Do not regenerate any golden.** If one moves, a value is wrong.
