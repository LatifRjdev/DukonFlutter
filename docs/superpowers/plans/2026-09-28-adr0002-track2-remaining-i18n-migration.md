# ADR-0002 Track 2 Remaining i18n Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate every remaining hardcoded Cyrillic string literal in `app/lib/presentation/` (61 files, 772 offender strings) to `AppLocalizations`, completing ADR-0002 Track 2 except for the 6 Bloc files deferred as Track 3.

**Architecture:** Same mechanism as the already-merged 9-file migration project: for each file, grep `tool/i18n-allowlist.txt` for exact offenders, grep `app_ru.arb` for reusable existing keys (verifying values match character-for-character before reusing — this is the single most important discipline in this plan, given two real bugs already shipped from skipping it), mint new keys only when no match exists, regenerate via `flutter gen-l10n`, replace literals, verify with `check_i18n.dart`/`flutter analyze`/`flutter test`, commit. 18 large files get individual tasks; 43 small files are grouped into 10 multi-file bundle tasks (one implementer, one review, one commit per bundle). A final task regenerates the allow-list and runs full verification.

**Tech Stack:** Flutter/Dart, `flutter gen-l10n`, ARB (`app_ru.arb`), the project's own `tool/check_i18n.dart` lint script.

**Full design context:** `docs/superpowers/specs/2026-09-28-adr0002-track2-remaining-i18n-migration-design.md`

---

## Conventions applied uniformly across every task below

- **`.claude/rules/mobile-l10n.md`**: `app_ru.arb` is the template locale; never hand-edit generated `app_localizations*.dart`; keys live in contiguous feature-prefix blocks; reuse an existing key when the *meaning* matches regardless of render location; grep the ARB before minting; label+separator+value composites get one full-sentence key; `@key` descriptions for non-obvious/near-duplicate keys; placeholders are always `String`-typed, pre-formatted at the call site (never `int`/`num`/ICU plural).
- **Mandatory value verification before reuse.** Every task confirms a candidate reused key's ARB value matches character-for-character before using it. This branch's predecessor shipped two real bugs (`f54d5fd`, `bb6a1cc`) from skipping this check — every task below explicitly calls out near-miss traps it found and avoided.
- **`check_i18n.dart`'s one-match-per-line blind spot.** The tool's regex only flags the *first* Cyrillic-quoted literal per source line. Several tasks below found and fixed genuine second-literal-on-the-same-line offenders that never appeared in the official allow-list count — these are called out explicitly wherever found; don't assume the allow-list dump is exhaustive.
- **Golden-test pre-existing-failure verification.** `test/flutter_test_config.dart` gives Linux CI 100% tolerance vs. ~0.2% on macOS — a local golden mismatch is not automatically a regression. When a golden test fails after a migration, verify via a throwaway `git worktree` at the parent commit (created outside this project's own worktree, removed after) whether the same failure pre-exists there.
- **Two-stage review per task** (spec-compliance, then code-quality), dispatched via subagent-driven-development. For bundled tasks, review covers all files in that bundle together (one spec-compliance + one code-quality pass per bundle, not per file).
- **Orchestrator fixes small, well-scoped review findings directly** rather than re-dispatching an implementer for a one-line fix (established pattern from the prior project).
- **Cross-task ARB coordination.** Several tasks below explicitly flag a key minted in one task and reused by a later one (e.g. `margin` in Task 2 reused by Task 3; `debtLabel`-style shared keys between Tasks 11/12; `unknownStaffLabel` and `acceptDebtPayment` shared within Tasks 25/26's own bundles). The **final whole-branch review** (after Task 29) must specifically re-check for cross-task ARB key duplication — this is the single biggest risk at this project's scale (29 independently-dispatched tasks each doing their own live ARB grep against a moving target).
- **`settings_page.dart`'s 6 proper-noun exceptions are out of scope** — already handled in the prior project, left untouched. Task 1 and Task 20 below extend the same proper-noun precedent to newly-discovered cases (tariff names recurring in `subscription_page.dart`, language names recurring in `language_settings_page.dart`) — each documented with its own allow-list comment block.
- **The 6 Bloc files (Track 3) are explicitly out of scope** for this plan — deferred to a future, separate design (per the approved spec).

---

### Task 1: Migrate `subscription_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/settings/subscription_page.dart`
- Modify: `tool/i18n-allowlist.txt` (add deliberate proper-noun exceptions — see Step 1)

Current offenders (all 61, verbatim):
```
35:    label: 'Старт',
36:    price: '49 TJS/мес',
38:      '1 магазин',
39:      '500 товаров',
40:      '2 сотрудника',
41:      'Отчёт продаж',
42:      'Валюты',
47:    label: 'Бизнес',
48:    price: '149 TJS/мес',
50:      '3 магазина',
51:      '2000 товаров',
52:      '10 сотрудников',
53:      'Все отчёты',
54:      'Telegram-бот',
55:      'Доставки',
56:      'Инвентаризация',
57:      '5 скидок',
62:    label: 'Премиум',
63:    price: '299 TJS/мес',
65:      '5 магазинов',
66:      'Безлимит товаров/сотрудников',
67:      'Экспорт PDF/Excel',
68:      'Безлимит скидок',
69:      'Приоритетная поддержка',
120:        return 'Активна';
122:        return 'Пробный период';
124:        return 'Истекла';
126:        return 'Отменена';
181:      expiryText = 'Пробный период: осталось ${state.trialDaysLeft} дней';
184:      expiryText = 'до $formatted';
258:                'Скидка ${state.adminDiscount!.toStringAsFixed(0)}%',
287:              'Ожидает подтверждения оплаты',
354:                    'Текущий план',
376:                    child: const Text('Выбрать',
411:          'История оплат',
429:        statusLabel = 'Подтверждено';
433:        statusLabel = 'Отклонено';
437:        statusLabel = 'Ожидает';
491:                        payment.method == 'CARD' ? 'Карта' : 'Наличные',
528:        title: Text('Платёж — ${_planLabel(payment.plan)}'),
533:            Text('Сумма: ${payment.amount.toStringAsFixed(0)} TJS'),
536:                'Метод: ${payment.method == 'CARD' ? 'Перевод на карту' : 'Наличные'}'),
538:            Text('Статус: ${payment.status}'),
540:            Text('Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(payment.createdAt)}'),
543:              Text('Примечание: ${payment.adminNote}'),
547:              const Text('Чек:',
558:                    'Изображение недоступно',
569:            child: const Text('Закрыть'),
592:          title: const Text('Подписка'),
617:                        child: const Text('Повторить'),
653:                      'Тарифные планы',
713:              title: const Text('Камера'),
718:              title: const Text('Галерея'),
785:            'Оплата тарифа «${planInfo.label}»',
800:              label: 'Перевод на карту',
820:                  Text('Реквизиты для перевода',
826:                  _CardDetailRow(label: 'Получатель', value: 'DukonPro LLC'),
828:                  _CardDetailRow(label: 'Банк', value: 'Эсхата'),
854:                label: Text(_uploading ? 'Загрузка...' : 'Я перевёл — загрузить чек'),
860:              child: const Text('Назад'),
```

- [ ] **Step 1: Handle deliberate exceptions, then check for reusable existing keys**

**Proper-noun exceptions (mirror `settings_page.dart`'s Task 6 precedent from the prior project — same tariff brand names, plus one new bank name):**

`'Старт'` (lines 35, 135), `'Бизнес'` (lines 47, 137), and `'Премиум'` (lines 62, 139) are the exact same tariff/plan brand names that `settings_page.dart` already treats as deliberate, untranslated proper nouns (per that file's Task 6 comment block: "tariff names are product brand names"). Per `.claude/rules/mobile-l10n.md`'s "discriminator is the string's *meaning*, never *where it currently renders*" rule, apply the same treatment here rather than minting AppLocalizations keys for them. Add directly to `tool/i18n-allowlist.txt` (hand-append, do not use `--dump-allowlist` for these, same as the settings_page.dart precedent):

```
# Deliberate exceptions — proper nouns, not translatable UI text (see
# docs/superpowers/specs/2026-09-28-adr0002-track2-remaining-i18n-migration-design.md
# and the same precedent already established in settings_page.dart).
# Tariff names are product brand names; a bank's own name doesn't change
# with the UI locale either.
lib/presentation/pages/settings/subscription_page.dart::'Старт'
lib/presentation/pages/settings/subscription_page.dart::'Бизнес'
lib/presentation/pages/settings/subscription_page.dart::'Премиум'
lib/presentation/pages/settings/subscription_page.dart::'Эсхата'
```

`'Эсхата'` (line 828, the value in `_CardDetailRow(label: 'Банк', value: 'Эсхата')`) is a real bank name (Bank Eskhata) — also a proper noun, added above. **Note:** `'Эсхата'` is not in the 61 counted offenders — see the lint-tool blind-spot note below for why, and why it still needs handling.

**Lint-tool blind spot — same-line companions not caught by `check_i18n.dart`'s one-match-per-line regex:** two lines in this file each contain a *second* Cyrillic string literal that the tool's `firstMatch`-per-line regex never flags, because a different literal earlier on the same line already consumes the match:
- Line 828: `_CardDetailRow(label: 'Банк', value: 'Эсхата'),` — `'Банк'` is the counted offender; `'Эсхата'` is the un-counted companion (handled above as a proper-noun exception).
- Line 854: `label: Text(_uploading ? 'Загрузка...' : 'Я перевёл — загрузить чек'),` — `'Загрузка...'` is the counted offender; `'Я перевёл — загрузить чек'` is the un-counted companion. This one is ordinary translatable UI text (a button label), not a proper noun — migrate it in the same pass so the ternary isn't left half-fixed (see new key `subscriptionUploadReceiptButton` below). Leaving only one branch of a two-branch ternary localized would be an obvious inconsistency for a reviewer to catch, so fix both together even though only one branch is in the counted 61.

**Reusable existing keys** — run:
`grep -n '"settingsTileTelegramBot"\|"deliveryListTitle"\|"inventoryTitle"\|"loading"\|"close"\|"paymentHistory"\|"card"\|"cash"\|"back"\|"cancelled"\|"retry"\|"settingsSectionSubscription"' lib/l10n/app_ru.arb`

Confirmed exact-value matches (verified character-for-character against `app_ru.arb`, per the mandatory reuse check — this branch's predecessor shipped two real bugs, `f54d5fd` and `bb6a1cc`, from skipping this):
- `settingsTileTelegramBot`: `"Telegram-бот"` → reuse for line 54.
- `deliveryListTitle`: `"Доставки"` → reuse for line 55. Its description ("Delivery list screen — AppBar title") is about a different screen, but the ARB already documents this same dual-use pattern on `inventoryTitle` below, so a second use is consistent with this file's own conventions.
- `inventoryTitle`: `"Инвентаризация"` → reuse for line 56 (its description already anticipates being "used both as the dashboard tile title and the inventory count screen's own AppBar title" — this is a third use of the same bare feature name).
- `loading`: `"Загрузка..."` → reuse for line 854's `_uploading ? 'Загрузка...' : ...` branch.
- `close`: `"Закрыть"` → reuse for line 569.
- `paymentHistory`: `"История оплат"` → reuse for line 411.
- `card`: `"Карта"` (description: "Card payment method") → reuse for both line 491's ternary branch and line 824's `_CardDetailRow(label: 'Карта', ...)` — same core meaning ("Card"), reused across the payment-method ternary and the card-detail-row label.
- `cash`: `"Наличные"` (description: "Cash payment method") → reuse for lines 491, 536 (inside the composite, see below), and 806.
- `back`: `"Назад"` → reuse for line 860.
- `cancelled`: `"Отменена"` (description: "Cancelled sale status") → reuse for line 126. **Note:** this key's description says "sale status," while here it's a *subscription* status — verified the value is character-for-character identical and the grammatical gender agrees (both feminine), and the concept ("cancelled") is the same regardless of which entity it modifies, so reuse per the meaning-not-location rule. Flagging explicitly since it's a cross-domain reuse, for the reviewer to confirm.
- `retry`: `"Повторить"` → reuse for line 617.
- `settingsSectionSubscription`: `"Подписка"` (description: "Settings page — subscription section header") → reuse for line 592's AppBar title. Same bare word, same meaning ("Subscription").

Also checked and confirmed **no** existing key holds these values (mint new below): `Банк`, `Выбрать`, `Галерея`, `Изображение недоступно`, `Истекла`, `Камера`, `Ожидает`, `Отклонено`, `Подтверждено`, `Получатель`, `Пробный период`, `Текущий план`, `Чек:`, `Валюты`. Also checked `'Активна'` — two existing keys hold this exact value (`loyaltySettingsActive`, `shiftsActiveStatus`), but both are explicitly screen-scoped per their own descriptions (and `shiftsActiveStatus`'s description already states it's kept separate from `loyaltySettingsActive` despite the identical value, establishing this ARB's own precedent of *not* merging same-value keys across unrelated features) — mint a third, `subscriptionActiveStatus`, following that same precedent rather than reusing either.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "subscriptionFeatureStores1": "1 магазин",
  "subscriptionFeatureProducts500": "500 товаров",
  "subscriptionFeatureEmployees2": "2 сотрудника",
  "subscriptionFeatureSalesReport": "Отчёт продаж",
  "subscriptionFeatureCurrencies": "Валюты",
  "subscriptionPriceStart": "49 TJS/мес",
  "subscriptionFeatureStores3": "3 магазина",
  "subscriptionFeatureProducts2000": "2000 товаров",
  "subscriptionFeatureEmployees10": "10 сотрудников",
  "subscriptionFeatureAllReports": "Все отчёты",
  "subscriptionFeatureDiscounts5": "5 скидок",
  "subscriptionPriceBusiness": "149 TJS/мес",
  "subscriptionFeatureStores5": "5 магазинов",
  "subscriptionFeatureUnlimitedProductsEmployees": "Безлимит товаров/сотрудников",
  "subscriptionFeatureExportPdfExcel": "Экспорт PDF/Excel",
  "subscriptionFeatureUnlimitedDiscounts": "Безлимит скидок",
  "subscriptionFeaturePrioritySupport": "Приоритетная поддержка",
  "subscriptionPricePremium": "299 TJS/мес",
  "subscriptionActiveStatus": "Активна",
  "@subscriptionActiveStatus": { "description": "Subscription-status badge — near-duplicate value to `loyaltySettingsActive` (\"Активна\", loyalty-toggle label) and `shiftsActiveStatus` (\"Активна\", shift-status badge); kept as its own key per this ARB's established pattern of not merging same-value keys across unrelated features" },
  "subscriptionTrialStatus": "Пробный период",
  "subscriptionExpiredStatus": "Истекла",
  "subscriptionTrialDaysLeftLine": "Пробный период: осталось {days} дней",
  "subscriptionExpiryUntilLine": "до {date}",
  "subscriptionAdminDiscountBadge": "Скидка {percent}%",
  "subscriptionPendingBannerText": "Ожидает подтверждения оплаты",
  "subscriptionCurrentPlanBadge": "Текущий план",
  "subscriptionSelectPlanButton": "Выбрать",
  "subscriptionPaymentPendingStatus": "Ожидает",
  "@subscriptionPaymentPendingStatus": { "description": "Payment-record status badge, default/pending case — distinct from `subscriptionPendingBannerText`, the fuller pending-payment banner sentence shown elsewhere on the same page" },
  "subscriptionPaymentConfirmedStatus": "Подтверждено",
  "subscriptionPaymentRejectedStatus": "Отклонено",
  "subscriptionPaymentDialogTitle": "Платёж — {plan}",
  "subscriptionPaymentAmountLine": "Сумма: {amount} TJS",
  "subscriptionCardTransferMethod": "Перевод на карту",
  "subscriptionPaymentMethodLine": "Метод: {method}",
  "subscriptionPaymentStatusLine": "Статус: {status}",
  "@subscriptionPaymentStatusLine": { "description": "Preserves existing behavior of interpolating the raw backend status code (e.g. \"CONFIRMED\"), not the already-localized status badge text used elsewhere on this page — not a behavior fix, just the literal migrated as-is" },
  "subscriptionPaymentDateLine": "Дата: {date}",
  "subscriptionAdminNoteLine": "Примечание: {note}",
  "subscriptionReceiptLabel": "Чек:",
  "subscriptionReceiptImageUnavailable": "Изображение недоступно",
  "subscriptionPlansSectionTitle": "Тарифные планы",
  "subscriptionCameraSource": "Камера",
  "subscriptionGallerySource": "Галерея",
  "subscriptionPaymentSheetTitle": "Оплата тарифа «{plan}»",
  "subscriptionTransferDetailsTitle": "Реквизиты для перевода",
  "subscriptionRecipientLabel": "Получатель",
  "subscriptionBankLabel": "Банк",
  "subscriptionUploadReceiptButton": "Я перевёл — загрузить чек",
  "@subscriptionUploadReceiptButton": { "description": "Lint-tool blind spot fix — check_i18n.dart's regex only flags the first Cyrillic string literal per line, and this one sits on the same line as the already-flagged 'Загрузка...' ternary branch, so it never appeared in tool/i18n-allowlist.txt; migrated together with its sibling for consistency" },
```

Placeholder metadata (all String-typed, pre-formatted at the call site per convention):

```json
  "@subscriptionTrialDaysLeftLine": { "placeholders": { "days": { "type": "String" } } },
  "@subscriptionExpiryUntilLine": { "placeholders": { "date": { "type": "String" } } },
  "@subscriptionAdminDiscountBadge": { "placeholders": { "percent": { "type": "String" } } },
  "@subscriptionPaymentDialogTitle": { "placeholders": { "plan": { "type": "String" } } },
  "@subscriptionPaymentAmountLine": { "placeholders": { "amount": { "type": "String" } } },
  "@subscriptionPaymentMethodLine": { "placeholders": { "method": { "type": "String" } } },
  "@subscriptionPaymentStatusLine": { "placeholders": { "status": { "type": "String" } } },
  "@subscriptionPaymentDateLine": { "placeholders": { "date": { "type": "String" } } },
  "@subscriptionAdminNoteLine": { "placeholders": { "note": { "type": "String" } } },
  "@subscriptionPaymentSheetTitle": { "placeholders": { "plan": { "type": "String" } } },
```

(Note `@subscriptionPaymentStatusLine` above merges both the `description` and `placeholders` sub-objects into one `@`-block — Dart's `arb` format allows a single object with multiple entries; don't create two separate `@subscriptionPaymentStatusLine` blocks.)

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

Add `final l10n = AppLocalizations.of(context)!;` at the top of `build(BuildContext context)` in both `_SubscriptionPageState` and `_PaymentMethodSheetState`. `_statusColor`/`_statusLabel`/`_planLabel` are instance methods of `_SubscriptionPageState` (a `State` subclass), so they can call `AppLocalizations.of(context)!` directly via the inherited `context` getter without any signature change.

| Find | Replace with |
|---|---|
| `label: 'Старт',` (line 35) / `return 'Старт';` (line 135) | left as-is — proper-noun exception, added to allowlist |
| `price: '49 TJS/мес',` | `price: l10n.subscriptionPriceStart,` |
| `'1 магазин',` | `l10n.subscriptionFeatureStores1,` |
| `'500 товаров',` | `l10n.subscriptionFeatureProducts500,` |
| `'2 сотрудника',` | `l10n.subscriptionFeatureEmployees2,` |
| `'Отчёт продаж',` | `l10n.subscriptionFeatureSalesReport,` |
| `'Валюты',` | `l10n.subscriptionFeatureCurrencies,` |
| `label: 'Бизнес',` (line 47) / `return 'Бизнес';` (line 137) | left as-is — proper-noun exception |
| `price: '149 TJS/мес',` | `price: l10n.subscriptionPriceBusiness,` |
| `'3 магазина',` | `l10n.subscriptionFeatureStores3,` |
| `'2000 товаров',` | `l10n.subscriptionFeatureProducts2000,` |
| `'10 сотрудников',` | `l10n.subscriptionFeatureEmployees10,` |
| `'Все отчёты',` | `l10n.subscriptionFeatureAllReports,` |
| `'Telegram-бот',` | `l10n.settingsTileTelegramBot,` |
| `'Доставки',` | `l10n.deliveryListTitle,` |
| `'Инвентаризация',` | `l10n.inventoryTitle,` |
| `'5 скидок',` | `l10n.subscriptionFeatureDiscounts5,` |
| `label: 'Премиум',` (line 62) / `return 'Премиум';` (line 139) | left as-is — proper-noun exception |
| `price: '299 TJS/мес',` | `price: l10n.subscriptionPricePremium,` |
| `'5 магазинов',` | `l10n.subscriptionFeatureStores5,` |
| `'Безлимит товаров/сотрудников',` | `l10n.subscriptionFeatureUnlimitedProductsEmployees,` |
| `'Экспорт PDF/Excel',` | `l10n.subscriptionFeatureExportPdfExcel,` |
| `'Безлимит скидок',` | `l10n.subscriptionFeatureUnlimitedDiscounts,` |
| `'Приоритетная поддержка',` | `l10n.subscriptionFeaturePrioritySupport,` |
| `return 'Активна';` | `return AppLocalizations.of(context)!.subscriptionActiveStatus;` |
| `return 'Пробный период';` | `return AppLocalizations.of(context)!.subscriptionTrialStatus;` |
| `return 'Истекла';` | `return AppLocalizations.of(context)!.subscriptionExpiredStatus;` |
| `return 'Отменена';` | `return AppLocalizations.of(context)!.cancelled;` |
| `expiryText = 'Пробный период: осталось ${state.trialDaysLeft} дней';` | `expiryText = AppLocalizations.of(context)!.subscriptionTrialDaysLeftLine('${state.trialDaysLeft}');` |
| `expiryText = 'до $formatted';` | `expiryText = AppLocalizations.of(context)!.subscriptionExpiryUntilLine(formatted);` |
| `'Скидка ${state.adminDiscount!.toStringAsFixed(0)}%',` | `AppLocalizations.of(context)!.subscriptionAdminDiscountBadge(state.adminDiscount!.toStringAsFixed(0)),` |
| `'Ожидает подтверждения оплаты',` | `AppLocalizations.of(context)!.subscriptionPendingBannerText,` |
| `'Текущий план',` | `l10n.subscriptionCurrentPlanBadge,` |
| `child: const Text('Выбрать',` | `child: Text(l10n.subscriptionSelectPlanButton,` |
| `'История оплат',` | `l10n.paymentHistory,` |
| `statusLabel = 'Подтверждено';` | `statusLabel = AppLocalizations.of(context)!.subscriptionPaymentConfirmedStatus;` |
| `statusLabel = 'Отклонено';` | `statusLabel = AppLocalizations.of(context)!.subscriptionPaymentRejectedStatus;` |
| `statusLabel = 'Ожидает';` | `statusLabel = AppLocalizations.of(context)!.subscriptionPaymentPendingStatus;` |
| `payment.method == 'CARD' ? 'Карта' : 'Наличные',` | `payment.method == 'CARD' ? AppLocalizations.of(context)!.card : AppLocalizations.of(context)!.cash,` |
| `title: Text('Платёж — ${_planLabel(payment.plan)}'),` | `title: Text(AppLocalizations.of(ctx)!.subscriptionPaymentDialogTitle(_planLabel(payment.plan))),` |
| `Text('Сумма: ${payment.amount.toStringAsFixed(0)} TJS'),` | `Text(AppLocalizations.of(ctx)!.subscriptionPaymentAmountLine(payment.amount.toStringAsFixed(0))),` |
| `'Метод: ${payment.method == 'CARD' ? 'Перевод на карту' : 'Наличные'}'),` | `AppLocalizations.of(ctx)!.subscriptionPaymentMethodLine(payment.method == 'CARD' ? AppLocalizations.of(ctx)!.subscriptionCardTransferMethod : AppLocalizations.of(ctx)!.cash)),` |
| `Text('Статус: ${payment.status}'),` | `Text(AppLocalizations.of(ctx)!.subscriptionPaymentStatusLine(payment.status)),` |
| `Text('Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(payment.createdAt)}'),` | `Text(AppLocalizations.of(ctx)!.subscriptionPaymentDateLine(DateFormat('dd.MM.yyyy HH:mm').format(payment.createdAt))),` |
| `Text('Примечание: ${payment.adminNote}'),` | `Text(AppLocalizations.of(ctx)!.subscriptionAdminNoteLine(payment.adminNote!)),` |
| `const Text('Чек:',` | `Text(AppLocalizations.of(ctx)!.subscriptionReceiptLabel,` |
| `'Изображение недоступно',` | `AppLocalizations.of(ctx)!.subscriptionReceiptImageUnavailable,` |
| `child: const Text('Закрыть'),` | `child: Text(AppLocalizations.of(ctx)!.close),` |
| `title: const Text('Подписка'),` | `title: Text(l10n.settingsSectionSubscription),` |
| `child: const Text('Повторить'),` | `child: Text(l10n.retry),` |
| `'Тарифные планы',` | `l10n.subscriptionPlansSectionTitle,` |
| `title: const Text('Камера'),` | `title: Text(AppLocalizations.of(ctx)!.subscriptionCameraSource),` |
| `title: const Text('Галерея'),` | `title: Text(AppLocalizations.of(ctx)!.subscriptionGallerySource),` |
| `'Оплата тарифа «${planInfo.label}»',` | `AppLocalizations.of(context)!.subscriptionPaymentSheetTitle(planInfo.label),` |
| `label: 'Перевод на карту',` | `label: AppLocalizations.of(context)!.subscriptionCardTransferMethod,` |
| `Text('Реквизиты для перевода',` | `Text(AppLocalizations.of(context)!.subscriptionTransferDetailsTitle,` |
| `_CardDetailRow(label: 'Получатель', value: 'DukonPro LLC'),` | `_CardDetailRow(label: AppLocalizations.of(context)!.subscriptionRecipientLabel, value: 'DukonPro LLC'),` |
| `_CardDetailRow(label: 'Банк', value: 'Эсхата'),` | `_CardDetailRow(label: AppLocalizations.of(context)!.subscriptionBankLabel, value: 'Эсхата'),` (value unchanged — proper-noun exception) |
| `label: Text(_uploading ? 'Загрузка...' : 'Я перевёл — загрузить чек'),` | `label: Text(_uploading ? AppLocalizations.of(context)!.loading : AppLocalizations.of(context)!.subscriptionUploadReceiptButton),` |
| `child: const Text('Назад'),` | `child: Text(AppLocalizations.of(context)!.back),` |
| `label: 'Наличные',` (line 806, `_MethodTile`) | `label: AppLocalizations.of(context)!.cash,` |
| `_CardDetailRow(label: 'Карта', value: '4276 3800 1234 5678'),` (line 824) | `_CardDetailRow(label: AppLocalizations.of(context)!.card, value: '4276 3800 1234 5678'),` |

**Important — `pw.Context` does not apply here** (that pitfall is specific to `reports_page.dart`'s PDF export code in Task 2); this file has no `package:pdf` usage, so no shadowing concern. **Do** watch for the two distinct `BuildContext`s in play: `_SubscriptionPageState.build`'s own `context`, and `_showPaymentDetail`'s dialog `builder: (ctx) => AlertDialog(...)` — use `ctx` for every `Text`/label inside that dialog (including the nested `errorBuilder: (ctx2, err, st) => ...` for the receipt image, where either the captured outer `ctx` or the builder's own `ctx2` work equally well since both resolve to valid `BuildContext`s in the same subtree; prefer `ctx` for consistency with the rest of the dialog). Similarly, `_PaymentMethodSheetState`'s own `_pickAndUploadReceipt()` opens a second, nested `showModalBottomSheet(builder: (ctx) => ...)` for the Камера/Галерея picker — use that inner `ctx`, not the outer sheet's `context`.

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep subscription_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `find test -iname '*subscription_page*'` to locate any golden/widget test for this page, then `flutter test <path> --reporter expanded` — expect passing. If a golden test fails after migration, verify via a throwaway `git worktree` at the parent commit (per the design spec's golden-baseline-check technique) whether the same failure pre-exists there before treating it as a regression.
Manually re-diff the file for any remaining `'...[а-яА-Я]...'` literal the tool might not catch (its regex is one-match-per-line, as demonstrated above) — there should be none left after this task.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/settings/subscription_page.dart tool/i18n-allowlist.txt
git commit -m "fix(app): migrate subscription_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 2: Migrate `reports_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/finance/reports_page.dart`

Current offenders (all 56, verbatim):
```
472:        'PURCHASE': 'Закупка',
473:        'RENT': 'Аренда',
474:        'SALARY': 'Зарплата',
475:        'UTILITIES': 'Коммунальные',
476:        'TRANSPORT': 'Транспорт',
477:        'MARKETING': 'Маркетинг',
478:        'OTHER': 'Другое',
536:              const Text('Экспорт отчёта',
542:                label: 'Скачать PDF',
551:                label: 'Скачать Excel (локальный)',
566:                        label: 'Скачать Excel (все данные)',
599:            pw.Text('Период: $period',
615:        text: 'Отчёт $tabName ($period)');
622:        if (rows.isEmpty) return [pw.Text('Нет данных')];
625:            headers: ['Дата', 'Продаж', 'Выручка', 'Средний чек'],
642:            headers: ['Категория', 'Сумма', '%'],
659:            headers: ['Показатель', 'Значение'],
661:              ['Доход', _fmtPrice(p.totalIncome)],
662:              ['Расходы', _fmtPrice(p.totalExpenses)],
663:              ['Чистая прибыль', _fmtPrice(p.netProfit)],
664:              ['Маржа', '${p.margin.toStringAsFixed(1)}%'],
672:          pw.Text('Топ товары',
677:            headers: ['Товар', 'Кол-во', 'Выручка'],
683:          pw.Text('Залёжные товары',
696:            headers: ['Кассир', 'Продаж', 'Выручка', 'Средний чек'],
727:        text: 'Отчёт $tabName');
746:        await Share.shareXFiles([XFile(file.path)], text: 'Экспорт $type');
765:              const Text('Что экспортировать?',
769:                ('Продажи', 'sales'),
770:                ('Товары', 'products'),
771:                ('Клиенты', 'customers'),
827:          addRow(['Маржа %', p.margin.toStringAsFixed(1)]);
830:            addRow(['Месяц', 'Доход', 'Расходы']);
843:          addRow(['=== Топ товары ===']);
849:          addRow(['=== Залёжные товары ===']);
855:          addRow(['Стоимость склада', d.stockValue.toStringAsFixed(2)]);
873:        'Прибыль',
875:        'Сотрудники',
888:          'Отчёты',
1057:            label: const Text('Все каналы'),
1065:            label: const Text('В магазине'),
1073:            label: const Text('Онлайн'),
1116:          TextButton(onPressed: onRetry, child: const Text('Повторить')),
1304:          title: 'Данные по продажам',
1324:                DataColumn(label: Text('Ср. чек'), numeric: true),
1342:            title: 'Топ-5 товаров по выручке',
1464:          title: 'Расходы по категориям',
1492:          title: 'Детализация',
1622:            title: 'Доход vs Расходы по месяцам',
1797:            title: 'Топ продажи',
1831:                          Text('${p.qty} шт',
1853:            title: 'Залёжные товары (30+ дней)',
1923:          title: 'Продажи по кассирам',
1934:                      '${rod.toY.toInt()} продаж',
```

- [ ] **Step 1: Check for reusable existing keys, and the PDF/Excel-header lint-tool blind spot**

**Lint-tool blind spot:** 12 lines in this file build a `List<String>` of table/PDF headers where only the *first* array element gets flagged (same one-match-per-line limitation documented in Task 1). The un-counted companions, all confirmed against `app_ru.arb`:
- `'Средний чек'` (full form) at lines 625, 696, 798, 858 — matches existing key `avgCheck` exactly. Distinct from the *abbreviated* `'Ср. чек'` (line 1324/2019), which has no existing match and needs a new key (see below).
- `'Сумма'` at lines 642, 808 — matches existing key `amount` exactly (there is also `adjustmentAmount` holding the same value, but its description ties it to the payroll-adjustment screen specifically, so `amount` is the more generic, appropriate reuse here).
- `'Кол-во'` at lines 677, 844, 850 — matches existing key `quantityShort` exactly.
- `'Неактивен'`-style gaps do not occur in this file.

None of these four are in the 56 counted offenders, but all four are ordinary hardcoded Cyrillic strings still sitting in the file — migrate them in the same pass (all four reuse existing keys except one, see below), and re-verify with a manual diff at Step 5, not just the automated grep.

**Reusable existing keys** — run:
`grep -n '"purchase"\|"rent"\|"salary"\|"utilities"\|"transport"\|"marketing"\|"other"\|"noData"\|"date"\|"category"\|"income"\|"expenses"\|"topProducts"\|"product"\|"cashier"\|"sales"\|"products"\|"moreClients"\|"month"\|"profit"\|"employees"\|"retry"\|"amount"\|"quantityShort"\|"avgCheck"' lib/l10n/app_ru.arb`

Confirmed exact-value matches (all verified character-for-character):
- `purchase`("Закупка"), `rent`("Аренда"), `salary`("Зарплата") — note `payroll` also equals "Зарплата" with no distinguishing description; `salary` reads better as an expense-category label than the feature-name-sounding `payroll`, so use `salary`.
- `utilities`("Коммунальные"), `transport`("Транспорт"), `marketing`("Маркетинг"), `other`("Другое") — the whole `_catLabel` map (lines 471-480) can be built entirely from already-existing generic keys, no new keys needed for it.
- `noData`("Нет данных") → reuse for all 7 occurrences (lines 622, 637, 656, 670, 693, 708, 1134).
- `date`("Дата") → reuse (lines 625, 798, 1321).
- `category`("Категория") → reuse (lines 642, 808).
- `income`("Доход") → reuse (lines 661, 824, 830, 1583, 1693).
- `expenses`("Расходы") → reuse (lines 662, 825, 830, 872, 910, 1591, 1695).
- `topProducts`("Топ товары") → reuse for the PDF header at line 672 (do **not** mint a second key for the same value).
- `product`("Товар") → reuse (lines 677, 688, 844, 850).
- `cashier`("Кассир") → reuse (lines 696, 858, 2016).
- `sales`("Продажи") → reuse (lines 769, 871, 909, and the `_tabName` list).
- `products`("Товары") → two existing keys hold this value (`products`, description "Products section title"; `navProducts`, no description) — use the more generic `products` for the export-type option and the tab labels (lines 770, 874, 912).
- `moreClients`("Клиенты") → its description ties it to the "More page" nav menu, a different screen, but the value and core meaning ("Clients") are identical — reuse per the meaning-not-location rule (line 771).
- `month`("Месяц") → reuse (line 830).
- `profit`("Прибыль") → reuse (lines 873, 911, and `_tabName`).
- `employees`("Сотрудники") → reuse (lines 875, 913, and `_tabName`).
- `retry`("Повторить") → reuse (line 1116).
- `amount`("Сумма"), `quantityShort`("Кол-во"), `avgCheck`("Средний чек") → reuse for the lint-gap companions above.

Also mint one **new generic (unprefixed) key in this task for cross-file reuse**: `margin: "Маржа"`. This bare word also appears as its own offender in `product_detail_page.dart` (Task 3 of this plan, `_MiniMetricCard(label: 'Маржа', ...)`); rather than each task minting its own `reportsMarginLabel`/`productDetailMarginLabel` for the identical value (the exact cross-task ARB duplication risk flagged in the design spec), mint it once here, generic and unprefixed, and Task 3 reuses it. **Coordinate task order accordingly** — if Task 3 is dispatched before this task's ARB changes land, its implementer must check whether `margin` already exists before minting a duplicate, and the final whole-branch review must confirm only one `margin` key exists.

Also checked and confirmed **no** existing key holds: `Продаж` (bare, distinct from plural `Продажи`/`sales`), `Показатель`, `Значение` (lint-gap companion of `Показатель`), `Чистая прибыль`, `Маржа %` (distinct literal from bare `Маржа`, kept separate since one includes the percent sign as part of the string), `Залёжные товары` (bare, distinct from the fuller `Залёжные товары (30+ дней)`), and all of the chart-title/section-title/export sentences below.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "margin": "Маржа",
  "@margin": { "description": "Bare 'Margin' metric label — reused verbatim by product_detail_page.dart's batch-profitability mini-card; mint here once, do not duplicate in that file's task" },
  "reportsSalesCountColumnLabel": "Продаж",
  "@reportsSalesCountColumnLabel": { "description": "Abbreviated table/PDF/Excel column header for a sales count — distinct from the plural noun `sales` (\"Продажи\", a tab/section name)" },
  "reportsExportSheetTitle": "Экспорт отчёта",
  "reportsExportPdf": "Скачать PDF",
  "reportsExportExcelLocal": "Скачать Excel (локальный)",
  "reportsExportExcelAllData": "Скачать Excel (все данные)",
  "reportsPdfPeriodLabel": "Период: {period}",
  "reportsShareSubjectWithPeriod": "Отчёт {tabName} ({period})",
  "reportsRevenueColumnLabel": "Выручка",
  "reportsMetricColumnLabel": "Показатель",
  "reportsValueColumnLabel": "Значение",
  "@reportsValueColumnLabel": { "description": "Lint-tool blind spot fix — companion header to `reportsMetricColumnLabel` on the same array literal, never flagged by check_i18n.dart's one-match-per-line regex" },
  "reportsNetProfitLabel": "Чистая прибыль",
  "reportsMarginPercentLabel": "Маржа %",
  "@reportsMarginPercentLabel": { "description": "Distinct literal from bare `margin` (\"Маржа\") — this one already includes the percent sign as part of the string, used only in the Excel-export row" },
  "reportsDeadStockPdfLabel": "Залёжные товары",
  "@reportsDeadStockPdfLabel": { "description": "Bare PDF section label — distinct from `reportsDeadStockSectionTitle` (\"Залёжные товары (30+ дней)\"), the fuller in-app section title" },
  "reportsShareSubject": "Отчёт {tabName}",
  "reportsExportTypeShareSubject": "Экспорт {type}",
  "reportsExportTypeSheetTitle": "Что экспортировать?",
  "reportsExcelTopProductsSectionHeader": "=== Топ товары ===",
  "reportsExcelDeadStockSectionHeader": "=== Залёжные товары ===",
  "reportsStockValueLabel": "Стоимость склада",
  "reportsPageTitle": "Отчёты",
  "reportsChannelAll": "Все каналы",
  "reportsChannelInStore": "В магазине",
  "reportsChannelOnline": "Онлайн",
  "reportsSalesDataSectionTitle": "Данные по продажам",
  "reportsAvgCheckColumnLabel": "Ср. чек",
  "@reportsAvgCheckColumnLabel": { "description": "Abbreviated column header — distinct from the full-word `avgCheck` (\"Средний чек\") used in the PDF/Excel export headers" },
  "reportsTop5ByRevenueChartTitle": "Топ-5 товаров по выручке",
  "reportsExpensesByCategoryChartTitle": "Расходы по категориям",
  "reportsDetailsSectionTitle": "Детализация",
  "reportsIncomeVsExpensesChartTitle": "Доход vs Расходы по месяцам",
  "reportsTopSalesSectionTitle": "Топ продажи",
  "reportsQuantityUnitsLine": "{qty} шт",
  "reportsDeadStockSectionTitle": "Залёжные товары (30+ дней)",
  "reportsSalesByCashierChartTitle": "Продажи по кассирам",
  "reportsSalesCountTooltip": "{count} продаж",
```

Placeholder metadata:

```json
  "@reportsPdfPeriodLabel": { "placeholders": { "period": { "type": "String" } } },
  "@reportsShareSubjectWithPeriod": { "placeholders": { "tabName": { "type": "String" }, "period": { "type": "String" } } },
  "@reportsShareSubject": { "placeholders": { "tabName": { "type": "String" } } },
  "@reportsExportTypeShareSubject": { "placeholders": { "type": { "type": "String" } } },
  "@reportsQuantityUnitsLine": { "placeholders": { "qty": { "type": "String" } } },
  "@reportsSalesCountTooltip": { "placeholders": { "count": { "type": "String" } } },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

Convert `_catLabel(String key)` (currently `String _catLabel(String key) => const {...}[key] ?? key;`) from an expression body to a block body that captures `l10n` first, since a `const` map literal can't call `AppLocalizations.of(context)`; `_catLabel` is an instance method of `_ReportsPageState` (a `State` subclass) so `context` is directly available, no parameter threading needed:

```dart
String _catLabel(String key) {
  final l10n = AppLocalizations.of(context)!;
  return {
        'PURCHASE': l10n.purchase,
        'RENT': l10n.rent,
        'SALARY': l10n.salary,
        'UTILITIES': l10n.utilities,
        'TRANSPORT': l10n.transport,
        'MARKETING': l10n.marketing,
        'OTHER': l10n.other,
      }[key] ??
      key;
}
```

Similarly convert `_tabName(int index)` (currently `String _tabName(int index) => const [...][index];`) the same way:

```dart
String _tabName(int index) {
  final l10n = AppLocalizations.of(context)!;
  return [
    l10n.sales,
    l10n.expenses,
    l10n.profit,
    l10n.products,
    l10n.employees,
  ][index];
}
```

The `TabBar`'s own `tabs: const [Tab(text: 'Продажи'), Tab(text: 'Расходы'), Tab(text: 'Прибыль'), Tab(text: 'Товары'), Tab(text: 'Сотрудники')]` (lines 908-914) holds the **same five values a second time** — convert it from `const` to a plain list built with the same `l10n` values (`build(BuildContext context)` already has `context`, add `final l10n = AppLocalizations.of(context)!;` at its top):

```dart
tabs: [
  Tab(text: l10n.sales),
  Tab(text: l10n.expenses),
  Tab(text: l10n.profit),
  Tab(text: l10n.products),
  Tab(text: l10n.employees),
],
```

**Critical `pw.Context` shadowing pitfall in `_exportPdf()`:** `doc.addPage(pw.Page(pageFormat: ..., build: (pw.Context context) { ... }))` names its own callback parameter `context`, of type `pw.Context` (from `package:pdf`) — **not** Flutter's `BuildContext`. Inside that closure, the identifier `context` no longer refers to the State's `BuildContext`, so `AppLocalizations.of(context)` would be a compile error there. Capture `l10n` **before** calling `doc.addPage(...)`:

```dart
Future<void> _exportPdf() async {
  final l10n = AppLocalizations.of(context)!; // capture BEFORE the pw.Page closure — its own `context` param shadows BuildContext
  final doc = pw.Document();
  final tabName = _tabName(_tabController.index);
  final period = '${_fmtDate(_from)} — ${_fmtDate(_to)}';

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    build: (pw.Context context) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('DukonPro — $tabName', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(l10n.reportsPdfPeriodLabel(period), style: const pw.TextStyle(fontSize: 12)),
          pw.Divider(),
          pw.SizedBox(height: 8),
          ..._buildPdfContent(l10n),
        ],
      );
    },
  ));
  ...
  await Share.shareXFiles([XFile(file.path)], text: l10n.reportsShareSubjectWithPeriod(tabName, period));
}
```

Thread `l10n` explicitly into `_buildPdfContent(AppLocalizations l10n)` (update its signature and its one call site above) rather than relying on it implicitly resolving `context` from the enclosing State — this keeps the call unambiguous and avoids anyone later "fixing" it to read `context` directly inside a spot that might get refactored into the `pw.Context` closure.

| Find | Replace with |
|---|---|
| `'PURCHASE': 'Закупка',` etc. (5 lines, 472-478) | see `_catLabel` conversion above |
| `const Text('Экспорт отчёта',` | `Text(AppLocalizations.of(ctx)!.reportsExportSheetTitle,` |
| `label: 'Скачать PDF',` | `label: AppLocalizations.of(ctx)!.reportsExportPdf,` |
| `label: 'Скачать Excel (локальный)',` | `label: AppLocalizations.of(ctx)!.reportsExportExcelLocal,` |
| `label: 'Скачать Excel (все данные)',` | `label: AppLocalizations.of(ctx)!.reportsExportExcelAllData,` (inside the nested `BlocBuilder<SubscriptionBloc, SubscriptionState>` whose own `builder: (_, sub)` discards its `BuildContext` — the enclosing `ctx` from `_showExportSheet`'s outer `builder: (ctx) => ...` is still in lexical scope and works fine here) |
| `pw.Text('Период: $period',` | `pw.Text(l10n.reportsPdfPeriodLabel(period),` (see `_exportPdf` rewrite above) |
| `text: 'Отчёт $tabName ($period)');` | `text: l10n.reportsShareSubjectWithPeriod(tabName, period));` |
| `if (rows.isEmpty) return [pw.Text('Нет данных')];` (and the 3 other identical `_buildPdfContent` returns at lines 637, 656, 670, 693, 708) | `if (rows.isEmpty) return [pw.Text(l10n.noData)];` — repeat for all 6 occurrences inside `_buildPdfContent`, now that it receives `l10n` as a parameter |
| `headers: ['Дата', 'Продаж', 'Выручка', 'Средний чек'],` (line 625) | `headers: [l10n.date, l10n.reportsSalesCountColumnLabel, l10n.reportsRevenueColumnLabel, l10n.avgCheck],` |
| `headers: ['Категория', 'Сумма', '%'],` | `headers: [l10n.category, l10n.amount, '%'],` |
| `headers: ['Показатель', 'Значение'],` | `headers: [l10n.reportsMetricColumnLabel, l10n.reportsValueColumnLabel],` |
| `['Доход', _fmtPrice(p.totalIncome)],` | `[l10n.income, _fmtPrice(p.totalIncome)],` |
| `['Расходы', _fmtPrice(p.totalExpenses)],` | `[l10n.expenses, _fmtPrice(p.totalExpenses)],` |
| `['Чистая прибыль', _fmtPrice(p.netProfit)],` | `[l10n.reportsNetProfitLabel, _fmtPrice(p.netProfit)],` |
| `['Маржа', '${p.margin.toStringAsFixed(1)}%'],` | `[l10n.margin, '${p.margin.toStringAsFixed(1)}%'],` |
| `pw.Text('Топ товары',` | `pw.Text(l10n.topProducts,` |
| `headers: ['Товар', 'Кол-во', 'Выручка'],` (lines 677, 844, 850) | `headers: [l10n.product, l10n.quantityShort, l10n.reportsRevenueColumnLabel],` |
| `pw.Text('Залёжные товары',` | `pw.Text(l10n.reportsDeadStockPdfLabel,` |
| `headers: ['Кассир', 'Продаж', 'Выручка', 'Средний чек'],` (lines 696, 858) | `headers: [l10n.cashier, l10n.reportsSalesCountColumnLabel, l10n.reportsRevenueColumnLabel, l10n.avgCheck],` |
| `text: 'Отчёт $tabName');` | `text: l10n.reportsShareSubject(tabName));` (thread `l10n = AppLocalizations.of(context)!;` into `_exportExcel()` the same way as `_exportPdf` — no `pw.Context` shadowing here, but keep the same pattern for consistency; also thread it into `_buildExcelContent(sheet, l10n)`) |
| `await Share.shareXFiles([XFile(file.path)], text: 'Экспорт $type');` | `await Share.shareXFiles([XFile(file.path)], text: AppLocalizations.of(context)!.reportsExportTypeShareSubject(type));` (in `_exportServerExcel`, no closure issue, `context` is directly usable) |
| `const Text('Что экспортировать?',` | `Text(AppLocalizations.of(ctx)!.reportsExportTypeSheetTitle,` |
| `('Продажи', 'sales'),` | `(l10n.sales, 'sales'),` (in `_showExportTypeSheet`, capture `final l10n = AppLocalizations.of(ctx)!;` at the top of the `builder: (ctx) =>` closure) |
| `('Товары', 'products'),` | `(l10n.products, 'products'),` |
| `('Клиенты', 'customers'),` | `(l10n.moreClients, 'customers'),` |
| `addRow(['Маржа %', p.margin.toStringAsFixed(1)]);` | `addRow([l10n.reportsMarginPercentLabel, p.margin.toStringAsFixed(1)]);` |
| `addRow(['Месяц', 'Доход', 'Расходы']);` | `addRow([l10n.month, l10n.income, l10n.expenses]);` |
| `addRow(['=== Топ товары ===']);` | `addRow([l10n.reportsExcelTopProductsSectionHeader]);` |
| `addRow(['=== Залёжные товары ===']);` | `addRow([l10n.reportsExcelDeadStockSectionHeader]);` |
| `addRow(['Стоимость склада', d.stockValue.toStringAsFixed(2)]);` | `addRow([l10n.reportsStockValueLabel, d.stockValue.toStringAsFixed(2)]);` |
| `'Прибыль',` (in `_tabName`) | see `_tabName` conversion above |
| `'Сотрудники',` (in `_tabName`) | see `_tabName` conversion above |
| `'Отчёты',` (AppBar title) | `l10n.reportsPageTitle,` |
| `label: const Text('Все каналы'),` | `label: Text(l10n.reportsChannelAll),` |
| `label: const Text('В магазине'),` (ChoiceChip) | `label: Text(l10n.reportsChannelInStore),` |
| `label: const Text('Онлайн'),` (ChoiceChip) | `label: Text(l10n.reportsChannelOnline),` |
| `TextButton(onPressed: onRetry, child: const Text('Повторить')),` | `TextButton(onPressed: onRetry, child: Text(AppLocalizations.of(context)!.retry)),` (inside `_ErrorView`, a `StatelessWidget` — `context` is the `build` parameter directly) |
| `title: 'Данные по продажам',` | `title: AppLocalizations.of(context)!.reportsSalesDataSectionTitle,` (inside `_SalesTab`, a `StatelessWidget`) |
| `DataColumn(label: Text('Ср. чек'), numeric: true),` (lines 1324, 2019) | `DataColumn(label: Text(AppLocalizations.of(context)!.reportsAvgCheckColumnLabel), numeric: true),` |
| `title: 'Топ-5 товаров по выручке',` | `title: AppLocalizations.of(context)!.reportsTop5ByRevenueChartTitle,` |
| `title: 'Расходы по категориям',` | `title: AppLocalizations.of(context)!.reportsExpensesByCategoryChartTitle,` |
| `title: 'Детализация',` (lines 1492, 1999) | `title: AppLocalizations.of(context)!.reportsDetailsSectionTitle,` |
| `title: 'Доход vs Расходы по месяцам',` | `title: AppLocalizations.of(context)!.reportsIncomeVsExpensesChartTitle,` |
| `_LegendDot(color: AppColors.primary, label: 'Доход'),` / `_LegendDot(color: context.danger, label: 'Расходы'),` | `_LegendDot(color: AppColors.primary, label: AppLocalizations.of(context)!.income),` / `_LegendDot(color: context.danger, label: AppLocalizations.of(context)!.expenses),` |
| `_KpiCard(label: 'В магазине', ...)` / `label: 'Онлайн'` (inside `_SalesTab`'s nested `Builder(builder: (context) {...})`) | `label: AppLocalizations.of(context)!.reportsChannelInStore` / `label: AppLocalizations.of(context)!.reportsChannelOnline` — the inner `Builder`'s own `context` param shadows `_SalesTab.build`'s outer one, but both are valid `BuildContext`s in the same subtree, so this is harmless (unlike the `pw.Context` case, which is a different, incompatible type) |
| `_KpiCard(label: 'Доход', ...)` / `'Расходы'` / `'Чистая прибыль'` / `'Маржа'` (Profit tab KPI cards) | `l10n.income` / `l10n.expenses` / `l10n.reportsNetProfitLabel` / `l10n.margin` |
| `title: 'Топ продажи',` | `title: AppLocalizations.of(context)!.reportsTopSalesSectionTitle,` |
| `Text('${p.qty} шт',` (lines 1831, 1871) | `Text(AppLocalizations.of(context)!.reportsQuantityUnitsLine('${p.qty}'),` |
| `title: 'Залёжные товары (30+ дней)',` | `title: AppLocalizations.of(context)!.reportsDeadStockSectionTitle,` |
| `const Text('Стоимость склада', ...)` (line 1776) | `Text(AppLocalizations.of(context)!.reportsStockValueLabel, ...)` |
| `title: 'Продажи по кассирам',` | `title: AppLocalizations.of(context)!.reportsSalesByCashierChartTitle,` |
| `'${rod.toY.toInt()} продаж',` | `AppLocalizations.of(context)!.reportsSalesCountTooltip('${rod.toY.toInt()}'),` |
| `columns: const [DataColumn(label: Text('Дата')), ...]` (line 1321) / `DataColumn(label: Text('Продаж'), ...)` (1322) / `DataColumn(label: Text('Выручка'), ...)` (1323) | non-`const` list: `columns: [DataColumn(label: Text(AppLocalizations.of(context)!.date)), DataColumn(label: Text(AppLocalizations.of(context)!.reportsSalesCountColumnLabel), numeric: true), DataColumn(label: Text(AppLocalizations.of(context)!.reportsRevenueColumnLabel), numeric: true), DataColumn(label: Text(AppLocalizations.of(context)!.reportsAvgCheckColumnLabel), numeric: true)],` |
| `columns: const [DataColumn(label: Text('Кассир')), ...]` (lines 2016-2019, `_StaffTab`) | same pattern as above, non-`const`, using `l10n.cashier`/`reportsSalesCountColumnLabel`/`reportsRevenueColumnLabel`/`reportsAvgCheckColumnLabel` |

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep reports_page.dart` — expect no output.
Run: `flutter analyze` — expect clean (this file's PDF-closure rewrite is the highest-risk change in this task for a type error; double-check the `pw.Context` vs `BuildContext` distinction compiles).
Run: `find test -iname '*reports_page*'` and `flutter test <path> --reporter expanded` if a test exists — expect passing, applying the golden-baseline-check technique from the design spec if a golden mismatch appears.
Manually re-diff for the lint-gap companions (`Средний чек`, `Сумма`, `Кол-во`, `Значение`) since they won't show up in the automated grep even before this task, and confirm none are left over after.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/finance/reports_page.dart
git commit -m "fix(app): migrate reports_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 3: Migrate `product_detail_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/product/product_detail_page.dart`

Current offenders (all 37, verbatim):
```
43:        appBar: AppBar(title: const Text('Товар')),
44:        body: const Center(child: Text('Товар не найден')),
82:                  const Text('Товар',
100:                        child: Text('Удалить', style: TextStyle(color: AppColors.error)),
153:                            product.isActive ? 'Активен' : 'Неактивен',
170:                            label: 'Цена продажи',
179:                            label: 'Себестоимость',
194:                            label: 'Прибыль',
203:                            label: 'Маржа',
243:                              Text('Текущий остаток: ${product.quantity} $unitName',
245:                              Text('Минимальный: ${product.minQuantity} $unitName',
285:                          _InfoRow(label: 'Артикул', value: product.sku ?? '—'),
287:                          _InfoRow(label: 'Штрих-код', value: product.barcode ?? '—'),
289:                          _InfoRow(label: 'Категория', value: product.categoryName ?? '—'),
237:                          const Text('Наличие на складе',
282:                          const Text('Информация',
333:                      label: const Text('Приход',
360:                      label: const Text('Продать',
377:        title: const Text('Удалить товар?'),
378:        content: const Text('Это действие нельзя отменить.'),
382:            child: const Text('Отмена'),
397:            child: const Text('Удалить',
495:        _error = 'Магазин не выбран';
515:        _error = 'Не удалось загрузить историю движений';
549:        return 'Приход';
551:        return 'Расход';
553:        return 'Корректировка';
579:          const Text('История движений',
603:                child: Text('Нет движений',
749:          'Нет данных о последней закупке — оформите приход, чтобы видеть окупаемость партии.',
769:            'Окупаемость партии',
774:            label: 'Себестоимость партии',
779:            label: 'Выручка от партии',
784:            label: 'Прибыль заработана',
789:            label: 'До окупаемости партии',
793:                    ? 'Партия окупилась'
798:            label: 'Остаток',
800:                '${(data['remainingQuantity'] as num?)?.round() ?? 0} шт. на ${_formatMoney((data['remainingStockValue'] as num?))}',
815:              '${paybackPercent.toStringAsFixed(0)}% окупаемости',
```

- [ ] **Step 1: Check for reusable existing keys, near-duplicate financial-vs-stock trap, and the lint-tool blind spot**

**Lint-tool blind spot:** line 153, `product.isActive ? 'Активен' : 'Неактивен',` — only `'Активен'` is in the counted 37 (regex first-match); `'Неактивен'` is the un-counted second branch. Fix both together in the same pass (same reasoning as Task 1/2's blind spots).

**Near-duplicate trap — same Russian word, two different domains, do NOT reuse across them:** `_typeLabel(String type)` (lines 546-557) returns `'Приход'`/`'Расход'`/`'Корректировка'` for stock-movement types `IN`/`OUT`/`ADJUSTMENT` — this is about **goods** moving in/out of stock, not money. The existing ARB key `expense` also holds the value `"Расход"`, but its description explicitly scopes it to a financial-ledger transaction-type fallback (verified its only real call site, `balance_page.dart:502`, is `isSale ? l10n.sale : l10n.expense` for a money transaction). Reusing `expense` here for the stock "OUT" movement type would be exactly the kind of same-spelling-different-meaning bug this branch's predecessor already shipped twice (`f54d5fd`, `bb6a1cc`) — mint a distinct key instead (`outflowType`, see below). The ARB already has sibling stock-movement-type keys nearby (`stockIntake: "Приход товара"`, `purchase: "Закупка"`, `sale: "Продажа"`, `returnType: "Возврат"`, `adjustment: "Корректировка"`, `writeOff: "Списание"`) — mint the two new ones (`intakeType`, `outflowType`) as bare nouns in that same style and physical block.

**Reusable existing keys** — run:
`grep -n '"sku"\|"category"\|"adjustment"\|"cancel"\|"profit"\|"dashboardCost"\|"productNotFound"\|"product"\|"delete"\|"sellPrice"\|"actionCannotBeUndone"' lib/l10n/app_ru.arb`

Confirmed exact-value matches:
- `sku`("Артикул", desc "SKU field") → line 285.
- `category`("Категория", desc "Category label") → line 289.
- `adjustment`("Корректировка", desc "Stock adjustment type") → line 553 — this one's description is already scoped correctly to stock movements, safe to reuse directly.
- `cancel`("Отмена", desc "Cancel button") → line 382.
- `profit`("Прибыль", desc "Profit label") → line 194.
- `dashboardCost`("Себестоимость", desc "Cost-of-goods metric tile label") → line 179.
- `productNotFound`("Товар не найден", desc "Shown when a scanned/looked-up product cannot be matched") → line 44.
- `product`("Товар", desc "Generic singular 'product' label") → lines 43, 82.
- `delete`("Удалить", desc "Delete button") → lines 100, 397.
- `sellPrice`("Цена продажи", desc "Selling price") → line 170.
- `actionCannotBeUndone`("Это действие нельзя отменить.") → line 378.

**Cross-task reuse — mint once, in Task 2:** `'Маржа'` (line 203) has no existing ARB match, but the identical bare word is also an offender in `reports_page.dart` (Task 2 of this plan). Per that task's Step 1, a new generic key `margin: "Маржа"` is minted there specifically so this task can reuse it rather than each task independently minting a same-value key (the cross-task ARB-duplication risk the design spec calls out as this plan's biggest real risk). **Do not mint a second `margin`-equivalent key here** — confirm `margin` exists in `app_ru.arb` before starting this task (run `grep -n '"margin"' lib/l10n/app_ru.arb`); if it doesn't yet (Task 2 hasn't landed), either wait for Task 2 or mint it here instead and have Task 2 reuse it — whichever task actually lands first should be the one that mints it, and the final whole-branch review must confirm there is exactly one `margin` key.

Also checked and confirmed **no** existing key holds: `Единица`, `Наличие на складе`, `Информация`, `Магазин не выбран`, `История движений`, `Не удалось загрузить историю движений`, `Нет движений`, `Окупаемость партии`, and `Штрих-код` — note the existing `barcode` key holds `"Штрихкод"` (no hyphen), a *different* literal from this file's `"Штрих-код"` (with hyphen); per the mandatory character-for-character check, these do not match, so mint a separate key here rather than "fixing" the existing one to match (that inconsistency is a pre-existing, unrelated issue — out of scope, don't fix unrelated things).

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "intakeType": "Приход",
  "@intakeType": { "description": "Stock movement type — goods arriving (IN), bare short form; distinct from `stockIntake` (\"Приход товара\"), the fuller action-button label used elsewhere. Also reused here for the page's own 'record an intake' bottom button, since it's the same bare word in the same underlying concept." },
  "outflowType": "Расход",
  "@outflowType": { "description": "Stock movement type — goods leaving (OUT/sold), bare short form. Distinct from `expense` (\"Расход\", a financial-ledger transaction-type fallback label used in balance_page.dart) — identical Russian spelling, different domain; do not merge." },
  "productStatusActive": "Активен",
  "@productStatusActive": { "description": "Product active-status badge, masculine grammatical agreement (product = 'товар', masculine) — distinct from the feminine-agreement 'Активна' forms used elsewhere (subscription/loyalty/shift status badges), which cannot be reused here without breaking Russian grammar" },
  "productStatusInactive": "Неактивен",
  "@productStatusInactive": { "description": "Lint-tool blind spot fix — companion to `productStatusActive` on the same ternary line, never flagged by check_i18n.dart's one-match-per-line regex" },
  "productDetailUnitLabel": "Единица",
  "productDetailCurrentStockLine": "Текущий остаток: {qty} {unit}",
  "productDetailMinStockLine": "Минимальный: {qty} {unit}",
  "productDetailBarcodeLabel": "Штрих-код",
  "productDetailStockAvailabilityTitle": "Наличие на складе",
  "productDetailInfoSectionTitle": "Информация",
  "productDetailSellButton": "Продать",
  "productDetailDeleteConfirmTitle": "Удалить товар?",
  "productDetailStoreNotSelectedError": "Магазин не выбран",
  "productDetailMovementHistoryLoadError": "Не удалось загрузить историю движений",
  "productDetailMovementHistoryTitle": "История движений",
  "productDetailNoMovements": "Нет движений",
  "productDetailBatchNoDataMessage": "Нет данных о последней закупке — оформите приход, чтобы видеть окупаемость партии.",
  "productDetailBatchPayabilityTitle": "Окупаемость партии",
  "productDetailBatchCostLabel": "Себестоимость партии",
  "productDetailBatchRevenueLabel": "Выручка от партии",
  "productDetailBatchProfitEarnedLabel": "Прибыль заработана",
  "productDetailBatchTimeToPaybackLabel": "До окупаемости партии",
  "productDetailBatchPaidOffLabel": "Партия окупилась",
  "productDetailStockRemainingLabel": "Остаток",
  "productDetailStockRemainingValue": "{qty} шт. на {value}",
  "productDetailBatchPaybackPercentLine": "{percent}% окупаемости",
```

Placeholder metadata:

```json
  "@productDetailCurrentStockLine": { "placeholders": { "qty": { "type": "String" }, "unit": { "type": "String" } } },
  "@productDetailMinStockLine": { "placeholders": { "qty": { "type": "String" }, "unit": { "type": "String" } } },
  "@productDetailStockRemainingValue": { "placeholders": { "qty": { "type": "String" }, "value": { "type": "String" } } },
  "@productDetailBatchPaybackPercentLine": { "placeholders": { "percent": { "type": "String" } } },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

`ProductDetailPage` is a `StatelessWidget`; `build(BuildContext context)` already does `final l10n = AppLocalizations.of(context)!;` at its top (line 37) — reuse that existing local, don't shadow it. `_showDeleteDialog(BuildContext context, Product product)` already takes `context` as an explicit parameter and opens its own `builder: (ctx) => AlertDialog(...)` — use `ctx` inside that dialog. `_StockMovementsSectionState` and `_BatchProfitabilitySectionState` are both `State` subclasses with their own inherited `context` getter — no threading needed for `_typeLabel`, `_loadMovements`, `_load`, etc.

| Find | Replace with |
|---|---|
| `appBar: AppBar(title: const Text('Товар')),` | `appBar: AppBar(title: Text(l10n.product)),` |
| `body: const Center(child: Text('Товар не найден')),` | `body: Center(child: Text(l10n.productNotFound)),` |
| `const Text('Товар',` (line 82) | `Text(l10n.product,` |
| `child: Text('Удалить', style: TextStyle(color: AppColors.error)),` (PopupMenuItem, line 100) | `child: Text(l10n.delete, style: TextStyle(color: AppColors.error)),` |
| `product.isActive ? 'Активен' : 'Неактивен',` | `product.isActive ? l10n.productStatusActive : l10n.productStatusInactive,` |
| `label: 'Цена продажи',` | `label: l10n.sellPrice,` |
| `label: 'Себестоимость',` | `label: l10n.dashboardCost,` |
| `label: 'Прибыль',` | `label: l10n.profit,` |
| `label: 'Маржа',` | `label: l10n.margin,` |
| `Text('Текущий остаток: ${product.quantity} $unitName',` | `Text(l10n.productDetailCurrentStockLine('${product.quantity}', unitName),` |
| `Text('Минимальный: ${product.minQuantity} $unitName',` | `Text(l10n.productDetailMinStockLine('${product.minQuantity}', unitName),` |
| `_InfoRow(label: 'Артикул', value: product.sku ?? '—'),` | `_InfoRow(label: l10n.sku, value: product.sku ?? '—'),` |
| `_InfoRow(label: 'Штрих-код', value: product.barcode ?? '—'),` | `_InfoRow(label: l10n.productDetailBarcodeLabel, value: product.barcode ?? '—'),` |
| `_InfoRow(label: 'Категория', value: product.categoryName ?? '—'),` | `_InfoRow(label: l10n.category, value: product.categoryName ?? '—'),` |
| `const Text('Наличие на складе',` | `Text(l10n.productDetailStockAvailabilityTitle,` |
| `const Text('Информация',` | `Text(l10n.productDetailInfoSectionTitle,` |
| `label: const Text('Приход',` (bottom button) | `label: Text(l10n.intakeType,` |
| `label: const Text('Продать',` | `label: Text(l10n.productDetailSellButton,` |
| `title: const Text('Удалить товар?'),` | `title: Text(AppLocalizations.of(ctx)!.productDetailDeleteConfirmTitle),` |
| `content: const Text('Это действие нельзя отменить.'),` | `content: Text(AppLocalizations.of(ctx)!.actionCannotBeUndone),` |
| `child: const Text('Отмена'),` | `child: Text(AppLocalizations.of(ctx)!.cancel),` |
| `child: const Text('Удалить',` (line 397, dialog confirm) | `child: Text(AppLocalizations.of(ctx)!.delete,` |
| `_error = 'Магазин не выбран';` | `_error = AppLocalizations.of(context)!.productDetailStoreNotSelectedError;` |
| `_error = 'Не удалось загрузить историю движений';` | `_error = AppLocalizations.of(context)!.productDetailMovementHistoryLoadError;` |
| `return 'Приход';` (in `_typeLabel`) | `return AppLocalizations.of(context)!.intakeType;` |
| `return 'Расход';` | `return AppLocalizations.of(context)!.outflowType;` |
| `return 'Корректировка';` | `return AppLocalizations.of(context)!.adjustment;` |
| `const Text('История движений',` | `Text(AppLocalizations.of(context)!.productDetailMovementHistoryTitle,` |
| `child: Text('Нет движений',` | `child: Text(AppLocalizations.of(context)!.productDetailNoMovements,` |
| `'Нет данных о последней закупке — оформите приход, чтобы видеть окупаемость партии.',` | `AppLocalizations.of(context)!.productDetailBatchNoDataMessage,` |
| `'Окупаемость партии',` | `AppLocalizations.of(context)!.productDetailBatchPayabilityTitle,` |
| `label: 'Себестоимость партии',` | `label: AppLocalizations.of(context)!.productDetailBatchCostLabel,` |
| `label: 'Выручка от партии',` | `label: AppLocalizations.of(context)!.productDetailBatchRevenueLabel,` |
| `label: 'Прибыль заработана',` | `label: AppLocalizations.of(context)!.productDetailBatchProfitEarnedLabel,` |
| `label: 'До окупаемости партии',` | `label: AppLocalizations.of(context)!.productDetailBatchTimeToPaybackLabel,` |
| `? 'Партия окупилась'` | `? AppLocalizations.of(context)!.productDetailBatchPaidOffLabel` |
| `label: 'Остаток',` | `label: AppLocalizations.of(context)!.productDetailStockRemainingLabel,` |
| `'${(data['remainingQuantity'] as num?)?.round() ?? 0} шт. на ${_formatMoney((data['remainingStockValue'] as num?))}',` | `AppLocalizations.of(context)!.productDetailStockRemainingValue('${(data['remainingQuantity'] as num?)?.round() ?? 0}', _formatMoney((data['remainingStockValue'] as num?))),` |
| `'${paybackPercent.toStringAsFixed(0)}% окупаемости',` | `AppLocalizations.of(context)!.productDetailBatchPaybackPercentLine(paybackPercent.toStringAsFixed(0)),` |

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep product_detail_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `find test -iname '*product_detail_page*'` and `flutter test <path> --reporter expanded` if a test exists — expect passing, applying the golden-baseline-check technique from the design spec on any mismatch.
Manually confirm `'Неактивен'` (the blind-spot line) is gone from the diff.
Run `grep -n '"margin"' lib/l10n/app_ru.arb` to confirm exactly one `margin` key exists (cross-task coordination check with Task 2).

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/product/product_detail_page.dart
git commit -m "fix(app): migrate product_detail_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 4: Migrate `receipt_template_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/settings/receipt_template_page.dart`

Current offenders (all 27, verbatim):
```
94:    final headerText = _headerCtrl.text.isEmpty ? 'Ваш магазин' : _headerCtrl.text;
95:    final footerText = _footerCtrl.text.isEmpty ? 'Спасибо за покупку!' : _footerCtrl.text;
117:            Text('Товар 1                 50.00 TJS',
119:            Text('Товар 2                 30.00 TJS',
122:              Text('Скидка                  -5.00 TJS',
125:            Text('ИТОГО                   75.00 TJS',
137:              Text('Кассир: Иванов И.',
159:        title: const Text('Шаблон чека'),
169:                : const Text('Сохранить',
191:                        Text('Предпросмотр',
204:                  Text('Текст',
222:                            labelText: 'Заголовок чека',
224:                            hintText: 'Название магазина или приветствие',
232:                            labelText: 'Подвал чека',
234:                            hintText: 'Спасибо за покупку!',
243:                  Text('Размер шрифта',
260:                              ButtonSegment(value: 'small', label: Text('Мал.')),
261:                              ButtonSegment(value: 'medium', label: Text('Ср.')),
262:                              ButtonSegment(value: 'large', label: Text('Бол.')),
275:                  Text('Ширина бумаги',
292:                              ButtonSegment(value: '58mm', label: Text('58 мм')),
293:                              ButtonSegment(value: '80mm', label: Text('80 мм')),
306:                  Text('Показывать на чеке',
319:                        _buildToggle(Icons.qr_code_outlined, 'QR-код', _showQr,
322:                        _buildToggle(Icons.calendar_today_outlined, 'Дата и время',
325:                        _buildToggle(Icons.person_outline, 'Кассир', _showCashier,
328:                        _buildToggle(Icons.discount_outlined, 'Скидка', _showDiscount,
349:                            : const Text('Сохранить шаблон',
```

- [ ] **Step 1: Check for reusable existing keys**

No lint-tool blind spots in this file (verified — every offending line has exactly one Cyrillic string literal, unlike Tasks 1-3).

Run: `grep -n '"cashier"\|"discount"\|"save"' lib/l10n/app_ru.arb`
Expected: `cashier`("Кассир"), `discount`("Скидка"), `save`("Сохранить") all already exist with no restrictive description — reuse for line 325's toggle label, line 328's toggle label, and line 169's AppBar action button, respectively.

Checked and confirmed **no** existing key holds any of the other 24 values (`58 мм`, `80 мм`, `QR-код`, `Бол.`, `Ваш магазин`, `Дата и время`, `Заголовок чека`, `ИТОГО                   75.00 TJS`, `Кассир: Иванов И.`, `Мал.`, `Название магазина или приветствие`, `Подвал чека`, `Показывать на чеке`, `Предпросмотр`, `Размер шрифта`, `Скидка                  -5.00 TJS`, `Сохранить шаблон`, `Спасибо за покупку!`, `Ср.`, `Текст`, `Товар 1                 50.00 TJS`, `Товар 2                 30.00 TJS`, `Шаблон чека`, `Ширина бумаги`) — mint new keys for all of these.

**Note on the mock receipt-preview lines** (lines 117, 119, 122, 125, 137): `_buildReceiptPreview()` renders a static, fixed-content visual preview of what a printed receipt looks like — `'Товар 1                 50.00 TJS'` etc. are not real transaction data, they're hardcoded demo content whose internal spacing is deliberate visual alignment for the monospace receipt mockup. Keep each as one opaque literal key (preserving the exact spacing character-for-character) rather than trying to decompose into a composite placeholder key — there's no real data being interpolated, so there's nothing to parameterize.

**Note on `'Спасибо за покупку!'` appearing twice** (line 95, the default footer text shown when the user hasn't typed one, and line 234, the `hintText` suggesting what to type in that same field): identical text, same meaning in both roles (one is the fallback preview value, the other is the input hint suggesting that exact same fallback) — reuse a single key for both, following the same-value-different-role reuse precedent already established in this plan (e.g. Task 5 of the prior project's `myStoresAddTitle`).

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "receiptTemplatePageTitle": "Шаблон чека",
  "receiptTemplateSaveButton": "Сохранить шаблон",
  "receiptTemplatePreviewLabel": "Предпросмотр",
  "receiptTemplateTextSectionLabel": "Текст",
  "receiptTemplateHeaderFieldLabel": "Заголовок чека",
  "receiptTemplateHeaderFieldHint": "Название магазина или приветствие",
  "receiptTemplateFooterFieldLabel": "Подвал чека",
  "receiptPreviewDefaultFooter": "Спасибо за покупку!",
  "@receiptPreviewDefaultFooter": { "description": "Default receipt-footer preview text — reused verbatim as the footer text field's hint, since the hint suggests exactly this same fallback value" },
  "receiptTemplateFontSizeLabel": "Размер шрифта",
  "receiptTemplateFontSizeSmall": "Мал.",
  "receiptTemplateFontSizeMedium": "Ср.",
  "receiptTemplateFontSizeLarge": "Бол.",
  "receiptTemplatePaperWidthLabel": "Ширина бумаги",
  "receiptTemplatePaperWidth58mm": "58 мм",
  "receiptTemplatePaperWidth80mm": "80 мм",
  "receiptTemplateShowOnReceiptLabel": "Показывать на чеке",
  "receiptTemplateQrToggleLabel": "QR-код",
  "receiptTemplateDateTimeToggleLabel": "Дата и время",
  "receiptPreviewDefaultHeader": "Ваш магазин",
  "receiptPreviewItemLine1": "Товар 1                 50.00 TJS",
  "receiptPreviewItemLine2": "Товар 2                 30.00 TJS",
  "receiptPreviewDiscountLine": "Скидка                  -5.00 TJS",
  "@receiptPreviewDiscountLine": { "description": "Fixed demo content for the receipt-mockup preview, monospace-aligned — not real transaction data, no placeholders needed" },
  "receiptPreviewTotalLine": "ИТОГО                   75.00 TJS",
  "receiptPreviewCashierLine": "Кассир: Иванов И.",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

`_ReceiptTemplatePageState` is a `State` subclass; `_buildReceiptPreview()` and `_buildToggle(...)` are its own instance methods, so `context` is directly available via the inherited getter in both — add `final l10n = AppLocalizations.of(context)!;` at the top of `build(BuildContext context)` and reuse it, and add the same line at the top of `_buildReceiptPreview()` (it's called from `build`, but doesn't currently receive `context`/`l10n` as a parameter — since it's an instance method of the same `State`, it can fetch its own via `AppLocalizations.of(context)!` without any signature change).

| Find | Replace with |
|---|---|
| `final headerText = _headerCtrl.text.isEmpty ? 'Ваш магазин' : _headerCtrl.text;` | `final l10n = AppLocalizations.of(context)!;` (add above) `final headerText = _headerCtrl.text.isEmpty ? l10n.receiptPreviewDefaultHeader : _headerCtrl.text;` |
| `final footerText = _footerCtrl.text.isEmpty ? 'Спасибо за покупку!' : _footerCtrl.text;` | `final footerText = _footerCtrl.text.isEmpty ? l10n.receiptPreviewDefaultFooter : _footerCtrl.text;` |
| `Text('Товар 1                 50.00 TJS',` | `Text(l10n.receiptPreviewItemLine1,` |
| `Text('Товар 2                 30.00 TJS',` | `Text(l10n.receiptPreviewItemLine2,` |
| `Text('Скидка                  -5.00 TJS',` | `Text(l10n.receiptPreviewDiscountLine,` |
| `Text('ИТОГО                   75.00 TJS',` | `Text(l10n.receiptPreviewTotalLine,` |
| `Text('Кассир: Иванов И.',` | `Text(l10n.receiptPreviewCashierLine,` |
| `title: const Text('Шаблон чека'),` | `title: Text(l10n.receiptTemplatePageTitle),` |
| `: const Text('Сохранить',` (AppBar action) | `: Text(l10n.save,` |
| `Text('Предпросмотр',` | `Text(l10n.receiptTemplatePreviewLabel,` |
| `Text('Текст',` | `Text(l10n.receiptTemplateTextSectionLabel,` |
| `labelText: 'Заголовок чека',` | `labelText: l10n.receiptTemplateHeaderFieldLabel,` |
| `hintText: 'Название магазина или приветствие',` | `hintText: l10n.receiptTemplateHeaderFieldHint,` |
| `labelText: 'Подвал чека',` | `labelText: l10n.receiptTemplateFooterFieldLabel,` |
| `hintText: 'Спасибо за покупку!',` | `hintText: l10n.receiptPreviewDefaultFooter,` |
| `Text('Размер шрифта',` | `Text(l10n.receiptTemplateFontSizeLabel,` |
| `ButtonSegment(value: 'small', label: Text('Мал.')),` | `ButtonSegment(value: 'small', label: Text(l10n.receiptTemplateFontSizeSmall)),` |
| `ButtonSegment(value: 'medium', label: Text('Ср.')),` | `ButtonSegment(value: 'medium', label: Text(l10n.receiptTemplateFontSizeMedium)),` |
| `ButtonSegment(value: 'large', label: Text('Бол.')),` | `ButtonSegment(value: 'large', label: Text(l10n.receiptTemplateFontSizeLarge)),` |
| `Text('Ширина бумаги',` | `Text(l10n.receiptTemplatePaperWidthLabel,` |
| `ButtonSegment(value: '58mm', label: Text('58 мм')),` | `ButtonSegment(value: '58mm', label: Text(l10n.receiptTemplatePaperWidth58mm)),` |
| `ButtonSegment(value: '80mm', label: Text('80 мм')),` | `ButtonSegment(value: '80mm', label: Text(l10n.receiptTemplatePaperWidth80mm)),` |
| `Text('Показывать на чеке',` | `Text(l10n.receiptTemplateShowOnReceiptLabel,` |
| `_buildToggle(Icons.qr_code_outlined, 'QR-код', _showQr,` | `_buildToggle(Icons.qr_code_outlined, l10n.receiptTemplateQrToggleLabel, _showQr,` |
| `_buildToggle(Icons.calendar_today_outlined, 'Дата и время',` | `_buildToggle(Icons.calendar_today_outlined, l10n.receiptTemplateDateTimeToggleLabel,` |
| `_buildToggle(Icons.person_outline, 'Кассир', _showCashier,` | `_buildToggle(Icons.person_outline, l10n.cashier, _showCashier,` |
| `_buildToggle(Icons.discount_outlined, 'Скидка', _showDiscount,` | `_buildToggle(Icons.discount_outlined, l10n.discount, _showDiscount,` |
| `: const Text('Сохранить шаблон',` | `: Text(l10n.receiptTemplateSaveButton,` |

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep receipt_template_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `find test -iname '*receipt_template_page*'` and `flutter test <path> --reporter expanded` if a test exists — expect passing.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/settings/receipt_template_page.dart
git commit -m "fix(app): migrate receipt_template_page.dart hardcoded strings to AppLocalizations"
```

---
### Task 5: Migrate `pos_checkout_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/pos/pos_checkout_page.dart`

This file already declares `final l10n = AppLocalizations.of(context)!;` in
`build()` and reuses it via `_buildCartContent(cartState, l10n)` /
`_buildCartItem(item, l10n)` — both already take an `AppLocalizations l10n`
parameter. `_confirmCardPayment` already declares its own local
`final l10n = AppLocalizations.of(context)!;` at its top (since it's a
separate instance method, not passed `l10n`). Follow this file's own
established convention: `_showCustomerSelection()`, `_showDiscountDialog()`
and `_showRedemptionSheet(BuildContext context, CartState cart)` currently
have **no** `l10n` binding at all — add
`final l10n = AppLocalizations.of(context)!;` at the very top of each of
those three methods (using the State's inherited `context` getter — this is
a `State<PosCheckoutPage>` class, so every instance method has `context`
available even without a parameter). Nested `builder: (context, ...)`
closures inside those methods **shadow** the identifier `context`, but they
do **not** shadow `l10n` — reference the outer `l10n` variable directly
inside those closures rather than re-deriving it from the (possibly
shadowed) inner `context`. `_paymentMethodButton(String method, String
label, IconData icon)` takes `label` as a plain `String` — no signature
change needed there; just pass `l10n.xxx` as the `label` argument from the
call sites already inside `build()`.

Current offenders (all 26, verbatim):
```
184: const Text('Выберите клиента',
191: child: const Text('Без клиента'),
206: return Center(child: Text('Нет клиентов', style: TextStyle(color: context.textSecondary)));
255: : 'Магазин';
283: const Text('Касса',
311: hintText: 'Поиск по названию',
427: title: 'Корзина пуста',
428: subtitle: 'Найдите товар через поиск или выберите из списка выше',
484: subtitle: Text('${product.quantity} шт', style: TextStyle(fontSize: 12, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
500: Text('Корзина (${cartState.itemCount} товаров)',
514: Text('Подытог', style: TextStyle(fontSize: 14, color: context.textSecondary)),
525: Text('Скидка', style: TextStyle(fontSize: 14, color: context.textSecondary)),
559: const Text('ИТОГО', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
691: _paymentMethodButton('CASH', 'Наличные', Icons.money),
693: _paymentMethodButton('CARD', 'Карта', Icons.credit_card),
695: _paymentMethodButton('DEBT', 'В долг', Icons.access_time),
697: _paymentMethodButton('MIXED', 'Смешанная', Icons.compare_arrows),
705: text: 'Оформить продажу — ${_formatPrice(cartState.total)}',
735: ? '${cart.redemptionPoints} баллов = -$redeemValue сом'
736: : '${cart.customerLoyaltyPoints} баллов доступно',
764: const Text('Списать баллы',
767: Text('Доступно: ${cart.customerLoyaltyPoints} баллов'),
780: 'Скидка: -${(selected * cart.loyaltyPointValue).toStringAsFixed(2)} сом',
791: child: const Text('Применить'),
847: title: const Text('Скидка'),
909: hintText: discountType == 'PERCENTAGE' ? 'Процент' : 'Сумма',
922: child: const Text('Сбросить'),
```

Note: `'Применить'` also appears a second time at line 931
(`_showDiscountDialog`'s Apply button) with identical text — same key,
second call site, covered in Step 4's table. `'Скидка'` also appears a
second time at line 847 (the discount-edit dialog's title) with identical
text — same key, second call site. Line 909 hides a **second** hardcoded
Cyrillic literal (`'Сумма'`) that `check_i18n.dart`'s per-line regex didn't
flag (it only captures the first Cyrillic-containing quoted string per
line) — fix it anyway in this same pass, same as the prior project's Task 4
precedent for dual-ternary lines.

- [ ] **Step 1: Check for reusable existing keys**

Run:
```
grep -n '"debt"\|"selectCustomer"\|"card"\|"pos"\|"cash"\|"subtotal"\|"discount"\|"emptyCart"\|"apply"\|"dashboardStoreFallback"\|"pcs"' lib/l10n/app_ru.arb
```
Expected, all exact character-for-character matches confirmed by reading
the file — reuse every one of these, do not mint new keys for them:
- `debt: "В долг"` → line 695
- `selectCustomer: "Выберите клиента"` → line 184
- `card: "Карта"` → line 693
- `pos: "Касса"` → line 283 (this key already exists at the top of the
  checkout-keys block; `navPOS` also holds `"Касса"` but is nav-menu scoped
  — prefer `pos` since it sits in the same checkout-domain key block)
- `cash: "Наличные"` → line 691
- `subtotal: "Подытог"` → line 514
- `discount: "Скидка"` → lines 525 **and** 847 (reuse the same key at both
  call sites)
- `emptyCart: "Корзина пуста"` → line 427
- `apply: "Применить"` → lines 791 **and** 931 (reuse the same key at both
  call sites)
- `dashboardStoreFallback: "Магазин"` → line 255 (its own `@description`
  is literally "Fallback store name shown before a store is selected" —
  exactly this call site's use)
- `pcs: "шт"` → line 484 (reuse via interpolation, not a composite key —
  see Step 4)

**Do NOT reuse** `mixed: "Смешанная оплата"` for line 697's bare
`'Смешанная'` — the stored value has an extra word ("оплата") and does not
match character-for-character. Mint a new bare key instead (Step 2).
**Do NOT reuse** `total: "Итого"` for line 559's `'ИТОГО'` — different
case, not a character match (this screen's totals row is deliberately
all-caps for emphasis, distinct from the title-case `total` used
elsewhere). Mint a new key instead.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

Check `grep -n '"posCheckout' lib/l10n/app_ru.arb` first (expect no hits —
this is the first `posCheckout*`-prefixed key). Add this block near the
existing checkout/cart keys (`checkout`, `cart`, `emptyCart`, `subtotal`,
`discount`, `total`, `cash`, `card`, `debt`, `mixed` — around the existing
`"mixed": "Смешанная оплата"` entry) for contiguity, plus two bare/generic
keys placed near other single-word generic actions (`cancel`, `save`,
`apply`):

```json
  "posCheckoutNoCustomerOption": "Без клиента",
  "noCustomers": "Нет клиентов",
  "@noCustomers": { "description": "Generic empty state for a customer picker list — deliberately unprefixed since any customer-selection UI could plausibly reuse it" },
  "posCheckoutSearchHint": "Поиск по названию",
  "posCheckoutEmptyCartSubtitle": "Найдите товар через поиск или выберите из списка выше",
  "posCheckoutCartHeader": "Корзина ({count} товаров)",
  "posCheckoutTotalCaps": "ИТОГО",
  "@posCheckoutTotalCaps": { "description": "All-caps totals-row label on the checkout screen, used for visual emphasis — distinct from `total` (\"Итого\", title case) used elsewhere; do not merge, the case difference is a deliberate style choice on this screen" },
  "posCheckoutCta": "Оформить продажу — {total}",
  "posCheckoutPointsRedeemPreview": "{points} баллов = -{value} сом",
  "posCheckoutPointsAvailableInline": "{points} баллов доступно",
  "posCheckoutRedeemPointsTitle": "Списать баллы",
  "posCheckoutPointsAvailableLabel": "Доступно: {points} баллов",
  "posCheckoutDiscountPreview": "Скидка: -{amount} сом",
  "posCheckoutDiscountPercentHint": "Процент",
  "posCheckoutDiscountAmountHint": "Сумма",
  "reset": "Сбросить",
  "@reset": { "description": "Generic 'Reset' action — deliberately unprefixed, same class of generic action word as cancel/save/delete/create/retry" },
  "paymentMixedShort": "Смешанная",
  "@paymentMixedShort": { "description": "Bare 'Mixed' payment-method label (as used on compact payment-method selector buttons/status labels) — distinct from `mixed` (\"Смешанная оплата\", the fuller phrase used in the checkout confirmation flow). Shared across pos_checkout_page.dart and transaction_detail_page.dart, both of which use the bare form for the same UI role (a compact payment-method chip/label)." },
```

Placeholder metadata (all `String`-typed per convention, pre-formatted at
the call site):

```json
  "@posCheckoutCartHeader": {
    "placeholders": { "count": { "type": "String" } }
  },
  "@posCheckoutCta": {
    "placeholders": { "total": { "type": "String" } }
  },
  "@posCheckoutPointsRedeemPreview": {
    "placeholders": {
      "points": { "type": "String" },
      "value": { "type": "String" }
    }
  },
  "@posCheckoutPointsAvailableInline": {
    "placeholders": { "points": { "type": "String" } }
  },
  "@posCheckoutPointsAvailableLabel": {
    "placeholders": { "points": { "type": "String" } }
  },
  "@posCheckoutDiscountPreview": {
    "placeholders": { "amount": { "type": "String" } }
  },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

| Find | Replace with |
|---|---|
| `const Text('Выберите клиента',` | `Text(l10n.selectCustomer,` |
| `child: const Text('Без клиента'),` | `child: Text(l10n.posCheckoutNoCustomerOption),` |
| `return Center(\n                            child: Text('Нет клиентов', style: TextStyle(color: context.textSecondary)),\n                          );` | `return Center(\n                            child: Text(l10n.noCustomers, style: TextStyle(color: context.textSecondary)),\n                          );` |
| `: 'Магазин';` | `: l10n.dashboardStoreFallback;` |
| `const Text('Касса',` | `Text(l10n.pos,` |
| `hintText: 'Поиск по названию',` | `hintText: l10n.posCheckoutSearchHint,` |
| `title: 'Корзина пуста',` | `title: l10n.emptyCart,` |
| `subtitle: 'Найдите товар через поиск или выберите из списка выше',` | `subtitle: l10n.posCheckoutEmptyCartSubtitle,` |
| `subtitle: Text('${product.quantity} шт', style: TextStyle(fontSize: 12, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),` | `subtitle: Text('${product.quantity} ${l10n.pcs}', style: TextStyle(fontSize: 12, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),` |
| `Text('Корзина (${cartState.itemCount} товаров)',` | `Text(l10n.posCheckoutCartHeader(cartState.itemCount.toString()),` |
| `Text('Подытог', style: TextStyle(fontSize: 14, color: context.textSecondary)),` | `Text(l10n.subtotal, style: TextStyle(fontSize: 14, color: context.textSecondary)),` |
| `Text('Скидка', style: TextStyle(fontSize: 14, color: context.textSecondary)),` | `Text(l10n.discount, style: TextStyle(fontSize: 14, color: context.textSecondary)),` |
| `const Text('ИТОГО', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),` | `Text(l10n.posCheckoutTotalCaps, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),` |
| `_paymentMethodButton('CASH', 'Наличные', Icons.money),` | `_paymentMethodButton('CASH', l10n.cash, Icons.money),` |
| `_paymentMethodButton('CARD', 'Карта', Icons.credit_card),` | `_paymentMethodButton('CARD', l10n.card, Icons.credit_card),` |
| `_paymentMethodButton('DEBT', 'В долг', Icons.access_time),` | `_paymentMethodButton('DEBT', l10n.debt, Icons.access_time),` |
| `_paymentMethodButton('MIXED', 'Смешанная', Icons.compare_arrows),` | `_paymentMethodButton('MIXED', l10n.paymentMixedShort, Icons.compare_arrows),` |
| `text: 'Оформить продажу — ${_formatPrice(cartState.total)}',` | `text: l10n.posCheckoutCta(_formatPrice(cartState.total)),` |
| `? '${cart.redemptionPoints} баллов = -$redeemValue сом'` | `? l10n.posCheckoutPointsRedeemPreview(cart.redemptionPoints.toString(), redeemValue)` |
| `: '${cart.customerLoyaltyPoints} баллов доступно',` | `: l10n.posCheckoutPointsAvailableInline(cart.customerLoyaltyPoints.toString()),` |
| `const Text('Списать баллы',` | `Text(l10n.posCheckoutRedeemPointsTitle,` |
| `Text('Доступно: ${cart.customerLoyaltyPoints} баллов'),` | `Text(l10n.posCheckoutPointsAvailableLabel(cart.customerLoyaltyPoints.toString())),` |
| `'Скидка: -${(selected * cart.loyaltyPointValue).toStringAsFixed(2)} сом',` | `l10n.posCheckoutDiscountPreview((selected * cart.loyaltyPointValue).toStringAsFixed(2)),` |
| `child: const Text('Применить'),` (line 791, redemption sheet) | `child: Text(l10n.apply),` |
| `title: const Text('Скидка'),` | `title: Text(l10n.discount),` |
| `hintText: discountType == 'PERCENTAGE' ? 'Процент' : 'Сумма',` | `hintText: discountType == 'PERCENTAGE' ? l10n.posCheckoutDiscountPercentHint : l10n.posCheckoutDiscountAmountHint,` |
| `child: const Text('Сбросить'),` | `child: Text(l10n.reset),` |
| `child: const Text('Применить'),` (line 931, discount dialog) | `child: Text(l10n.apply),` |

Add `final l10n = AppLocalizations.of(context)!;` at the top of
`_showCustomerSelection()`, `_showDiscountDialog()`, and
`_showRedemptionSheet(BuildContext context, CartState cart)` before their
first use of `l10n` (matching `_confirmCardPayment`'s existing pattern).
Since two of these three methods have `showModalBottomSheet`/`showDialog`
builders that re-parameter-shadow `context`, make sure every reference
inside those nested closures uses the captured `l10n` variable, not a
fresh `AppLocalizations.of(<shadowed context>)` call.

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep pos_checkout_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/pos/pos_checkout_page_test.dart test/presentation/pages/pos/pos_checkout_page_golden_test.dart --reporter expanded` — expect passing. Note: `test/presentation/pages/pos/failures/` already contains prior golden-diff artifacts (`pos_checkout_*_isolatedDiff.png` etc.) from an earlier, unrelated run — if the golden test fails after this migration, verify per the design spec's baseline-check technique (throwaway worktree at the parent commit) whether the same mismatch pre-exists there before treating it as a regression.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/pos/pos_checkout_page.dart
git commit -m "fix(app): migrate pos_checkout_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 6: Migrate `transaction_detail_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/sales/transaction_detail_page.dart`

`TransactionDetailPage` is a `StatelessWidget`. Its `_paymentTypeLabel(String
type)` and `_statusLabel(String status)` instance methods currently take no
`BuildContext`/`l10n` — unlike `State` subclasses, a `StatelessWidget`'s own
instance methods have **no** inherited `context` getter, so these two must
have a parameter threaded in explicitly. `_statusColor(BuildContext context,
String status)` already establishes the file's own precedent for this
(taking `BuildContext context` as its first parameter) — but since `build()`
already computes `final l10n = AppLocalizations.of(context)!;` at its top
(line 57), the simplest change is to thread `AppLocalizations l10n`
directly into the two string-returning methods instead of re-deriving it
from a threaded `BuildContext`: change signatures to `_paymentTypeLabel(
AppLocalizations l10n, String type)` and `_statusLabel(AppLocalizations
l10n, String status)`, and update their two call sites (line 96 and line
126) to pass `l10n` as the first argument.

Current offenders (all 23, verbatim):
```
23: case 'CASH': return 'Наличные';
24: case 'CARD': return 'Карта';
25: case 'DEBT': return 'В долг';
26: case 'MIXED': return 'Смешанная';
33: case 'COMPLETED': return 'Оплачен';
34: case 'RETURNED': return 'Возвращён';
35: case 'PARTIALLY_RETURNED': return 'Частичный возврат';
76: Text('Чек ${sale.receiptNo}',
117: const Text('Информация',
120: _InfoRow(label: 'Дата', value: dateFormat.format(sale.createdAt)),
122: _InfoRow(label: 'Кассир', value: sale.staffId ?? '—'),
124: _InfoRow(label: 'Клиент', value: sale.customerName ?? 'Розничный'),
126: _InfoRow(label: 'Оплата', value: _paymentTypeLabel(sale.paymentType)),
143: const Text('Товары',
150: child: Text('Нет данных о товарах',
171: Text('${item.quantity} шт × ${_formatPrice(item.unitPrice)}',
202: const Text('Итого',
205: _TotalRow(label: 'Подытог', value: _formatPrice(sale.subtotal)),
207: _TotalRow(label: 'Скидка', value: _formatPrice(sale.discount)),
214: _TotalRow(label: 'Оплачено', value: _formatPrice(sale.paidAmount)),
216: _TotalRow(label: 'Сдача', value: _formatPrice(sale.change)),
247: label: const Text('Печатать чек',
265: label: const Text('Возврат',
```

Note: `'Итого'` also appears a second time at line 212
(`_TotalRow(label: 'Итого', ..., isBold: true)`) with identical text — same
key, second call site, covered below. Line 124 hides a **second** hardcoded
Cyrillic literal (`'Розничный'`, the walk-in-customer fallback name) that
the per-line regex didn't flag — fix it in this same pass.

- [ ] **Step 1: Check for reusable existing keys**

Run:
```
grep -n '"debt"\|"card"\|"cash"\|"subtotal"\|"discount"\|"total"\|"products"\|"change"\|"payment"\|"refund"\|"partiallyReturned"\|"date"\|"cashier"\|"deliveryDetailCustomerLabel"\|"paid"\|"completed"\|"returned"\|"printReceipt"\|"receiptNo"\|"dashboardSaleReceiptLabel"' lib/l10n/app_ru.arb
```

Exact character-for-character matches confirmed — reuse all of these:
- `debt: "В долг"` → line 25
- `card: "Карта"` → line 24
- `cash: "Наличные"` → line 23
- `subtotal: "Подытог"` → line 205
- `discount: "Скидка"` → line 207
- `total: "Итого"` → lines 202 **and** 212 (reuse the same key at both
  call sites — this is title-case "Итого", an exact match, unlike
  Task 5's all-caps "ИТОГО" which was correctly *not* reused)
- `products: "Товары"` → line 143
- `change: "Сдача"` → line 216
- `payment: "Оплата"` → line 126
- `refund: "Возврат"` → line 265
- `partiallyReturned: "Частичный возврат"` → line 35
- `date: "Дата"` → line 120
- `cashier: "Кассир"` → line 122
- `deliveryDetailCustomerLabel: "Клиент"` → line 124. Cross-feature reuse
  (delivery detail vs. sales transaction) is intentional per
  `.claude/rules/mobile-l10n.md`'s "reuse regardless of render location"
  rule — the text and role (a bare "Customer" field label) are identical;
  this is a genuinely-identical concept, not a near-duplicate needing its
  own key.
- `paid: "Оплачено"` → line 214
- `paymentMixedShort: "Смешанная"` (minted in **Task 5**) → line 26. Cross-
  file reuse — Task 5 already established this bare key for exactly this
  UI role (a compact payment-method label); do not mint a second one here.

**Do NOT reuse** the following near-misses — each differs from this
file's actual text and would silently change displayed copy if forced:
- `completed: "Завершена"` — different word entirely from this file's
  `'Оплачен'` (line 33). Not a match.
- `returned: "Возвращена"` — different grammatical gender ending from this
  file's `'Возвращён'` (line 34: masculine, agreeing with "чек"/receipt;
  the existing key is feminine). Not a match.
- `printReceipt: "Печать чека"` — a noun-form ("printing of the receipt")
  vs. this file's `'Печатать чек'` (line 247: imperative verb form,
  "Print receipt"). Not a match.
- `receiptNo: "Чек №"` and `dashboardSaleReceiptLabel: "Чек #{receiptNo}"`
  — neither matches this file's `'Чек ${sale.receiptNo}'` (line 76: no
  `№`/`#` symbol, plain space before the number). Two near-miss candidates
  for the same "Чек" prefix already exist in the ARB; this is exactly the
  kind of trap the mandatory value-verification rule exists to catch — mint
  a **third**, distinct key (Step 2).

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "transactionDetailItemQtyLine": "{quantity} шт × {price}",
  "transactionDetailStatusReturned": "Возвращён",
  "@transactionDetailStatusReturned": { "description": "Sale status badge — 'Returned' (masculine form, agrees with 'чек'). Distinct from `returned` (\"Возвращена\", feminine form used elsewhere) — different grammatical gender, do not merge." },
  "transactionDetailInfoSectionTitle": "Информация",
  "transactionDetailNoItemsData": "Нет данных о товарах",
  "transactionDetailStatusPaid": "Оплачен",
  "@transactionDetailStatusPaid": { "description": "Sale status badge — 'Paid/Completed'. Distinct from `completed` (\"Завершена\", a different word) and `paid` (\"Оплачено\", a different grammatical form used for the paid-amount value row on this same screen) — do not merge any of the three." },
  "transactionDetailPrintReceiptButton": "Печатать чек",
  "@transactionDetailPrintReceiptButton": { "description": "Imperative-form 'Print receipt' button label. Distinct from `printReceipt` (\"Печать чека\", noun form used elsewhere) — different grammatical form, do not merge." },
  "transactionDetailReceiptTitle": "Чек {receiptNo}",
  "@transactionDetailReceiptTitle": { "description": "Receipt-detail screen header. Distinct from `receiptNo` (\"Чек №\") and `dashboardSaleReceiptLabel` (\"Чек #{receiptNo}\") — this screen's header has no separating symbol before the number, unlike either existing candidate; do not merge." },
  "transactionDetailRetailCustomerFallback": "Розничный",
  "@transactionDetailRetailCustomerFallback": { "description": "Fallback customer name shown when a sale has no linked customer (walk-in/retail sale) — deliberately unprefixed-in-spirit but kept file-scoped here since no other screen currently needs it; a future task can genericize if reused" }
```

Placeholder metadata:

```json
  "@transactionDetailItemQtyLine": {
    "placeholders": {
      "quantity": { "type": "String" },
      "price": { "type": "String" }
    }
  },
  "@transactionDetailReceiptTitle": {
    "placeholders": { "receiptNo": { "type": "String" } }
  },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

| Find | Replace with |
|---|---|
| `case 'CASH': return 'Наличные';` | `case 'CASH': return l10n.cash;` |
| `case 'CARD': return 'Карта';` | `case 'CARD': return l10n.card;` |
| `case 'DEBT': return 'В долг';` | `case 'DEBT': return l10n.debt;` |
| `case 'MIXED': return 'Смешанная';` | `case 'MIXED': return l10n.paymentMixedShort;` |
| `case 'COMPLETED': return 'Оплачен';` | `case 'COMPLETED': return l10n.transactionDetailStatusPaid;` |
| `case 'RETURNED': return 'Возвращён';` | `case 'RETURNED': return l10n.transactionDetailStatusReturned;` |
| `case 'PARTIALLY_RETURNED': return 'Частичный возврат';` | `case 'PARTIALLY_RETURNED': return l10n.partiallyReturned;` |
| `Text('Чек ${sale.receiptNo}',` | `Text(l10n.transactionDetailReceiptTitle(sale.receiptNo),` |
| `const Text('Информация',` | `Text(l10n.transactionDetailInfoSectionTitle,` |
| `_InfoRow(label: 'Дата', value: dateFormat.format(sale.createdAt)),` | `_InfoRow(label: l10n.date, value: dateFormat.format(sale.createdAt)),` |
| `_InfoRow(label: 'Кассир', value: sale.staffId ?? '—'),` | `_InfoRow(label: l10n.cashier, value: sale.staffId ?? '—'),` |
| `_InfoRow(label: 'Клиент', value: sale.customerName ?? 'Розничный'),` | `_InfoRow(label: l10n.deliveryDetailCustomerLabel, value: sale.customerName ?? l10n.transactionDetailRetailCustomerFallback),` |
| `_InfoRow(label: 'Оплата', value: _paymentTypeLabel(sale.paymentType)),` | `_InfoRow(label: l10n.payment, value: _paymentTypeLabel(l10n, sale.paymentType)),` |
| `const Text('Товары',` | `Text(l10n.products,` |
| `child: Text('Нет данных о товарах',` | `child: Text(l10n.transactionDetailNoItemsData,` |
| `Text('${item.quantity} шт × ${_formatPrice(item.unitPrice)}',` | `Text(l10n.transactionDetailItemQtyLine(item.quantity.toString(), _formatPrice(item.unitPrice)),` |
| `const Text('Итого',` | `Text(l10n.total,` |
| `_TotalRow(label: 'Подытог', value: _formatPrice(sale.subtotal)),` | `_TotalRow(label: l10n.subtotal, value: _formatPrice(sale.subtotal)),` |
| `_TotalRow(label: 'Скидка', value: _formatPrice(sale.discount)),` | `_TotalRow(label: l10n.discount, value: _formatPrice(sale.discount)),` |
| `_TotalRow(label: 'Итого', value: _formatPrice(sale.total), isBold: true),` | `_TotalRow(label: l10n.total, value: _formatPrice(sale.total), isBold: true),` |
| `_TotalRow(label: 'Оплачено', value: _formatPrice(sale.paidAmount)),` | `_TotalRow(label: l10n.paid, value: _formatPrice(sale.paidAmount)),` |
| `_TotalRow(label: 'Сдача', value: _formatPrice(sale.change)),` | `_TotalRow(label: l10n.change, value: _formatPrice(sale.change)),` |
| `label: const Text('Печатать чек',` | `label: Text(l10n.transactionDetailPrintReceiptButton,` |
| `label: const Text('Возврат',` | `label: Text(l10n.refund,` |

Also update the method signatures and their call sites:

```dart
// before
String _paymentTypeLabel(String type) { ... }
String _statusLabel(String status) { ... }
// ...
child: Text(_statusLabel(sale.status), ...)
// ...
_InfoRow(label: 'Оплата', value: _paymentTypeLabel(sale.paymentType)),
```
```dart
// after
String _paymentTypeLabel(AppLocalizations l10n, String type) { ... }
String _statusLabel(AppLocalizations l10n, String status) { ... }
// ...
child: Text(_statusLabel(l10n, sale.status), ...)
// ...
_InfoRow(label: l10n.payment, value: _paymentTypeLabel(l10n, sale.paymentType)),
```

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep transaction_detail_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/sales/transaction_detail_page_test.dart test/presentation/pages/sales/transaction_detail_page_golden_test.dart --reporter expanded` — expect passing (goldens at `test/presentation/pages/sales/goldens/transaction_detail_{light,dark}.png` — no visible text changes expected since every replacement preserves the exact Russian string).

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/sales/transaction_detail_page.dart
git commit -m "fix(app): migrate transaction_detail_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 7: Migrate `zakat_settings_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/zakat/zakat_settings_page.dart`

This is a `State<ZakatSettingsPage>` class — `build()` already declares
`final l10n = AppLocalizations.of(context)!;` at its top. All the string
literals below are either directly inside `build()` or inside
`_buildSectionLabel(String title)` / `_buildCard(List<Widget> children)` /
`_buildToggleRow(String title, String? subtitle, {...})` call *sites*
(these three helpers take plain `String` parameters — no signature change
needed, just pass `l10n.xxx` from the call site). The two numeric-field
`validator:` closures are defined inside `BlocConsumer`'s
`builder: (context, state) {...}` callback, which **shadows** the
identifier `context` — but not `l10n`, which was already computed with the
outer, unshadowed `context` before the `BlocConsumer` was built; reference
that captured `l10n` inside the validators directly.

**Cross-file note (per this project's zakat-pair reuse check):** this
file's offender `'Дебиторская задолженность'` (line 394) is **identical**
to an offender in `zakat_calculator_page.dart` (Task 8) — but rather than
minting a new shared key, the ARB **already has** an exact-match existing
key for it (`receivables`, see Step 1) — reuse that in both tasks. This
file's line 394 also hides a second, unflagged Cyrillic literal
(`'Долги клиентов'`, the toggle's subtitle) that is *also* shared with
Task 8's offender list, and the ARB already has an exact match for that
too (`customerDebts`) — reuse it here as well, and Task 8 will reuse the
same key. No new shared key needs to be minted for either.

Current offenders (all 21, verbatim):
```
145: const Text('Настройки закята',
190: _buildSectionLabel('МЕТОД РАСЧЁТА'),
198: child: Text('Стандарт нисаба',
202: title: Text('По золоту (85g)', style: TextStyle(fontSize: 14)),
209: title: Text('По серебру (595g)', style: TextStyle(fontSize: 14)),
227: const Text('Курс золота (за 1g)',
234: if (v == null || v.isEmpty) return 'Обязательное поле';
236: if (parsed == null) return 'Введите число';
237: if (parsed < 0) return 'Не может быть отрицательным';
277: const Text('Наличные в кассе',
291: helperText: 'Учитывается в активах при расчёте закята',
304: _buildSectionLabel('ЛУННЫЙ ГОД (ХАВЛЬ)'),
328: const Text('Дата начала хавля',
334: : 'Не выбрана',
364: Text('Напоминание',
366: Text('За 30 дней до окончания хавля',
383: _buildSectionLabel('АВТОМАТИЧЕСКИЕ ДАННЫЕ'),
386: _buildToggleRow('Товарные остатки магазина', 'Авто из каталога',
398: _buildToggleRow('Долги поставщикам (вычет)', 'Авто из модуля поставщиков',
416: state is ZakatLoading ? 'Сохранение...' : 'Сохранить',
```

Note: `'Введите число'` (line 236) and `'Не может быть отрицательным'`
(line 237) each appear a **second** time, identically, at lines 286/287 (the
cash-on-hand field's validator) — same keys, second call sites, covered
below. `'Наличные в кассе'` (line 277) appears a **second** time,
identically, at line 390 (the toggle row's title) — same key, second call
site. Lines 386, 398, and 416 each hide a **second**, unflagged hardcoded
Cyrillic literal (the `_buildToggleRow` subtitle argument, and the ternary's
other branch, respectively) — fix all three in this same pass:
- Line 386's subtitle `'Авто из каталога'`
- Line 398's subtitle `'Авто из модуля поставщиков'`
- Line 416's other branch `'Сохранить'`
And line 394 (`_buildToggleRow('Дебиторская задолженность', 'Долги
клиентов', ...)`) is itself one of the 21 official offenders (via its
first argument) but its second argument `'Долги клиентов'` is *also*
unflagged — fix it too (reuses `customerDebts`, see the cross-file note
above).

- [ ] **Step 1: Check for reusable existing keys**

Run:
```
grep -n '"zakatSettings"\|"receivables"\|"customerDebts"\|"save"\|"haulStartDate"' lib/l10n/app_ru.arb
```

- `zakatSettings: "Настройки закята"` → exact match for line 145 (this key
  is already consumed elsewhere in the app as a tooltip in
  `zakat_calculator_page.dart` — confirms it's meant to be reused for this
  exact page-title role too).
- `receivables: "Дебиторская задолженность"` → exact match for line 394's
  first argument. Shared with Task 8.
- `customerDebts: "Долги клиентов"` → exact match for line 394's
  (unflagged) second argument. Shared with Task 8.
- `save: "Сохранить"` → exact match for line 416's unflagged second
  ternary branch.

**Do NOT reuse** `haulStartDate: "Дата начала хауля"` for line 328's
`'Дата начала хавля'` — the two strings differ by one letter
("хауля" vs "хавля", a `у`/`в` transliteration mismatch of the Islamic
lunar-year term "hawl"). This is exactly the kind of near-miss the
mandatory value-verification rule exists to catch; migrate this file's
literal text unchanged (don't silently "fix" the apparent inconsistency —
that's a separate, out-of-scope product decision) and mint its own key.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

Check `grep -n '"zakatSettings' lib/l10n/app_ru.arb` first (expect no
`zakatSettings*`-prefixed keys yet besides the bare `zakatSettings` page-
title key already reused above). Add this block near the existing
`zakat*` keys (~line 883-901):

```json
  "zakatSettingsMethodSection": "МЕТОД РАСЧЁТА",
  "zakatSettingsNisabStandardLabel": "Стандарт нисаба",
  "zakatSettingsNisabGoldOption": "По золоту (85g)",
  "zakatSettingsNisabSilverOption": "По серебру (595g)",
  "zakatSettingsGoldPriceLabel": "Курс золота (за 1g)",
  "requiredFieldError": "Обязательное поле",
  "@requiredFieldError": { "description": "Generic required-field form validation message — deliberately unprefixed, reusable across any form field in the app" },
  "requiredNumberError": "Введите число",
  "@requiredNumberError": { "description": "Generic 'enter a valid number' form validation message — deliberately unprefixed" },
  "cannotBeNegativeError": "Не может быть отрицательным",
  "@cannotBeNegativeError": { "description": "Generic 'value cannot be negative' form validation message — deliberately unprefixed" },
  "zakatSettingsCashOnHandLabel": "Наличные в кассе",
  "zakatSettingsCashHelperText": "Учитывается в активах при расчёте закята",
  "zakatSettingsHaulSection": "ЛУННЫЙ ГОД (ХАВЛЬ)",
  "zakatSettingsHaulStartDateLabel": "Дата начала хавля",
  "@zakatSettingsHaulStartDateLabel": { "description": "Haul (lunar year) start-date field label. NOTE: spelled 'хавля' here, matching this screen's current source text exactly — the existing `haulStartDate` key holds a differently-spelled 'хауля'. This discrepancy is pre-existing in the app and out of scope to reconcile in this migration; do not merge the two keys." },
  "zakatSettingsDateNotSelected": "Не выбрана",
  "zakatSettingsReminderTitle": "Напоминание",
  "zakatSettingsReminderSubtitle": "За 30 дней до окончания хавля",
  "zakatSettingsAutoDataSection": "АВТОМАТИЧЕСКИЕ ДАННЫЕ",
  "zakatSettingsStockValueToggleTitle": "Товарные остатки магазина",
  "@zakatSettingsStockValueToggleTitle": { "description": "Zakat-settings toggle row title. Distinct from zakat_calculator_page.dart's `zakatCalculatorStockValueLabel` (\"Товарные остатки\", no 'магазина' suffix) — different text, do not merge." },
  "zakatSettingsStockAutoSubtitle": "Авто из каталога",
  "zakatSettingsSupplierDebtsToggleTitle": "Долги поставщикам (вычет)",
  "@zakatSettingsSupplierDebtsToggleTitle": { "description": "Zakat-settings toggle row title. Distinct from zakat_calculator_page.dart's `zakatCalculatorSupplierDebtsLabel` (\"Долги поставщикам\", no '(вычет)' suffix) — different text, do not merge." },
  "zakatSettingsSupplierDebtsAutoSubtitle": "Авто из модуля поставщиков",
  "savingEllipsis": "Сохранение...",
  "@savingEllipsis": { "description": "Generic in-flight 'Saving...' button label — deliberately unprefixed, reusable on any save-button loading state" },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

| Find | Replace with |
|---|---|
| `const Text('Настройки закята',` | `Text(l10n.zakatSettings,` |
| `_buildSectionLabel('МЕТОД РАСЧЁТА'),` | `_buildSectionLabel(l10n.zakatSettingsMethodSection),` |
| `child: Text('Стандарт нисаба',` | `child: Text(l10n.zakatSettingsNisabStandardLabel,` |
| `title: Text('По золоту (85g)', style: TextStyle(fontSize: 14)),` | `title: Text(l10n.zakatSettingsNisabGoldOption, style: TextStyle(fontSize: 14)),` |
| `title: Text('По серебру (595g)', style: TextStyle(fontSize: 14)),` | `title: Text(l10n.zakatSettingsNisabSilverOption, style: TextStyle(fontSize: 14)),` |
| `const Text('Курс золота (за 1g)',` | `Text(l10n.zakatSettingsGoldPriceLabel,` |
| `if (v == null || v.isEmpty) return 'Обязательное поле';` | `if (v == null || v.isEmpty) return l10n.requiredFieldError;` |
| `if (parsed == null) return 'Введите число';` (gold-price validator, line 236) | `if (parsed == null) return l10n.requiredNumberError;` |
| `if (parsed < 0) return 'Не может быть отрицательным';` (gold-price validator, line 237) | `if (parsed < 0) return l10n.cannotBeNegativeError;` |
| `const Text('Наличные в кассе',` (line 277) | `Text(l10n.zakatSettingsCashOnHandLabel,` |
| `if (parsed == null) return 'Введите число';` (cash-on-hand validator, line 286) | `if (parsed == null) return l10n.requiredNumberError;` |
| `if (parsed < 0) return 'Не может быть отрицательным';` (cash-on-hand validator, line 287) | `if (parsed < 0) return l10n.cannotBeNegativeError;` |
| `helperText: 'Учитывается в активах при расчёте закята',` | `helperText: l10n.zakatSettingsCashHelperText,` |
| `_buildSectionLabel('ЛУННЫЙ ГОД (ХАВЛЬ)'),` | `_buildSectionLabel(l10n.zakatSettingsHaulSection),` |
| `const Text('Дата начала хавля',` | `Text(l10n.zakatSettingsHaulStartDateLabel,` |
| `: 'Не выбрана',` | `: l10n.zakatSettingsDateNotSelected,` |
| `Text('Напоминание',` | `Text(l10n.zakatSettingsReminderTitle,` |
| `Text('За 30 дней до окончания хавля',` | `Text(l10n.zakatSettingsReminderSubtitle,` |
| `_buildSectionLabel('АВТОМАТИЧЕСКИЕ ДАННЫЕ'),` | `_buildSectionLabel(l10n.zakatSettingsAutoDataSection),` |
| `_buildToggleRow('Товарные остатки магазина', 'Авто из каталога',` | `_buildToggleRow(l10n.zakatSettingsStockValueToggleTitle, l10n.zakatSettingsStockAutoSubtitle,` |
| `_buildToggleRow('Наличные в кассе', null,` (line 390) | `_buildToggleRow(l10n.zakatSettingsCashOnHandLabel, null,` |
| `_buildToggleRow('Дебиторская задолженность', 'Долги клиентов',` | `_buildToggleRow(l10n.receivables, l10n.customerDebts,` |
| `_buildToggleRow('Долги поставщикам (вычет)', 'Авто из модуля поставщиков',` | `_buildToggleRow(l10n.zakatSettingsSupplierDebtsToggleTitle, l10n.zakatSettingsSupplierDebtsAutoSubtitle,` |
| `state is ZakatLoading ? 'Сохранение...' : 'Сохранить',` | `state is ZakatLoading ? l10n.savingEllipsis : l10n.save,` |

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep zakat_settings_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/zakat/zakat_settings_page_test.dart test/presentation/pages/zakat/zakat_settings_page_golden_test.dart --reporter expanded` — expect passing. Note: `test/presentation/pages/zakat/failures/` already contains prior golden-diff artifacts from an earlier, unrelated run — if the golden test fails here, verify via the design spec's throwaway-worktree baseline check before treating it as a regression.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/zakat/zakat_settings_page.dart
git commit -m "fix(app): migrate zakat_settings_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 8: Migrate `zakat_calculator_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/zakat/zakat_calculator_page.dart`

This is a `State<ZakatCalculatorPage>` class — `build()` already declares
`final l10n = AppLocalizations.of(context)!;` at its top. All offenders
below are either directly inside `build()` or passed as `String` arguments
into `_buildAssetCard({required String title, String? subtitle, String?
badge, ...})`, called three times from within `build()` — no signature
change needed, just pass `l10n.xxx` from each call site.

**Cross-file note (must land after or alongside Task 7):** this file's
offender `'Дебиторская задолженность'` (line 162) is identical to
`zakat_settings_page.dart`'s offender at line 394 — reuse the existing ARB
key `receivables` (not a new key) for both, per Task 7's Step 1. This
file's offender `'Долги клиентов'` (line 165) is identical to
`zakat_settings_page.dart`'s unflagged co-offender at line 394 — reuse the
existing ARB key `customerDebts` (not a new key) for both. If Task 7 has
not yet run `flutter gen-l10n` when this task starts, both keys already
exist in `app_ru.arb` independent of Task 7's edits (they predate this
project), so this task has no ordering dependency on Task 7 — it's purely
a documentation cross-reference, not a build dependency.

Current offenders (all 21, verbatim):
```
81: Text('Калькулятор закята',
130: 'Закят — ${calc.zakatRate.toStringAsFixed(1)}% от имущества, хранящегося 1 лунный год',
139: Text('АКТИВЫ МАГАЗИНА',
151: title: 'Товарные остатки',
154: subtitle: 'Автоматически из каталога',
155: badge: 'Авто',
162: title: 'Дебиторская задолженность',
165: subtitle: 'Долги клиентов',
173: Text('ВЫЧЕТЫ',
185: title: 'Долги поставщикам',
190: subtitle: 'Автоматически из модуля',
214: Text('Облагаемая сумма:',
224: Text('Нисаб (85г золота):',
234: const Text('Превышен',
245: Text('СУММА ЗАКЯТА (${calc.zakatRate.toStringAsFixed(1)}%):',
268: child: Text('Активы ниже нисаба. Закят не обязателен.',
299: child: const Text('Отметить как оплачено',
314: final text = 'Закят: ${c.zakatDue.toStringAsFixed(2)} сом.\n'
315:     'Нисаб: ${c.nisabAmount.toStringAsFixed(2)} сом.\n'
316:     'Чистые активы: ${c.netAssets.toStringAsFixed(2)} сом.';
326: label: const Text('Поделиться расчётом',
```

Note: `badge: 'Авто'` (line 155) is one offender key but the exact literal
`badge: 'Авто'` appears **twice more**, identically, at lines 166 and 191
(the receivables and payables asset cards) — same key, three call sites
total, all covered below. Lines 314-316 are three separate adjacent-string-
literal pieces of **one** concatenated multi-line share-text value passed
to `Share.share(...)` — per `.claude/rules/mobile-l10n.md`'s
label+separator+value composite rule, these become **one** full-sentence
key with three placeholders rather than three half-sentence keys.

- [ ] **Step 1: Check for reusable existing keys**

Run:
```
grep -n '"zakatCalculator"\|"receivables"\|"customerDebts"' lib/l10n/app_ru.arb
```

- `zakatCalculator: "Калькулятор закята"` → exact match for line 81 (page
  title). Already consumed elsewhere in this same file as a semantics
  label if applicable — confirm no second, conflicting local `l10n`
  binding is introduced.
- `receivables: "Дебиторская задолженность"` → exact match for line 162.
  Shared with Task 7 (see cross-file note above).
- `customerDebts: "Долги клиентов"` → exact match for line 165. Shared
  with Task 7.

**Do NOT reuse** `payables: "Кредиторская задолженность"` for line 185's
`'Долги поставщикам'` — different word entirely ("payables"/accounts-
payable accounting term vs. the plain-language "debts to suppliers" used
on this screen). Not a match — mint a new key.
**Do NOT reuse** `stockValue: "Стоимость товаров"` for line 151's
`'Товарные остатки'` — different wording ("value of goods" vs. "goods on
hand/remainders"). Not a match — mint a new key.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

Check `grep -n '"zakatCalculator' lib/l10n/app_ru.arb` first (expect no
`zakatCalculator*`-prefixed keys yet besides the bare `zakatCalculator`
page-title key already reused above). Add this block near the existing
`zakat*` keys:

```json
  "zakatCalculatorAssetsSection": "АКТИВЫ МАГАЗИНА",
  "zakatCalculatorStockValueLabel": "Товарные остатки",
  "@zakatCalculatorStockValueLabel": { "description": "Zakat-calculator asset-card title. Distinct from zakat_settings_page.dart's `zakatSettingsStockValueToggleTitle` (\"Товарные остатки магазина\", with a 'магазина' suffix) — different text, do not merge." },
  "zakatCalculatorAutoFromCatalog": "Автоматически из каталога",
  "zakatCalculatorAutoBadge": "Авто",
  "zakatCalculatorSupplierDebtsLabel": "Долги поставщикам",
  "@zakatCalculatorSupplierDebtsLabel": { "description": "Zakat-calculator asset-card title. Distinct from zakat_settings_page.dart's `zakatSettingsSupplierDebtsToggleTitle` (\"Долги поставщикам (вычет)\", with a '(вычет)' suffix) — different text, do not merge." },
  "zakatCalculatorAutoFromSupplierModule": "Автоматически из модуля",
  "zakatCalculatorDeductionsSection": "ВЫЧЕТЫ",
  "zakatCalculatorTaxableAmountLabel": "Облагаемая сумма:",
  "zakatCalculatorNisabLabel": "Нисаб (85г золота):",
  "zakatCalculatorNisabExceededBadge": "Превышен",
  "zakatCalculatorZakatAmountLabel": "СУММА ЗАКЯТА ({rate}%):",
  "zakatCalculatorBelowNisabNotice": "Активы ниже нисаба. Закят не обязателен.",
  "zakatCalculatorMarkPaidButton": "Отметить как оплачено",
  "zakatCalculatorInfoBanner": "Закят — {rate}% от имущества, хранящегося 1 лунный год",
  "zakatCalculatorShareText": "Закят: {due} сом.\nНисаб: {nisab} сом.\nЧистые активы: {netAssets} сом.",
  "@zakatCalculatorShareText": { "description": "Full multi-line text passed to the OS share sheet — combines what were three separate concatenated string literals into one full-sentence key per the label+separator+value composite convention" },
  "zakatCalculatorShareButton": "Поделиться расчётом",
```

Placeholder metadata (all `String`-typed, pre-formatted at the call site
exactly as the existing `.toStringAsFixed(...)` calls already do):

```json
  "@zakatCalculatorZakatAmountLabel": {
    "placeholders": { "rate": { "type": "String" } }
  },
  "@zakatCalculatorInfoBanner": {
    "placeholders": { "rate": { "type": "String" } }
  },
  "@zakatCalculatorShareText": {
    "placeholders": {
      "due": { "type": "String" },
      "nisab": { "type": "String" },
      "netAssets": { "type": "String" }
    }
  },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

| Find | Replace with |
|---|---|
| `Text('Калькулятор закята',` | `Text(l10n.zakatCalculator,` |
| `'Закят — ${calc.zakatRate.toStringAsFixed(1)}% от имущества, хранящегося 1 лунный год',` | `l10n.zakatCalculatorInfoBanner(calc.zakatRate.toStringAsFixed(1)),` |
| `Text('АКТИВЫ МАГАЗИНА',` | `Text(l10n.zakatCalculatorAssetsSection,` |
| `title: 'Товарные остатки',` | `title: l10n.zakatCalculatorStockValueLabel,` |
| `subtitle: 'Автоматически из каталога',` | `subtitle: l10n.zakatCalculatorAutoFromCatalog,` |
| `badge: 'Авто',` (line 155, stock card) | `badge: l10n.zakatCalculatorAutoBadge,` |
| `title: 'Дебиторская задолженность',` | `title: l10n.receivables,` |
| `subtitle: 'Долги клиентов',` | `subtitle: l10n.customerDebts,` |
| `badge: 'Авто',` (line 166, receivables card) | `badge: l10n.zakatCalculatorAutoBadge,` |
| `Text('ВЫЧЕТЫ',` | `Text(l10n.zakatCalculatorDeductionsSection,` |
| `title: 'Долги поставщикам',` | `title: l10n.zakatCalculatorSupplierDebtsLabel,` |
| `subtitle: 'Автоматически из модуля',` | `subtitle: l10n.zakatCalculatorAutoFromSupplierModule,` |
| `badge: 'Авто',` (line 191, payables card) | `badge: l10n.zakatCalculatorAutoBadge,` |
| `Text('Облагаемая сумма:',` | `Text(l10n.zakatCalculatorTaxableAmountLabel,` |
| `Text('Нисаб (85г золота):',` | `Text(l10n.zakatCalculatorNisabLabel,` |
| `const Text('Превышен',` | `Text(l10n.zakatCalculatorNisabExceededBadge,` |
| `Text('СУММА ЗАКЯТА (${calc.zakatRate.toStringAsFixed(1)}%):',` | `Text(l10n.zakatCalculatorZakatAmountLabel(calc.zakatRate.toStringAsFixed(1)),` |
| `child: Text('Активы ниже нисаба. Закят не обязателен.',` | `child: Text(l10n.zakatCalculatorBelowNisabNotice,` |
| `child: const Text('Отметить как оплачено',` | `child: Text(l10n.zakatCalculatorMarkPaidButton,` |
| `final text = 'Закят: ${c.zakatDue.toStringAsFixed(2)} сом.\n'\n                                    'Нисаб: ${c.nisabAmount.toStringAsFixed(2)} сом.\n'\n                                    'Чистые активы: ${c.netAssets.toStringAsFixed(2)} сом.';` | `final text = l10n.zakatCalculatorShareText(\n                                  c.zakatDue.toStringAsFixed(2),\n                                  c.nisabAmount.toStringAsFixed(2),\n                                  c.netAssets.toStringAsFixed(2),\n                                );` |
| `label: const Text('Поделиться расчётом',` | `label: Text(l10n.zakatCalculatorShareButton,` |

Note the `const` on `Text('Превышен', ...)`, `Text('Отметить как
оплачено', ...)` etc. must be dropped wherever the argument becomes a
non-const `l10n.xxx` call — the surrounding `const Row(...)` at lines
263-272 also needs its `const` dropped since one of its children
(`Text(l10n.zakatCalculatorBelowNisabNotice, ...)`) is no longer constant;
check that outer `const` when editing line 268's parent `Row`.

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep zakat_calculator_page.dart` — expect no output.
Run: `flutter analyze` — expect clean (in particular, verify the dropped `const` on the `Row` wrapping line 268 doesn't leave a stray unused `const` elsewhere that the analyzer flags).
Run: `flutter test test/presentation/pages/zakat/zakat_calculator_page_golden_test.dart test/presentation/pages/zakat/zakat_calculator_reload_test.dart --reporter expanded` — expect passing.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/zakat/zakat_calculator_page.dart
git commit -m "fix(app): migrate zakat_calculator_page.dart hardcoded strings to AppLocalizations"
```

---
### Task 9: Migrate `finance_dashboard_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/finance/finance_dashboard_page.dart`

This file already declares `final l10n = AppLocalizations.of(context)!;` in
`build()` (line 71) and uses it for `l10n.a11yOpenReports` — reuse that
binding for every call site inside `build()`. `_buildSectionsGrid()` is a
separate method on `_FinanceDashboardPageState` (a `State` subclass) with no
`BuildContext` parameter of its own — per this class being a `State`, it has
the inherited `context` getter usable from any instance method, so declare a
*second*, method-local `final l10n = AppLocalizations.of(context)!;` at the
top of `_buildSectionsGrid()` rather than trying to reuse `build()`'s local
variable across methods (it's out of scope there).

Current offenders (all 21, verbatim):
```
88: const Text('Финансы',
139: label: 'День',
145: label: 'Неделя',
151: label: 'Месяц',
157: label: '6 мес',
173: label: 'Общий доход',
184: label: 'Общие расходы',
199: label: 'Валовая прибыль',
210: label: 'Чистая прибыль',
221: const Text('Динамика',
239: const labels = ['Доход', 'Расход', 'Прибыль'];
291: const Text('Топ товары',
318: Text('${s.topProducts[i].quantity} шт',
359: _SectionItem('Баланс', Icons.account_balance_wallet_outlined,
361: _SectionItem('Кредиты', Icons.credit_card_outlined,
363: _SectionItem('Вложения', Icons.trending_up_outlined,
365: _SectionItem('Закят', Icons.volunteer_activism_outlined,
367: _SectionItem('Валюты', Icons.currency_exchange_outlined,
369: _SectionItem('Доставка', Icons.local_shipping_outlined,
371: _SectionItem('Отчёт', Icons.bar_chart_outlined,
373: _SectionItem('Расходы', Icons.money_off_outlined,
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"finances"\|"day"\|"week"\|"month"\|"income"\|"profit"\|"dynamics"\|"topProducts"\|"balance"\|"credits"\|"zakat"\|"expenses"' lib/l10n/app_ru.arb`

Expected, all already exist — reuse:
- `finances: "Финансы"` (line 88 header)
- `day: "День"`, `week: "Неделя"`, `month: "Месяц"` (period tab chips)
- `income: "Доход"` and `profit: "Прибыль"` — these match two of the three
  bar-chart axis labels on line 239 **exactly** (bare singular forms)
- `dynamics: "Динамика"`, `topProducts: "Топ товары"`
- `balance: "Баланс"`, `credits: "Кредиты"`, `zakat: "Закят"`
- `expenses: "Расходы"` (plural — matches the grid item on line 373 exactly)

**Important — do NOT reuse `expenses` for line 239's middle label.** The bar
chart's middle label is `'Расход'` (singular, no с), not `'Расходы'`
(plural). These are different rendered strings; reusing `expenses` here
would silently change the chart's on-screen text — exactly the kind of
character-for-character mismatch that shipped bugs `f54d5fd`/`bb6a1cc` in
the predecessor branch. Mint a distinct `financeChartExpenseLabel` key for
it (Step 2).

Also confirm none of `'Вложения'`, `'Валюты'`, `'Доставка'`, `'Отчёт'`,
`'6 мес'`, `'Общий доход'`, `'Общие расходы'`, `'Валовая прибыль'`,
`'Чистая прибыль'` already exist under some other name:
Run: `grep -n '"Вложения"\|"Валюты"\|"Доставка"\|"Отчёт"\|investments\|reportsPageTitle' lib/l10n/app_ru.arb`
Expected: no output — all five need new keys.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "financeDashboardPeriodHalfYear": "6 мес",
  "financeTotalIncome": "Общий доход",
  "financeTotalExpenses": "Общие расходы",
  "financeGrossProfit": "Валовая прибыль",
  "financeNetProfit": "Чистая прибыль",
  "financeChartExpenseLabel": "Расход",
  "@financeChartExpenseLabel": { "description": "Bar-chart x-axis label for the expense bar (bare singular form) — distinct from `expenses` (\"Расходы\", plural), which is the finance-dashboard grid item linking to the expenses list" },
  "financeDashboardQuantityUnit": "{quantity} шт",
  "@financeDashboardQuantityUnit": {
    "description": "Top-products list row — quantity sold with the abbreviated units suffix; quantity is pre-formatted to a string at the call site",
    "placeholders": { "quantity": { "type": "String" } }
  },
  "financeDashboardInvestments": "Вложения",
  "financeDashboardCurrencies": "Валюты",
  "financeDashboardDelivery": "Доставка",
  "financeDashboardReport": "Отчёт",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors.

- [ ] **Step 4: Replace literals**

| Find | Replace with |
|---|---|
| `const Text('Финансы',` | `Text(l10n.finances,` |
| `label: 'День',` | `label: l10n.day,` |
| `label: 'Неделя',` | `label: l10n.week,` |
| `label: 'Месяц',` | `label: l10n.month,` |
| `label: '6 мес',` | `label: l10n.financeDashboardPeriodHalfYear,` |
| `label: 'Общий доход',` | `label: l10n.financeTotalIncome,` |
| `label: 'Общие расходы',` | `label: l10n.financeTotalExpenses,` |
| `label: 'Валовая прибыль',` | `label: l10n.financeGrossProfit,` |
| `label: 'Чистая прибыль',` | `label: l10n.financeNetProfit,` |
| `const Text('Динамика',` | `Text(l10n.dynamics,` |
| `const labels = ['Доход', 'Расход', 'Прибыль'];` | `final labels = [l10n.income, l10n.financeChartExpenseLabel, l10n.profit];` |
| `const Text('Топ товары',` | `Text(l10n.topProducts,` |
| `Text('${s.topProducts[i].quantity} шт',` | `Text(l10n.financeDashboardQuantityUnit(s.topProducts[i].quantity.toString()),` |
| `_SectionItem('Баланс', Icons.account_balance_wallet_outlined,` | `_SectionItem(l10n.balance, Icons.account_balance_wallet_outlined,` |
| `_SectionItem('Кредиты', Icons.credit_card_outlined,` | `_SectionItem(l10n.credits, Icons.credit_card_outlined,` |
| `_SectionItem('Вложения', Icons.trending_up_outlined,` | `_SectionItem(l10n.financeDashboardInvestments, Icons.trending_up_outlined,` |
| `_SectionItem('Закят', Icons.volunteer_activism_outlined,` | `_SectionItem(l10n.zakat, Icons.volunteer_activism_outlined,` |
| `_SectionItem('Валюты', Icons.currency_exchange_outlined,` | `_SectionItem(l10n.financeDashboardCurrencies, Icons.currency_exchange_outlined,` |
| `_SectionItem('Доставка', Icons.local_shipping_outlined,` | `_SectionItem(l10n.financeDashboardDelivery, Icons.local_shipping_outlined,` |
| `_SectionItem('Отчёт', Icons.bar_chart_outlined,` | `_SectionItem(l10n.financeDashboardReport, Icons.bar_chart_outlined,` |
| `_SectionItem('Расходы', Icons.money_off_outlined,` | `_SectionItem(l10n.expenses, Icons.money_off_outlined,` |

**Notes:**
- Line 239's `const labels = [...]` is declared inside the nested
  `getTitlesWidget: (value, meta) { ... }` closure (itself nested inside
  `BarChartData` → `FlTitlesData` → `AxisTitles` → `SideTitles`, all still
  within the outer `BlocBuilder`'s `builder: (context, state) { ... }`
  closure, itself inside `build(context)`). The closure captures the outer
  `l10n` variable fine regardless of nesting depth — but the list can no
  longer be `const` once it contains getter calls, so change `const labels`
  to `final labels`.
- Only `'Доход'` on line 239 was flagged by `check_i18n.dart` as an offender
  (the tool's regex takes only the *first* Cyrillic-quoted match per line —
  `'Расход'` and `'Прибыль'` on the same line were never separately
  flagged). **You must still replace all three**, not just the flagged one:
  if you leave `'Расход'` and `'Прибыль'` as literals after removing
  `'Доход'`, the tool's first-match-per-line scan will newly flag whichever
  literal is now first on the line — Step 5's verification would fail with
  a *different* offender on the same line instead of a clean pass.
- `_buildSectionsGrid()`'s `sections` list (line 358, `final sections = [...]`)
  is already non-`const` — only the string literals inside the
  `_SectionItem(...)` constructors change; no structural edit needed beyond
  adding the method-local `l10n` declaration at the top of the method.
- `_KpiCardContent` and `_SectionItem` are helper classes instantiated from
  inside `build()`/`_buildSectionsGrid()` — the literals live at the
  *call site*, not inside those helper classes' own `build()` methods, so no
  `BuildContext` threading into `_KpiCardContent`/`_SectionItem` is needed.

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep finance_dashboard_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/finance/finance_dashboard_page_golden_test.dart test/presentation/pages/finance/finance_dashboard_clamp_test.dart --reporter expanded` — expect passing.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/finance/finance_dashboard_page.dart
git commit -m "fix(app): migrate finance_dashboard_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 10: Migrate `sales_history_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/sales/sales_history_page.dart`

This file already declares `final l10n = AppLocalizations.of(context)!;` in
`_SalesHistoryPageState.build()` (line 71) and uses it for `l10n.a11yFilter`
/ `l10n.a11yDownloadReport` — reuse that binding for every literal inside
that `build()`. Two call sites need extra threading because they live
*outside* that scope:
- `_SaleCard` (a `StatelessWidget`, separate class) has its own
  `build(BuildContext context)` — it needs its own local `l10n` declared
  there, and its private `_paymentLabel()` method (currently
  `String _paymentLabel()`, no parameters) must become
  `String _paymentLabel(BuildContext context)` so it can look up
  `AppLocalizations.of(context)!` — it's a plain instance method on a
  `StatelessWidget`, which (unlike a `State` subclass) has no inherited
  `context` getter of its own outside `build()`.
- `_pluralRecord(int n)` is a **top-level function** (declared outside any
  class, at the bottom of the file) — top-level functions have no
  `BuildContext` at all. Thread the localizations instance in directly as a
  parameter: `String _pluralRecord(int n, AppLocalizations l10n)`.

Current offenders (all 19, verbatim; note lines 411 and 414 share the exact
same content `'записей'`, so they collapse to one allow-list entry but both
call sites need the replacement):
```
82: const Text('История продаж',
138: label: 'Сегодня',
144: label: 'Неделя',
150: label: 'Месяц',
156: label: 'Выбрать',
182: title: 'Нет продаж',
183: subtitle: 'История продаж появится здесь после первой транзакции',
205: '$totalSales продаж  |  ${_formatPrice(totalAmount)}',
234: '${state.skippedRows} ${_pluralRecord(state.skippedRows)} пропущено',
303: case 'CASH': return 'Наличные';
304: case 'CARD': return 'Карта';
305: case 'DEBT': return 'В долг';
306: case 'MIXED': return 'Смешанная';
356: Text('Чек ${sale.receiptNo}',
367: '${sale.customerName ?? 'Розничный'}  •  ${sale.items.length} товаров',
388: Text(isRefund ? 'Возврат' : _paymentLabel(),
411: if (mod100 >= 11 && mod100 <= 14) return 'записей';
412: if (mod10 == 1) return 'запись';
413: if (mod10 >= 2 && mod10 <= 4) return 'записи';
414: return 'записей';
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"salesHistory"\|"today"\|"week"\|"month"\|"noSales"\|"cash"\|"card"\|"debt"\|"refund"\|"mixed"\|"dashboardSaleReceiptLabel"' lib/l10n/app_ru.arb`

Expected, all already exist — reuse:
- `salesHistory: "История продаж"` — matches line 82's header exactly.
- `today: "Сегодня"`, `week: "Неделя"`, `month: "Месяц"` — chip labels.
- `noSales: "Нет продаж"` — matches line 182's empty-state title exactly.
- `cash: "Наличные"`, `card: "Карта"`, `debt: "В долг"` — payment labels.
- `refund: "Возврат"` — matches line 388's ternary text.

**Do NOT reuse `mixed` for line 306.** `mixed`'s stored value is
`"Смешанная оплата"` (with "оплата" appended) — line 306's `_paymentLabel()`
returns the bare `'Смешанная'`. Character-for-character these differ; reuse
would visibly change this screen's payment-badge text. Mint
`salesHistoryPaymentMixed` instead (Step 2).

**Do NOT reuse `dashboardSaleReceiptLabel`** (`"Чек #{receiptNo}"`, used on
the dashboard's recent-sales card — confirmed via
`grep -n 'dashboardSaleReceiptLabel' lib/l10n/app_ru.arb`) for line 356.
That key's value includes a `#` before the number; line 356's literal
`'Чек ${sale.receiptNo}'` has no `#`. Reusing it would add a character that
isn't currently on screen. Mint `salesHistoryReceiptLabel: "Чек {receiptNo}"`
instead — this is exactly the kind of near-miss the design doc's mandatory
value-verification rule exists to catch (real bugs `f54d5fd`/`bb6a1cc`
shipped from skipping this exact check in the predecessor branch).

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "salesHistoryCustomDateChip": "Выбрать",
  "@salesHistoryCustomDateChip": { "description": "Sales-history period-filter chip for opening a custom date-range picker (bare \"Выбрать\") — distinct from `salesFilterCustomDates` (\"Выбрать даты\"), the fuller wording used in the sales-filter bottom sheet's period section" },
  "salesHistoryEmptySubtitle": "История продаж появится здесь после первой транзакции",
  "salesHistoryStatsLine": "{count} продаж  |  {amount}",
  "@salesHistoryStatsLine": {
    "description": "Stats banner above the sales list — sale count and total amount, both pre-formatted strings",
    "placeholders": {
      "count": { "type": "String" },
      "amount": { "type": "String" }
    }
  },
  "salesHistorySkippedRowsLine": "{count} {word} пропущено",
  "@salesHistorySkippedRowsLine": {
    "description": "Shown when the sales import parser skipped rows (BUG #28 warning banner); `word` is the already-pluralized Russian noun form (записей/запись/записи), pre-formatted at the call site via _pluralRecord",
    "placeholders": {
      "count": { "type": "String" },
      "word": { "type": "String" }
    }
  },
  "salesHistoryPaymentMixed": "Смешанная",
  "@salesHistoryPaymentMixed": { "description": "Sales-history payment-method badge (bare \"Смешанная\") — distinct from `mixed` (\"Смешанная оплата\"), the fuller wording used elsewhere" },
  "salesHistoryReceiptLabel": "Чек {receiptNo}",
  "@salesHistoryReceiptLabel": {
    "description": "Sales-history list row's receipt-number label, no # prefix — distinct from `dashboardSaleReceiptLabel` (\"Чек #{receiptNo}\", which does have a # prefix and renders on the dashboard's recent-sales card); do not merge these, the rendered text differs",
    "placeholders": { "receiptNo": { "type": "String" } }
  },
  "salesHistoryRetailCustomer": "Розничный",
  "salesHistorySaleSummaryLine": "{customer} • {itemsCount} товаров",
  "@salesHistorySaleSummaryLine": {
    "description": "Sales-history list row's second line — customer name (or the retail-customer fallback) bullet-separated from the item count",
    "placeholders": {
      "customer": { "type": "String" },
      "itemsCount": { "type": "String" }
    }
  },
  "recordsCountOne": "запись",
  "recordsCountFew": "записи",
  "recordsCountMany": "записей",
  "@recordsCountOne": { "description": "Russian singular form of 'record(s)', used in the skipped-rows warning on the sales-history import screen" },
  "@recordsCountFew": { "description": "Russian few-form (2-4) of 'record(s)', same usage as recordsCountOne" },
  "@recordsCountMany": { "description": "Russian many-form (0, 5+, 11-14) of 'record(s)', same usage as recordsCountOne — deliberately three separate keys rather than ICU plural, per this file's String-only placeholder convention" },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

| Find | Replace with |
|---|---|
| `const Text('История продаж',` | `Text(l10n.salesHistory,` |
| `label: 'Сегодня',` | `label: l10n.today,` |
| `label: 'Неделя',` | `label: l10n.week,` |
| `label: 'Месяц',` | `label: l10n.month,` |
| `label: 'Выбрать',` | `label: l10n.salesHistoryCustomDateChip,` |
| `title: 'Нет продаж',` | `title: l10n.noSales,` |
| `subtitle: 'История продаж появится здесь после первой транзакции',` | `subtitle: l10n.salesHistoryEmptySubtitle,` |
| `'$totalSales продаж  |  ${_formatPrice(totalAmount)}',` | `l10n.salesHistoryStatsLine(totalSales.toString(), _formatPrice(totalAmount)),` |
| `'${state.skippedRows} ${_pluralRecord(state.skippedRows)} пропущено',` | `l10n.salesHistorySkippedRowsLine(state.skippedRows.toString(), _pluralRecord(state.skippedRows, l10n)),` |
| `case 'CASH': return 'Наличные';` | `case 'CASH': return l10n.cash;` |
| `case 'CARD': return 'Карта';` | `case 'CARD': return l10n.card;` |
| `case 'DEBT': return 'В долг';` | `case 'DEBT': return l10n.debt;` |
| `case 'MIXED': return 'Смешанная';` | `case 'MIXED': return l10n.salesHistoryPaymentMixed;` |
| `Text('Чек ${sale.receiptNo}',` | `Text(l10n.salesHistoryReceiptLabel(sale.receiptNo.toString()),` |
| `'${sale.customerName ?? 'Розничный'}  •  ${sale.items.length} товаров',` | `l10n.salesHistorySaleSummaryLine(sale.customerName ?? l10n.salesHistoryRetailCustomer, sale.items.length.toString()),` |
| `Text(isRefund ? 'Возврат' : _paymentLabel(),` | `Text(isRefund ? l10n.refund : _paymentLabel(context),` |
| `if (mod100 >= 11 && mod100 <= 14) return 'записей';` | `if (mod100 >= 11 && mod100 <= 14) return l10n.recordsCountMany;` |
| `if (mod10 == 1) return 'запись';` | `if (mod10 == 1) return l10n.recordsCountOne;` |
| `if (mod10 >= 2 && mod10 <= 4) return 'записи';` | `if (mod10 >= 2 && mod10 <= 4) return l10n.recordsCountFew;` |
| `return 'записей';` | `return l10n.recordsCountMany;` |

**Required structural changes (not literal find/replace, do these too):**
1. In `_SaleCard.build(BuildContext context)` (currently just declares
   `dateFormat`/`isRefund`), add `final l10n = AppLocalizations.of(context)!;`
   before it's used at lines 356/367/388.
2. Change `String _paymentLabel() {` to
   `String _paymentLabel(BuildContext context) {` and add
   `final l10n = AppLocalizations.of(context)!;` at its top; update its
   single call site (line 388, already shown above) to pass `context`.
3. Change `String _pluralRecord(int n) {` (top-level function, bottom of
   file) to `String _pluralRecord(int n, AppLocalizations l10n) {`; its one
   call site (line 234, already shown above) now passes the outer `l10n`.
4. Add the `AppLocalizations` import to any new usage site if not already
   present at the top of the file (it already is, line 20).

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep sales_history_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/sales/sales_history_page_golden_test.dart --reporter expanded` — expect passing.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/sales/sales_history_page.dart
git commit -m "fix(app): migrate sales_history_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 11: Migrate `sales_filter_sheet.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/widgets/pos/sales_filter_sheet.dart`

Unlike the previous nine files, **this file does not import
`AppLocalizations` at all yet** — add
`import 'package:dukonpro/l10n/app_localizations.dart';` at the top. The
widget hierarchy is: `SalesFilterSheet` (a thin `StatefulWidget` wrapper,
its `show()` static method opens it as a modal bottom sheet) →
`_SalesFilterSheetState` (the actual `State`, all offending literals live in
its single `build(BuildContext context)`) → private helper
`StatelessWidget`s `_SectionLabel` and `_FilterChip`, whose `label`
parameters are supplied from `_SalesFilterSheetState.build()`'s call sites —
so every literal in scope for this task is reachable from one `context`;
declare `final l10n = AppLocalizations.of(context)!;` once at the top of
`_SalesFilterSheetState.build()` and use it everywhere.

Current offenders (all 18, verbatim; `'Все'` appears twice — line 346's
payment-filter chip and line 378's status-filter chip both hold the exact
same content, so it's one allow-list entry covering two call sites):
```
244: 'Фильтры',
256: 'Сбросить',
271: tooltip: 'Пӯшидан',
292: _SectionLabel(label: 'Период'),
299: label: 'Сегодня',
308: label: 'Неделя',
317: label: 'Месяц',
326: label: 'Выбрать даты',
339: _SectionLabel(label: 'Тип оплаты'),
346: label: 'Все',
351: label: 'Наличные',
356: label: 'Карта',
361: label: 'Долг',
371: _SectionLabel(label: 'Статус'),
378: label: 'Все',
383: label: 'Выполнен',
389: label: 'Возврат',
393: label: 'Отменён',
428: 'Применить',
```

- [ ] **Step 1: Handle the stray-language bug first**

Line 271's tooltip is `'Пӯшидан'` — this is **Tajik**, not Russian (it
contains the Tajik-specific letter `ӯ`), sitting on an otherwise
all-Russian close ("X") icon button in an all-Russian file. It was still
flagged by `check_i18n.dart` because the regex matches base Cyrillic
letters, which Tajik's alphabet is built on. This reads as an accidental
paste/leftover, not an intentional design choice — the correct Russian text
for a close-button tooltip is "Закрыть", which the ARB already has as
`close`. Treat replacing it with `l10n.close` as a real bugfix bundled into
this migration (same spirit as the two reuse-mismatch bugs the predecessor
branch shipped and later fixed in `f54d5fd`/`bb6a1cc` — this is the mirror
case: catching a wrong value *before* shipping it, not reusing a
mismatched key). Flag this explicitly in the PR description / code review
pass so it isn't waved through as a routine literal swap.

- [ ] **Step 2: Check for reusable existing keys**

Run: `grep -n '"today"\|"week"\|"month"\|"cash"\|"card"\|"all"\|"period"\|"apply"\|"close"\|"refund"\|"offlineResetSyncStatusConfirm"' lib/l10n/app_ru.arb`

Expected, all already exist — reuse:
- `today: "Сегодня"`, `week: "Неделя"`, `month: "Месяц"`
- `cash: "Наличные"`, `card: "Карта"`
- `all: "Все"` — reused at **both** line 346 and line 378 call sites
- `period: "Период"` — matches line 292's section label exactly
- `apply: "Применить"` — matches line 428's button text exactly
- `close: "Закрыть"` — see Step 1
- `refund: "Возврат"` — matches line 389's status-filter chip

**Do NOT reuse `offlineResetSyncStatusConfirm`** (`"Сбросить"`) for line 256
even though the value matches — its own description ties it specifically to
the offline-sync-status dialog's confirm button, a different feature
entirely; coincidental value match, not shared meaning. Mint a distinct
`salesFilterReset` key.

- [ ] **Step 3: Add new keys to `app_ru.arb`**

```json
  "salesFilterSheetTitle": "Фильтры",
  "salesFilterReset": "Сбросить",
  "@salesFilterReset": { "description": "Sales-filter bottom sheet's reset-all-filters button — distinct from `offlineResetSyncStatusConfirm` (\"Сбросить\"), a different screen's dialog-confirm button that happens to share the same Russian word" },
  "salesFilterCustomDates": "Выбрать даты",
  "@salesFilterCustomDates": { "description": "Sales-filter bottom sheet's period-section chip for opening a custom date-range picker (\"Выбрать даты\") — distinct from `salesHistoryCustomDateChip` (\"Выбрать\"), the shorter wording used on the sales-history page's own period chips" },
  "salesFilterPaymentTypeSectionLabel": "Тип оплаты",
  "debtLabel": "Долг",
  "@debtLabel": { "description": "Generic bare 'Debt' label — shared between this sheet's payment-type filter chip and customer_detail_page.dart's debt stat card; distinct from `debt` (\"В долг\"), the preposition-inflected form used as a payment-method value elsewhere" },
  "salesFilterStatusSectionLabel": "Статус",
  "salesFilterStatusCompleted": "Выполнен",
  "salesFilterStatusCancelled": "Отменён",
```

- [ ] **Step 4: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 5: Replace literals**

First add the missing import at the top of the file:
```dart
import 'package:dukonpro/l10n/app_localizations.dart';
```
Then add `final l10n = AppLocalizations.of(context)!;` at the top of
`_SalesFilterSheetState.build(BuildContext context)`, and apply:

| Find | Replace with |
|---|---|
| `'Фильтры',` (inside `Text('Фильтры', style: ...)`, line 244) | `l10n.salesFilterSheetTitle,` |
| `'Сбросить',` (inside `child: const Text('Сбросить', style: ...)`, line 256 — drop `const`) | `l10n.salesFilterReset,` |
| `tooltip: 'Пӯшидан',` | `tooltip: l10n.close,` |
| `_SectionLabel(label: 'Период'),` | `_SectionLabel(label: l10n.period),` |
| `label: 'Сегодня',` (period chip, line 299) | `label: l10n.today,` |
| `label: 'Неделя',` (period chip, line 308) | `label: l10n.week,` |
| `label: 'Месяц',` (period chip, line 317) | `label: l10n.month,` |
| `label: 'Выбрать даты',` | `label: l10n.salesFilterCustomDates,` |
| `_SectionLabel(label: 'Тип оплаты'),` | `_SectionLabel(label: l10n.salesFilterPaymentTypeSectionLabel),` |
| `label: 'Все',` (payment-filter chip, line 346) | `label: l10n.all,` |
| `label: 'Наличные',` | `label: l10n.cash,` |
| `label: 'Карта',` | `label: l10n.card,` |
| `label: 'Долг',` | `label: l10n.debtLabel,` |
| `_SectionLabel(label: 'Статус'),` | `_SectionLabel(label: l10n.salesFilterStatusSectionLabel),` |
| `label: 'Все',` (status-filter chip, line 378 — same content as line 346, same replacement) | `label: l10n.all,` |
| `label: 'Выполнен',` | `label: l10n.salesFilterStatusCompleted,` |
| `label: 'Возврат',` | `label: l10n.refund,` |
| `label: 'Отменён',` | `label: l10n.salesFilterStatusCancelled,` |
| `'Применить',` (inside `child: const Text('Применить', style: ...)`, line 428 — drop `const`) | `l10n.apply,` |

Note: three `Text(...)` widgets currently marked `const` (lines
243/255/427-ish — confirm exact wrapping when editing) can no longer be
`const` once their child is a `l10n.*` getter call — remove `const` from
each of those `Text(`/`child: const Text(` sites, not just swap the string.

- [ ] **Step 6: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep sales_filter_sheet.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/widgets/pos/sales_filter_sheet_golden_test.dart --reporter expanded` — expect passing.

- [ ] **Step 7: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/widgets/pos/sales_filter_sheet.dart
git commit -m "fix(app): migrate sales_filter_sheet.dart hardcoded strings to AppLocalizations"
```

---

### Task 12: Migrate `customer_detail_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/customer/customer_detail_page.dart`

`AppLocalizations` is already imported (line 21) and already used inline
once, at line 157 (`AppLocalizations.of(context)!.snackCustomerSelectedForSale(...)`)
— leave that call site untouched (it's not an offender, and per the design
spec's "don't fix unrelated things" discipline this task shouldn't refactor
it into the new `l10n` variable just for tidiness). Add
`final l10n = AppLocalizations.of(context)!;` at the top of
`_CustomerDetailPageState.build(BuildContext context)` and use it for every
offender below. `_paymentLabel(String type)` (lines 321-328) is a plain
instance method on `_CustomerDetailPageState`, a `State` subclass — it has
the inherited `context` getter available even outside `build()`, so no
signature change is needed there; just declare
`final l10n = AppLocalizations.of(context)!;` at its own top.

Current offenders (all 18, verbatim):
```
68: appBar: AppBar(title: const Text('Клиент')),
136: label: 'Звонок',
143: label: 'СМС',
149: label: 'Продажа',
163: label: 'Изменить',
177: Text('Потрачено', style: TextStyle(fontSize: 12, color: context.textSecondary)),
189: Text('Долг', style: TextStyle(fontSize: 12, color: context.textSecondary)),
201: Text('Баллы', style: TextStyle(fontSize: 12, color: context.textSecondary)),
214: text: 'Посмотреть долги',
227: title: const Text('История баллов',
248: title: Text('$sign${tx.points} баллов',
254: 'до ${_formatDate(tx.expiresAt!.toIso8601String())}',
265: const Text('Последние покупки', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
271: child: Text('Нет покупок', style: TextStyle(color: context.textSecondary)),
284: Text('Чек #${sale['receiptNo'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
323: case 'CASH': return 'Наличные';
324: case 'CARD': return 'Карта';
325: case 'CREDIT': return 'В долг';
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"loyaltyPoints"\|"debt"\|"call"\|"modify"\|"cash"\|"card"\|"noPurchases"\|"recentPurchases"\|"viewDebts"\|"sale"\|"sms"\|"dashboardSaleReceiptLabel"\|"deliveryDetailCustomerLabel"' lib/l10n/app_ru.arb`

Expected, all already exist — reuse:
- `loyaltyPoints: "Баллы"` (line 201)
- `debt: "В долг"` (line 325's `case 'CREDIT'`)
- `call: "Звонок"` (line 136), `modify: "Изменить"` (line 163)
- `cash: "Наличные"` (line 323), `card: "Карта"` (line 324)
- `noPurchases: "Нет покупок"` (line 271)
- `recentPurchases: "Последние покупки"` (line 265)
- `viewDebts: "Посмотреть долги"` (line 214)
- `sale: "Продажа"` (line 149), `sms: "СМС"` (line 143)
- `dashboardSaleReceiptLabel: "Чек #{receiptNo}"` — verify this
  character-for-character against line 284's literal
  `'Чек #${sale['receiptNo'] ?? ''}'`: same `Чек #` prefix, same
  `{receiptNo}` placeholder position — **this one is a true exact match**,
  reuse it (contrast with Task 10's `sales_history_page.dart`, where the
  visually-similar-but-not-identical `'Чек ${sale.receiptNo}'`, missing the
  `#`, required its own distinct key — don't let this task's clean match
  make you assume the other file's near-miss was also safe to reuse).

**Also check the cross-task shared key from Task 11.** If Task 11
(`sales_filter_sheet.dart`) has already run and minted `debtLabel: "Долг"`,
reuse it here for line 189 instead of minting a duplicate — run
`grep -n '"debtLabel"' lib/l10n/app_ru.arb` first. If Task 11 hasn't run
yet when this task executes, add `debtLabel` here instead (Step 2 below),
and Task 11 should then find and reuse it rather than re-adding it. Either
way, only one `debtLabel` entry should exist in the ARB when both tasks are
done — this is exactly the kind of cross-task ARB duplication the design
doc calls out as the largest risk at this project's scale.

**Do NOT reuse `deliveryDetailCustomerLabel`** (`"Клиент"`, an info-row
label on the delivery-detail screen) for line 68's AppBar title even though
the value matches exactly — same text, different UI role (a page title vs.
a form/info-row label). Mint a distinct `customerDetailPageTitle` key with
a description noting the relationship, following the same near-duplicate
pattern already established for `deliveryDetailAddressLabel` vs. `address`
elsewhere in the ARB.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "customerDetailPageTitle": "Клиент",
  "@customerDetailPageTitle": { "description": "Customer-detail screen's AppBar title — same Russian text as `deliveryDetailCustomerLabel` (\"Клиент\") but a different UI role (page title vs. an info-row label on the delivery-detail screen); kept as a separate key per convention for near-duplicate values used in different roles" },
  "customerDetailSpentLabel": "Потрачено",
  "customerDetailLoyaltyHistoryTitle": "История баллов",
  "customerDetailPointsLine": "{sign}{points} баллов",
  "@customerDetailPointsLine": {
    "description": "Loyalty-history row title — signed points delta (sign is '+' or empty, both pre-formatted strings)",
    "placeholders": {
      "sign": { "type": "String" },
      "points": { "type": "String" }
    }
  },
  "customerDetailPointsExpiryLine": "до {date}",
  "@customerDetailPointsExpiryLine": {
    "description": "Loyalty-history row trailing text — expiry date for earned points, pre-formatted at the call site",
    "placeholders": { "date": { "type": "String" } }
  },
```

If `debtLabel` does not already exist from Task 11 (check per Step 1),
also add here:
```json
  "debtLabel": "Долг",
  "@debtLabel": { "description": "Generic bare 'Debt' label — shared between this screen's debt stat card and sales_filter_sheet.dart's payment-type filter chip; distinct from `debt` (\"В долг\"), the preposition-inflected form used as a payment-method value elsewhere" },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

Add `final l10n = AppLocalizations.of(context)!;` at the top of
`build(BuildContext context)`, then:

| Find | Replace with |
|---|---|
| `appBar: AppBar(title: const Text('Клиент')),` | `appBar: AppBar(title: Text(l10n.customerDetailPageTitle)),` |
| `label: 'Звонок',` | `label: l10n.call,` |
| `label: 'СМС',` | `label: l10n.sms,` |
| `label: 'Продажа',` | `label: l10n.sale,` |
| `label: 'Изменить',` | `label: l10n.modify,` |
| `Text('Потрачено', style: TextStyle(fontSize: 12, color: context.textSecondary)),` | `Text(l10n.customerDetailSpentLabel, style: TextStyle(fontSize: 12, color: context.textSecondary)),` |
| `Text('Долг', style: TextStyle(fontSize: 12, color: context.textSecondary)),` | `Text(l10n.debtLabel, style: TextStyle(fontSize: 12, color: context.textSecondary)),` |
| `Text('Баллы', style: TextStyle(fontSize: 12, color: context.textSecondary)),` | `Text(l10n.loyaltyPoints, style: TextStyle(fontSize: 12, color: context.textSecondary)),` |
| `text: 'Посмотреть долги',` | `text: l10n.viewDebts,` |
| `title: const Text('История баллов',` | `title: Text(l10n.customerDetailLoyaltyHistoryTitle,` |
| `title: Text('$sign${tx.points} баллов',` | `title: Text(l10n.customerDetailPointsLine(sign, tx.points.toString()),` |
| `'до ${_formatDate(tx.expiresAt!.toIso8601String())}',` | `l10n.customerDetailPointsExpiryLine(_formatDate(tx.expiresAt!.toIso8601String())),` |
| `const Text('Последние покупки', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),` | `Text(l10n.recentPurchases, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),` |
| `child: Text('Нет покупок', style: TextStyle(color: context.textSecondary)),` | `child: Text(l10n.noPurchases, style: TextStyle(color: context.textSecondary)),` |
| `Text('Чек #${sale['receiptNo'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),` | `Text(l10n.dashboardSaleReceiptLabel((sale['receiptNo'] ?? '').toString()), style: const TextStyle(fontWeight: FontWeight.w600)),` |
| `case 'CASH': return 'Наличные';` | `case 'CASH': return l10n.cash;` |
| `case 'CARD': return 'Карта';` | `case 'CARD': return l10n.card;` |
| `case 'CREDIT': return 'В долг';` | `case 'CREDIT': return l10n.debt;` |

Note `sale['receiptNo']` comes from a `Map` (likely `Map<String, dynamic>`,
not guaranteed to already be a `String`) — the explicit `.toString()` after
the `?? ''` fallback is required so the placeholder argument is `String`-typed
per convention, matching what the existing `dashboardSaleReceiptLabel`
call sites elsewhere already do.

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep customer_detail_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/customer/customer_detail_page_golden_test.dart --reporter expanded` — expect passing.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/customer/customer_detail_page.dart
git commit -m "fix(app): migrate customer_detail_page.dart hardcoded strings to AppLocalizations"
```

---
### Task 13: Migrate `product_list_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/product/product_list_page.dart`

Current offenders (all 17, verbatim):
```
131: const Text('Товары',
150: child: Text('Категории'),
154: child: Text('Импорт из Excel'),
182: hintText: 'Поиск товара',
227: label: 'Все',
233: label: 'В наличии',
239: label: 'Заканчивается',
245: label: 'Нет в наличии',
251: label: 'Требует внимания',
286: title: isEmptyOverall ? 'Нет товаров' : 'Нет товаров по фильтру',
288: ? 'Добавьте первый товар в каталог'
289: : 'Попробуйте изменить фильтр или поисковый запрос',
290: buttonText: isEmptyOverall ? 'Добавить товар' : null,
338: Text('Общая сумма',
351: Text('Себестоимость',
450: Text('Арт: ${product.sku}',
456: Text('На складе: ',
```

**Important tooling note before you start:** `check_i18n.dart`'s regex only takes the *first* Cyrillic-quoted match per source line (`cyrillicInString.firstMatch(line)`, not a global match). Line 286 has **two** Cyrillic literals on it — `'Нет товаров'` and `'Нет товаров по фильтру'` — and only the first one (`'Нет товаров'`) is in the allow-list dump above. If you migrate only the listed offender and leave `'Нет товаров по фильтру'` as a bare literal, it becomes the new first-match on that line the instant you fix the first one, and `check_i18n.dart` will report it as a "new" violation. Both literals on line 286 must be migrated together even though only one appears in the official offender list. (Verified: this is the *only* line across all 6 files in this batch with more than one Cyrillic literal — checked with a per-line multi-match scan.)

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"products"\|"categories"\|"importFromExcel"\|"^  \"all\"\|"inStock"\|"outOfStock"\|"noProducts"\|"addProduct"\|"totalAmount"\|"dashboardCost"' lib/l10n/app_ru.arb`

Confirmed exact-value matches to reuse:
- `products`: `"Товары"` — reuse for line 131's header (and note `navProducts` also holds `"Товары"` but is the bottom-nav-bar label; `products`'s own description, "Products section title," is the correct semantic fit here, not the nav one).
- `categories`: `"Категории"` — reuse for line 150.
- `importFromExcel`: `"Импорт из Excel"` — reuse for line 154. Its existing `@importFromExcel` description literally says *"generic (also appears on the product list page's overflow menu)"* — this key was pre-anticipated for exactly this call site.
- `all`: `"Все"` — reuse for line 227.
- `inStock`: `"В наличии"` — reuse for line 233.
- `outOfStock`: `"Нет в наличии"` — reuse for line 245.
- `noProducts`: `"Нет товаров"` — reuse for line 286's true-branch. **Do NOT** reuse `emptyProductsTitle` (`"Добавьте свой первый товар"`) for line 288 or `emptyProductsSubtitle` (`"Начните добавлять товары в ваш магазин, чтобы управлять продажами и складом"`) for line 289 — both are near-duplicates in *meaning* but differ character-for-character from our offenders; they belong to a different empty-products screen and must not be force-reused.
- `addProduct`: `"Добавить товар"` — reuse for line 290 (already used as a tooltip earlier in this same file, line 159).
- `totalAmount`: `"Общая сумма"` — reuse for line 338.
- `dashboardCost`: `"Себестоимость"` — reuse for line 351.

No exact match exists for: `'Поиск товара'`, `'Заканчивается'` (do **not** reuse `lowStock` — its value is `"Мало на складе"`, a different string), `'Требует внимания'`, `'Нет товаров по фильтру'` (the hidden offender), `'Добавьте первый товар в каталог'`, `'Попробуйте изменить фильтр или поисковый запрос'`, `'Арт: ${product.sku}'`, `'На складе: '`. These need new keys (below).

- [ ] **Step 2: Add new keys to `app_ru.arb`**

Insert into the existing `product*` block (right after `"importFromExcel": "Импорт из Excel",` / its `@importFromExcel` line, around line 390):

```json
  "productSearchHint": "Поиск товара",
  "@productSearchHint": { "description": "Product list page — search field hint text" },
  "productFilterLowStock": "Заканчивается",
  "@productFilterLowStock": { "description": "Product list page — stock filter chip for products running low; distinct from `lowStock` (\"Мало на складе\"), a differently-worded low-stock warning used elsewhere" },
  "productFilterAttention": "Требует внимания",
  "@productFilterAttention": { "description": "Product list page — stock filter chip for the combined low-stock + out-of-stock 'needs attention' filter (see the file's BUG #26 comments)" },
  "productsEmptyFilteredTitle": "Нет товаров по фильтру",
  "@productsEmptyFilteredTitle": { "description": "Product list page — empty-state headline shown when a stock filter/search hides all products. Distinct from `emptyProductsTitle` (\"Добавьте свой первый товар\"), a differently-worded empty-state used on another products screen. NOTE: this string was NOT in check_i18n.dart's original allow-list dump for this file — it shares a source line with `noProducts` and check_i18n only flags the first Cyrillic match per line — but it must still be migrated in this same pass" },
  "productsEmptyAddSubtitle": "Добавьте первый товар в каталог",
  "@productsEmptyAddSubtitle": { "description": "Product list page — empty-state subtitle shown when the store has zero products at all; distinct from `emptyProductsSubtitle` (\"Начните добавлять товары в ваш магазин, чтобы управлять продажами и складом\"), differently-worded text on another products screen" },
  "productsEmptyFilteredSubtitle": "Попробуйте изменить фильтр или поисковый запрос",
  "@productsEmptyFilteredSubtitle": { "description": "Product list page — empty-state subtitle shown when a filter/search hides all products" },
  "productSkuLine": "Арт: {sku}",
  "@productSkuLine": {
    "description": "Product list card — SKU line",
    "placeholders": { "sku": { "type": "String" } }
  },
  "productStockQuantityLine": "На складе: {value}",
  "@productStockQuantityLine": {
    "description": "Product list card — in-stock quantity line. {value} is the pre-formatted '<quantity> <unit>' string. This collapses what was previously two separately-styled Text widgets (grey label + stock-status-colored value) into one Text per the label+separator+value composite-string rule (.claude/rules/mobile-l10n.md) — the merged Text keeps the stock-status color since that's the more important visual signal",
    "placeholders": { "value": { "type": "String" } }
  },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

`_ProductListPageState.build()` already binds `final l10n = AppLocalizations.of(context)!;` at line 114 — use it directly for everything in the main build tree, including the `PopupMenuButton`'s `itemBuilder` (its `context` parameter shadows the outer one but the closure still captures the outer `l10n` fine, no need for a second lookup). `_ProductCard.build()` (the separate `StatelessWidget`) already binds its own `l10n` at line 385 — use that one for the two card-level replacements.

| Find | Replace with |
|---|---|
| `const Text('Товары',` | `Text(l10n.products,` |
| `child: Text('Категории'),` | `child: Text(l10n.categories),` |
| `child: Text('Импорт из Excel'),` | `child: Text(l10n.importFromExcel),` |
| `hintText: 'Поиск товара',` | `hintText: l10n.productSearchHint,` |
| `label: 'Все',` | `label: l10n.all,` |
| `label: 'В наличии',` | `label: l10n.inStock,` |
| `label: 'Заканчивается',` | `label: l10n.productFilterLowStock,` |
| `label: 'Нет в наличии',` | `label: l10n.outOfStock,` |
| `label: 'Требует внимания',` | `label: l10n.productFilterAttention,` |
| `title: isEmptyOverall ? 'Нет товаров' : 'Нет товаров по фильтру',` | `title: isEmptyOverall ? l10n.noProducts : l10n.productsEmptyFilteredTitle,` |
| `? 'Добавьте первый товар в каталог'` | `? l10n.productsEmptyAddSubtitle` |
| `: 'Попробуйте изменить фильтр или поисковый запрос',` | `: l10n.productsEmptyFilteredSubtitle,` |
| `buttonText: isEmptyOverall ? 'Добавить товар' : null,` | `buttonText: isEmptyOverall ? l10n.addProduct : null,` |
| `Text('Общая сумма',` | `Text(l10n.totalAmount,` |
| `Text('Себестоимость',` | `Text(l10n.dashboardCost,` |
| `Text('Арт: ${product.sku}',` | `Text(l10n.productSkuLine(product.sku!),` |

For lines 454-465 (`_ProductCard.build()`), replace the two-Text `Row` with a single `Text`:

Find:
```dart
Row(
  children: [
    Text('На складе: ',
      style: TextStyle(fontSize: 12, color: context.textSecondary)),
    Text('${product.quantity} $unitName',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: stockColor,
      )),
  ],
),
```
Replace with:
```dart
Text(
  l10n.productStockQuantityLine('${product.quantity} $unitName'),
  style: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: stockColor,
  ),
),
```

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep product_list_page.dart` — expect no output (this must also confirm the hidden `'Нет товаров по фильтру'` literal is gone, not just the originally-listed offenders).
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/product/product_list_page_golden_test.dart --reporter expanded` — expect passing (if a golden mismatch appears, verify via a throwaway parent-commit worktree per the design spec's baseline-check technique before treating it as a regression — Linux CI tolerance is ~100% vs. macOS's ~0.2%).

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/product/product_list_page.dart
git commit -m "fix(app): migrate product_list_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 14: Migrate `notification_settings_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/notifications/notification_settings_page.dart`

Current offenders (all 17, verbatim):
```
138: title: const Text('Настройки уведомлений'),
150: 'Выберите какие уведомления вы хотите получать',
159: 'Низкий остаток',
160: 'Когда товар заканчивается на складе',
166: 'Новая продажа',
167: 'Когда кассир оформляет продажу',
173: 'Закрытие смены',
174: 'Когда смена закрывается',
180: 'Доставка выполнена',
181: 'Когда курьер доставил заказ',
187: 'Напоминание о долге',
188: 'Просроченные долги клиентов (> 7 дней)',
210: 'Залежалый товар',
218: 'Уведомлять, если товар не продаётся N дней и остаток ещё большой',
231: labelText: 'Дней без продаж',
242: labelText: 'Остаток, % от партии',
266: 'Сохранить',
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"save"\|"newSale"\|"lowStock"' lib/l10n/app_ru.arb`
- `save`: `"Сохранить"` — exact match, reuse for line 266 (inside the `Builder(builder: (ctx) => ...)` that wraps the button's `Text` purely to get `ctx.onPrimary` for styling — this doesn't need a separate localization lookup; the outer `l10n` variable added in Step 4 is captured by the closure fine).
- `newSale`: `"Новая продажа"` — exact match, reuse for line 166 (the switch-tile title). No other line in this file matches an existing key: `lowStock` holds `"Мало на складе"`, a different string from line 159's `'Низкий остаток'` — do not force-reuse it.

All 15 remaining offenders need new keys, prefixed `notificationSettings*` since none of this vocabulary (switch titles/subtitles, threshold field labels, page title/subtitle) exists anywhere else in the ARB.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

Insert as a new contiguous block right after `"notifications": "Уведомления",` in the settings section (around line 710):

```json
  "notificationSettingsPageTitle": "Настройки уведомлений",
  "@notificationSettingsPageTitle": { "description": "Notification settings screen — AppBar title" },
  "notificationSettingsSubtitle": "Выберите какие уведомления вы хотите получать",
  "@notificationSettingsSubtitle": { "description": "Notification settings screen — intro subtitle above the switch list" },
  "notificationSettingsLowStockTitle": "Низкий остаток",
  "@notificationSettingsLowStockTitle": { "description": "Notification settings — low-stock alert switch title; distinct from `lowStock` (\"Мало на складе\"), a differently-worded stock-status label used on the product list page" },
  "notificationSettingsLowStockSubtitle": "Когда товар заканчивается на складе",
  "notificationSettingsNewSaleSubtitle": "Когда кассир оформляет продажу",
  "@notificationSettingsNewSaleSubtitle": { "description": "Notification settings — new-sale alert switch subtitle (the switch title itself reuses `newSale`, \"Новая продажа\")" },
  "notificationSettingsShiftClosedTitle": "Закрытие смены",
  "notificationSettingsShiftClosedSubtitle": "Когда смена закрывается",
  "notificationSettingsDeliveryTitle": "Доставка выполнена",
  "notificationSettingsDeliverySubtitle": "Когда курьер доставил заказ",
  "notificationSettingsDebtReminderTitle": "Напоминание о долге",
  "notificationSettingsDebtReminderSubtitle": "Просроченные долги клиентов (> 7 дней)",
  "notificationSettingsStaleProductTitle": "Залежалый товар",
  "notificationSettingsStaleProductSubtitle": "Уведомлять, если товар не продаётся N дней и остаток ещё большой",
  "notificationSettingsDaysWithoutSaleLabel": "Дней без продаж",
  "notificationSettingsRemainingPercentLabel": "Остаток, % от партии",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

`build(BuildContext context)` does not currently bind an `l10n` variable — add one right after the opening brace: `final l10n = AppLocalizations.of(context)!;`. All replacements below live directly inside `build()`, including the `_buildSwitch(...)` call-site arguments (its own method signature/body is untouched — only the literal strings passed into it change).

| Find | Replace with |
|---|---|
| `title: const Text('Настройки уведомлений'),` | `title: Text(l10n.notificationSettingsPageTitle),` |
| `'Выберите какие уведомления вы хотите получать',` | `l10n.notificationSettingsSubtitle,` |
| `'Низкий остаток',` | `l10n.notificationSettingsLowStockTitle,` |
| `'Когда товар заканчивается на складе',` | `l10n.notificationSettingsLowStockSubtitle,` |
| `'Новая продажа',` | `l10n.newSale,` |
| `'Когда кассир оформляет продажу',` | `l10n.notificationSettingsNewSaleSubtitle,` |
| `'Закрытие смены',` | `l10n.notificationSettingsShiftClosedTitle,` |
| `'Когда смена закрывается',` | `l10n.notificationSettingsShiftClosedSubtitle,` |
| `'Доставка выполнена',` | `l10n.notificationSettingsDeliveryTitle,` |
| `'Когда курьер доставил заказ',` | `l10n.notificationSettingsDeliverySubtitle,` |
| `'Напоминание о долге',` | `l10n.notificationSettingsDebtReminderTitle,` |
| `'Просроченные долги клиентов (> 7 дней)',` | `l10n.notificationSettingsDebtReminderSubtitle,` |
| `'Залежалый товар',` (currently inside `const Text(...)`, line 209) | `l10n.notificationSettingsStaleProductTitle,` (drop the `const` since `l10n` is not a compile-time constant) |
| `'Уведомлять, если товар не продаётся N дней и остаток ещё большой',` | `l10n.notificationSettingsStaleProductSubtitle,` |
| `labelText: 'Дней без продаж',` | `labelText: l10n.notificationSettingsDaysWithoutSaleLabel,` |
| `labelText: 'Остаток, % от партии',` | `labelText: l10n.notificationSettingsRemainingPercentLabel,` |
| `'Сохранить',` (inside the `Builder(builder: (ctx) => ...)`) | `l10n.save,` |

Note line 209's surrounding `const Text(\n  'Залежалый товар',\n  style: ...\n)` needs its `const` keyword removed once the string becomes `l10n.notificationSettingsStaleProductTitle` — read the surrounding widget declaration first to confirm which `const` needs dropping (the `Text` itself, not necessarily the `TextStyle`, which can usually stay `const`).

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep notification_settings_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/notifications/notification_settings_page_golden_test.dart --reporter expanded` — expect passing.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/notifications/notification_settings_page.dart
git commit -m "fix(app): migrate notification_settings_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 15: Migrate `refund_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/sales/refund_page.dart`

Current offenders (all 15, verbatim):
```
75: title: const Text('Подтвердить возврат?'),
77: 'Сумма возврата: ${Formatters.price(_refundTotal)}\n'
78: 'Выбрано позиций: ${_selectedItems.length}',
83: child: const Text('Отмена'),
90: child: const Text('Подтвердить',
143: title: const Text('Возврат'),
175: 'Выберите товары для возврата',
188: 'Чек ${widget.sale.receiptNo}',
201: const Text('Товары',
210: ? 'Снять все'
211: : 'Выбрать все',
272: const Text('Причина возврата',
279: hint: 'Укажите причину возврата',
300: Text('Сумма возврата:',
322: text: 'Оформить возврат',
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"cancel"\|"confirm"\|"refund"\|"^  \"products\"\|"receiptNo"\|"dashboardSaleReceiptLabel"' lib/l10n/app_ru.arb`
- `cancel`: `"Отмена"` — exact match, reuse for line 83.
- `confirm`: `"Подтвердить"` — exact match, reuse for line 90's bare confirm button (careful: this is a *different* offender from line 75's `'Подтвердить возврат?'`, a full dialog title — don't conflate the two).
- `refund`: `"Возврат"` — exact match, reuse for line 143's AppBar title (do **not** use `returnType`, which also holds `"Возврат"` but means a stock-movement return type, an unrelated concept).
- `products`: `"Товары"` — exact match, reuse for line 201's section header.
- `receiptNo` (`"Чек №"`) and `dashboardSaleReceiptLabel` (`"Чек #{receiptNo}"`) both look similar to line 188's `'Чек ${widget.sale.receiptNo}'` but neither matches character-for-character — the actual rendered text here is `"Чек " + receiptNo` with **no** `№` or `#` separator symbol. Do not reuse either; mint a new key.

No matches exist for the remaining 10 offender occurrences (`'Подтвердить возврат?'`, the two-part confirm-dialog body, `'Выберите товары для возврата'`, `'Чек ...'`, `'Снять все'`/`'Выбрать все'`, `'Причина возврата'`, `'Укажите причину возврата'`, `'Сумма возврата:'`, `'Оформить возврат'`).

- [ ] **Step 2: Add new keys to `app_ru.arb`**

Insert into the sales block, right after `"refund": "Возврат",` (around line 468):

```json
  "refundConfirmTitle": "Подтвердить возврат?",
  "refundConfirmBody": "Сумма возврата: {amount}\nВыбрано позиций: {count}",
  "@refundConfirmBody": {
    "description": "Refund confirmation dialog body — combines the refund total and selected-item count into one translatable sentence (was two adjacent Dart string literals forming one Text)",
    "placeholders": { "amount": { "type": "String" }, "count": { "type": "String" } }
  },
  "refundInstructionBanner": "Выберите товары для возврата",
  "refundReceiptLabel": "Чек {receiptNo}",
  "@refundReceiptLabel": {
    "description": "Refund page — receipt number line. Distinct from `receiptNo` (\"Чек №\") and `dashboardSaleReceiptLabel` (\"Чек #{receiptNo}\") — this screen's wording has no separator symbol between 'Чек' and the number",
    "placeholders": { "receiptNo": { "type": "String" } }
  },
  "refundSelectAll": "Выбрать все",
  "refundDeselectAll": "Снять все",
  "refundReasonLabel": "Причина возврата",
  "refundReasonHint": "Укажите причину возврата",
  "refundTotalLine": "Сумма возврата: {amount}",
  "@refundTotalLine": {
    "description": "Refund page — bottom bar total line. {amount} is the pre-formatted refund total. Collapses what was previously two separately-styled Text widgets (grey label + bold red value) into one Text per the label+separator+value composite-string rule (.claude/rules/mobile-l10n.md); the merged Text keeps the bold/red styling since the total is the more important visual signal. Distinct from `investmentReturnAmountLabel` (also \"Сумма возврата\", but a form field label on the add-investment screen for a different concept — money returned to an investor, not a sale refund)",
    "placeholders": { "amount": { "type": "String" } }
  },
  "refundSubmitButton": "Оформить возврат",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

`build(BuildContext context)` does not currently bind `l10n` — add `final l10n = AppLocalizations.of(context)!;` right after the opening brace. The confirm dialog (`_confirmRefund()`, lines ~72-95) has its own `ctx` from `builder: (ctx) => AlertDialog(...)`, distinct from the page's `context` — use `AppLocalizations.of(ctx)!` there.

| Find | Replace with |
|---|---|
| `title: const Text('Подтвердить возврат?'),` | `title: Text(AppLocalizations.of(ctx)!.refundConfirmTitle),` |
| `'Сумма возврата: ${Formatters.price(_refundTotal)}\n'` <br> `'Выбрано позиций: ${_selectedItems.length}',` | `AppLocalizations.of(ctx)!.refundConfirmBody(Formatters.price(_refundTotal), _selectedItems.length.toString()),` |
| `child: const Text('Отмена'),` | `child: Text(AppLocalizations.of(ctx)!.cancel),` |
| `child: const Text('Подтвердить',` | `child: Text(AppLocalizations.of(ctx)!.confirm,` |
| `title: const Text('Возврат'),` | `title: Text(l10n.refund),` |
| `'Выберите товары для возврата',` | `l10n.refundInstructionBanner,` |
| `'Чек ${widget.sale.receiptNo}',` | `l10n.refundReceiptLabel(widget.sale.receiptNo),` |
| `const Text('Товары',` | `Text(l10n.products,` |
| `? 'Снять все'` | `? l10n.refundDeselectAll` |
| `: 'Выбрать все',` | `: l10n.refundSelectAll,` |
| `const Text('Причина возврата',` | `Text(l10n.refundReasonLabel,` |
| `hint: 'Укажите причину возврата',` | `hint: l10n.refundReasonHint,` |
| `Text('Сумма возврата:',` (bottom-bar label, ~line 300) | *(see below — merged with its sibling value Text)* |
| `text: 'Оформить возврат',` | `text: l10n.refundSubmitButton,` |

For the bottom-bar total (lines 296-313), merge the two-Text `Row` into one `Text`:

Find:
```dart
Row(
  mainAxisAlignment:
      MainAxisAlignment.spaceBetween,
  children: [
    Text('Сумма возврата:',
        style: TextStyle(
            fontSize: 16,
            color: context.textSecondary)),
    Text(
      Formatters.price(_refundTotal),
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.error,
      ),
    ),
  ],
),
```
Replace with:
```dart
Text(
  l10n.refundTotalLine(Formatters.price(_refundTotal)),
  style: const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.error,
  ),
),
```

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep refund_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/sales/refund_page_golden_test.dart test/presentation/pages/sales/refund_page_test.dart --reporter expanded` — expect passing.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/sales/refund_page.dart
git commit -m "fix(app): migrate refund_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 16: Migrate `add_adjustment_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/payroll/add_adjustment_page.dart`

Current offenders (all 15, verbatim):
```
63: appBar: AppBar(title: const Text('Корректировка')),
97: 'Добавить корректировку',
102: 'Укажите тип, сумму и описание корректировки',
111: 'Тип корректировки',
119: label: 'Бонус',
129: label: 'Удержание',
141: label: 'ID сотрудника (необязательно)',
143: hint: 'Оставьте пустым для всех',
148: label: 'Сумма (TJS)',
152: if (v == null || v.isEmpty) return 'Введите сумму';
153: if (double.tryParse(v) == null) return 'Некорректная сумма';
154: if (double.parse(v) <= 0) return 'Сумма должна быть больше 0';
161: label: 'Описание',
165: if (v == null || v.trim().isEmpty) return 'Введите описание';
173: text: 'Добавить',
```

This file shares vocabulary with the already-migrated `payroll_page.dart` — check for `payroll*` keys before minting anything new.

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"bonus"\|"deduction"\|"payrollAddAdjustmentTooltip"\|"shiftsCashAmountRequired"\|"invalidAmount"\|"^  \"description\"\|"amountTjs"' lib/l10n/app_ru.arb`
- `bonus`: `"Бонус"` — exact match, reuse for line 119.
- **Do not** reuse `deduction` for line 129 — `deduction` holds `"Вычет"`, not `"Удержание"`. Different Russian word, same rough concept — this is exactly the kind of trap that shipped bugs `f54d5fd`/`bb6a1cc` in the predecessor branch. Mint a new key.
- `payrollAddAdjustmentTooltip`: `"Добавить корректировку"` (added by Task 7 for `payroll_page.dart`'s icon-button tooltip) — exact character match to line 97's heading text. Reuse it here too even though the UI role differs (tooltip vs. form heading), per the established "same text, reuse unless it reads awkwardly" convention.
- `shiftsCashAmountRequired`: `"Введите сумму"` — exact match for line 152, despite its shifts-specific name and `@key` description ("Close-shift dialog — validation error..."). This exact literal is used verbatim in 4 separate files across the codebase (`add_expense_page.dart`, `add_investment_page.dart`, `add_adjustment_page.dart`, `open_shift_page.dart`); reuse per meaning, not per name, same precedent as Task 5's `createStoreNameRequiredError` reuse.
- `invalidAmount`: `"Некорректная сумма"` — exact match, reuse for line 153.
- `description`: `"Описание"` — exact match, reuse for line 161. (Note: the ARB also has orphaned `adjustmentDescription`/`adjustmentAmount`/`adjustmentType` keys with the same generic values — grep confirms they are **not referenced anywhere in `lib/`**, so their intended UI role is unclear; prefer the actively-used generic `description`/`amountTjs` keys instead of these unused ones.)
- `amountTjs`: `"Сумма (TJS)"` — exact match for line 148. Its existing `@amountTjs` description explicitly calls out *"this exact literal also recurs verbatim on other payment-amount fields (e.g. the payroll adjustment screen)"* — this key was pre-anticipated for this exact call site.

No match exists for: `'Корректировка'`, `'Укажите тип, сумму и описание корректировки'`, `'Тип корректировки'`, `'Удержание'`, `'ID сотрудника (необязательно)'`, `'Оставьте пустым для всех'`, `'Сумма должна быть больше 0'`, `'Введите описание'`, `'Добавить'` (bare submit button).

- [ ] **Step 2: Add new keys to `app_ru.arb`**

Insert into the `payroll*` block, right after `"payrollPaidLabel": "Выплачено",` / its `@payrollPaidLabel` line (around line 1249, before the `permissions` block starts):

```json
  "payrollAdjustmentPageTitle": "Корректировка",
  "payrollAdjustmentInstructions": "Укажите тип, сумму и описание корректировки",
  "payrollAdjustmentTypeLabel": "Тип корректировки",
  "payrollDeductionTypeLabel": "Удержание",
  "@payrollDeductionTypeLabel": { "description": "Add-adjustment form's deduction-type toggle label; distinct from `deduction` (\"Вычет\"), a different Russian word used elsewhere for the same underlying concept — do not merge, values differ character-for-character" },
  "payrollAdjustmentStaffIdLabel": "ID сотрудника (необязательно)",
  "payrollAdjustmentStaffIdHint": "Оставьте пустым для всех",
  "payrollAdjustmentDescriptionRequiredError": "Введите описание",
  "payrollAdjustmentAmountMustBePositiveError": "Сумма должна быть больше 0",
  "payrollAdjustmentSubmit": "Добавить",
  "@payrollAdjustmentSubmit": { "description": "Add-adjustment form's bare submit button label" },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

`build(BuildContext context)` does not bind an `l10n` variable — add `final l10n = AppLocalizations.of(context)!;` right after the opening brace (the existing inline `AppLocalizations.of(context)!.snackAdjustmentAdded` call in the `BlocListener` can stay untouched — purely additive change).

| Find | Replace with |
|---|---|
| `appBar: AppBar(title: const Text('Корректировка')),` | `appBar: AppBar(title: Text(l10n.payrollAdjustmentPageTitle)),` |
| `'Добавить корректировку',` | `l10n.payrollAddAdjustmentTooltip,` |
| `'Укажите тип, сумму и описание корректировки',` | `l10n.payrollAdjustmentInstructions,` |
| `'Тип корректировки',` | `l10n.payrollAdjustmentTypeLabel,` |
| `label: 'Бонус',` | `label: l10n.bonus,` |
| `label: 'Удержание',` | `label: l10n.payrollDeductionTypeLabel,` |
| `label: 'ID сотрудника (необязательно)',` | `label: l10n.payrollAdjustmentStaffIdLabel,` |
| `hint: 'Оставьте пустым для всех',` | `hint: l10n.payrollAdjustmentStaffIdHint,` |
| `label: 'Сумма (TJS)',` | `label: l10n.amountTjs,` |
| `if (v == null || v.isEmpty) return 'Введите сумму';` | `if (v == null || v.isEmpty) return l10n.shiftsCashAmountRequired;` |
| `if (double.tryParse(v) == null) return 'Некорректная сумма';` | `if (double.tryParse(v) == null) return l10n.invalidAmount;` |
| `if (double.parse(v) <= 0) return 'Сумма должна быть больше 0';` | `if (double.parse(v) <= 0) return l10n.payrollAdjustmentAmountMustBePositiveError;` |
| `label: 'Описание',` | `label: l10n.description,` |
| `if (v == null || v.trim().isEmpty) return 'Введите описание';` | `if (v == null || v.trim().isEmpty) return l10n.payrollAdjustmentDescriptionRequiredError;` |
| `text: 'Добавить',` | `text: l10n.payrollAdjustmentSubmit,` |

Since `'Добавить корректировку'` (line 97) sits inside a `const Text(...)`, drop the `const` on that `Text` widget (its parent `Column`/`Container` may keep `const` where it doesn't wrap this literal — read the surrounding declaration before editing).

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep add_adjustment_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/payroll/add_adjustment_page_golden_test.dart --reporter expanded` — expect passing.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/payroll/add_adjustment_page.dart
git commit -m "fix(app): migrate add_adjustment_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 17: Migrate `add_investment_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/finance/add_investment_page.dart`

Current offenders (all 15, verbatim):
```
125: appBar: AppBar(title: const Text('Добавить вложение')),
150: label: 'Название *',
153: if (v == null || v.isEmpty) return 'Введите название';
160: label: 'Описание',
166: label: 'Сумма *',
170: if (v == null || v.isEmpty) return 'Введите сумму';
172: return 'Некорректная сумма';
180: label: 'Сумма возврата',
187: label: 'Имя инвестора *',
191: return 'Введите имя инвестора';
199: label: 'Телефон инвестора',
204: const Text('Дата начала',
234: const Text('Дата окончания (необязательно)',
259: : 'Не выбрана',
275: text: 'Сохранить',
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"createStoreNameRequiredError"\|"shiftsCashAmountRequired"\|"myStoresNameLabel"\|"invalidAmount"\|"^  \"description\"\|"^  \"save\"'  lib/l10n/app_ru.arb`
- `createStoreNameRequiredError`: `"Введите название"` — exact match for line 153, despite its store-specific name (already established precedent from Task 5).
- `shiftsCashAmountRequired`: `"Введите сумму"` — exact match for line 170, same reuse rationale as Task 16.
- `myStoresNameLabel`: `"Название *"` — exact match for line 150 (added by Task 5 for the my-stores form; reuse here for the same "required name field with asterisk" meaning).
- `invalidAmount`: `"Некорректная сумма"` — exact match for line 172.
- `description`: `"Описание"` — exact match for line 160.
- `save`: `"Сохранить"` — exact match for line 275.

No match exists for: `'Добавить вложение'` (AppBar title — the existing `investment*` keys are all snackbar messages: `investmentCreated`/`Updated`/`Deleted`, none hold this title text), `'Сумма *'`, `'Сумма возврата'` (no leading `Введите`/trailing colon — a bare field label, different from `refund_page.dart`'s `'Сумма возврата:'`), `'Имя инвестора *'`, `'Введите имя инвестора'`, `'Телефон инвестора'`, `'Дата начала'`, `'Дата окончания (необязательно)'`, `'Не выбрана'`.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

Insert right after `"investmentDeleted": "Вложение удалено",` (the last two keys in the file, just before the closing `}`):

```json
  "investmentAddPageTitle": "Добавить вложение",
  "investmentInvestorNameRequiredError": "Введите имя инвестора",
  "investmentStartDateLabel": "Дата начала",
  "investmentEndDateLabel": "Дата окончания (необязательно)",
  "investmentInvestorNameLabel": "Имя инвестора *",
  "investmentEndDateNotSelected": "Не выбрана",
  "investmentAmountLabel": "Сумма *",
  "investmentReturnAmountLabel": "Сумма возврата",
  "@investmentReturnAmountLabel": { "description": "Add-investment form field — amount returned to the investor. Distinct from `refundTotalLine` (also containing \"Сумма возврата\", but a sale-refund total display on a different screen — different domain, same words" },
  "investmentInvestorPhoneLabel": "Телефон инвестора"
```

(Since this is the last block in the file, drop the trailing comma on the final new key or add one back onto `"investmentDeleted"` — whichever keeps the JSON valid; run `flutter gen-l10n` immediately after to confirm the file still parses.)

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

`build(BuildContext context)` already binds `final l10n = AppLocalizations.of(context)!;` at line 119 — use it directly.

| Find | Replace with |
|---|---|
| `appBar: AppBar(title: const Text('Добавить вложение')),` | `appBar: AppBar(title: Text(l10n.investmentAddPageTitle)),` |
| `label: 'Название *',` | `label: l10n.myStoresNameLabel,` |
| `if (v == null || v.isEmpty) return 'Введите название';` | `if (v == null || v.isEmpty) return l10n.createStoreNameRequiredError;` |
| `label: 'Описание',` | `label: l10n.description,` |
| `label: 'Сумма *',` | `label: l10n.investmentAmountLabel,` |
| `if (v == null || v.isEmpty) return 'Введите сумму';` | `if (v == null || v.isEmpty) return l10n.shiftsCashAmountRequired;` |
| `return 'Некорректная сумма';` | `return l10n.invalidAmount;` |
| `label: 'Сумма возврата',` | `label: l10n.investmentReturnAmountLabel,` |
| `label: 'Имя инвестора *',` | `label: l10n.investmentInvestorNameLabel,` |
| `return 'Введите имя инвестора';` | `return l10n.investmentInvestorNameRequiredError;` |
| `label: 'Телефон инвестора',` | `label: l10n.investmentInvestorPhoneLabel,` |
| `const Text('Дата начала',` | `Text(l10n.investmentStartDateLabel,` |
| `const Text('Дата окончания (необязательно)',` | `Text(l10n.investmentEndDateLabel,` |
| `: 'Не выбрана',` | `: l10n.investmentEndDateNotSelected,` |
| `text: 'Сохранить',` | `text: l10n.save,` |

Note lines 204/234 drop `const` on those `Text` widgets since `l10n.investmentStartDateLabel`/`l10n.investmentEndDateLabel` are not compile-time constants — verify the parent widget tree doesn't otherwise assume `const`.

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep add_investment_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/finance/add_investment_page_test.dart test/presentation/pages/finance/add_investment_page_golden_test.dart --reporter expanded` — expect passing.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json lib/presentation/pages/finance/add_investment_page.dart
git commit -m "fix(app): migrate add_investment_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 18: Migrate `add_expense_page.dart`

**Files:**
- Modify: `lib/presentation/pages/finance/add_expense_page.dart`
- (No `app_ru.arb` changes needed — see Step 1.)

Current offenders (all 15, verbatim):
```
40: ('PURCHASE', 'Закупка'),
41: ('RENT', 'Аренда'),
42: ('SALARY', 'Зарплата'),
43: ('UTILITIES', 'Коммунальные'),
44: ('TRANSPORT', 'Транспорт'),
45: ('MARKETING', 'Маркетинг'),
46: ('OTHER', 'Другое'),
90: appBar: AppBar(title: const Text('Добавить расход')),
108: const Text('Категория', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
133: label: 'Сумма',
137: if (v == null || v.isEmpty) return 'Введите сумму';
138: if (double.tryParse(v) == null) return 'Некорректная сумма';
145: label: 'Описание',
151: label: 'Заметки',
183: text: 'Сохранить',
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"^  \"rent\"\|"^  \"salary\"\|"^  \"utilities\"\|"^  \"transport\"\|"^  \"marketing\"\|"^  \"other\"\|"^  \"purchase\"\|"addExpense"\|"^  \"category\"\|"^  \"amount\"\|"shiftsCashAmountRequired"\|"invalidAmount"\|"^  \"description\"\|"^  \"notes\"\|"^  \"save\"' lib/l10n/app_ru.arb`

**Every single offender in this file has an exact-match existing key — no new ARB keys are needed at all.** `expense_list_page.dart` (already migrated, outside this batch) establishes the identical `('CODE', l10n.key)` tuple-list pattern for the same 7 expense categories:

- `purchase`: `"Закупка"` — reuse for `'PURCHASE'` entry.
- `rent`: `"Аренда"` — reuse for `'RENT'`.
- `salary`: `"Зарплата"` — reuse for `'SALARY'`. (Do not confuse with the unrelated `payroll` key, which also holds `"Зарплата"` but means the Payroll *section*, not an expense category — `expense_list_page.dart`'s own precedent already uses `salary` for this exact category, confirming the correct key.)
- `utilities`: `"Коммунальные"` — reuse for `'UTILITIES'`.
- `transport`: `"Транспорт"` — reuse for `'TRANSPORT'`.
- `marketing`: `"Маркетинг"` — reuse for `'MARKETING'`.
- `other`: `"Другое"` — reuse for `'OTHER'`.
- `addExpense`: `"Добавить расход"` — exact match for the AppBar title (line 90); already used in `expense_list_page.dart` as an empty-state button label — same meaning, reuse.
- `category`: `"Категория"` — exact match for line 108 (do not use `expenseCategory`, which holds the differently-worded `"Категория расхода"`).
- `amount`: `"Сумма"` — exact match for line 133 (bare, no `(TJS)` suffix — do not use `amountTjs`).
- `shiftsCashAmountRequired`: `"Введите сумму"` — exact match for line 137, same cross-file reuse rationale as Tasks 16/17.
- `invalidAmount`: `"Некорректная сумма"` — exact match for line 138.
- `description`: `"Описание"` — exact match for line 145.
- `notes`: `"Заметки"` — exact match for line 151.
- `save`: `"Сохранить"` — exact match for line 183.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

None — skip this step entirely for this task.

- [ ] **Step 3: Regenerate localizations**

Skip — no ARB changes were made, so `flutter gen-l10n` is not required for this task. (If you're running Task 18 as part of the same session as Task 17, the generated files will already be current from that task's run.)

- [ ] **Step 4: Replace literals**

`build(BuildContext context)` already binds `final l10n = AppLocalizations.of(context)!;` at line 88 — use it directly. `_categoryOptions` (line 39) is currently a `final` **instance field initializer**, which runs during object construction — before the widget is mounted and before `context`/`AppLocalizations.of(context)` is available. It must become a method that takes `l10n` as a parameter, called from `build()`.

| Find | Replace with |
|---|---|
| `appBar: AppBar(title: const Text('Добавить расход')),` | `appBar: AppBar(title: Text(l10n.addExpense)),` |
| `const Text('Категория', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),` | `Text(l10n.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),` |
| `label: 'Сумма',` | `label: l10n.amount,` |
| `if (v == null || v.isEmpty) return 'Введите сумму';` | `if (v == null || v.isEmpty) return l10n.shiftsCashAmountRequired;` |
| `if (double.tryParse(v) == null) return 'Некорректная сумма';` | `if (double.tryParse(v) == null) return l10n.invalidAmount;` |
| `label: 'Описание',` | `label: l10n.description,` |
| `label: 'Заметки',` | `label: l10n.notes,` |
| `text: 'Сохранить',` | `text: l10n.save,` |

For the category options (lines 39-47), convert the field to a method:

Find:
```dart
  final _categoryOptions = [
    ('PURCHASE', 'Закупка'),
    ('RENT', 'Аренда'),
    ('SALARY', 'Зарплата'),
    ('UTILITIES', 'Коммунальные'),
    ('TRANSPORT', 'Транспорт'),
    ('MARKETING', 'Маркетинг'),
    ('OTHER', 'Другое'),
  ];
```
Replace with:
```dart
  List<(String, String)> _categoryOptions(AppLocalizations l10n) => [
    ('PURCHASE', l10n.purchase),
    ('RENT', l10n.rent),
    ('SALARY', l10n.salary),
    ('UTILITIES', l10n.utilities),
    ('TRANSPORT', l10n.transport),
    ('MARKETING', l10n.marketing),
    ('OTHER', l10n.other),
  ];
```
And update its one call site (line ~120):

| Find | Replace with |
|---|---|
| `items: _categoryOptions.map((c) => DropdownMenuItem(` | `items: _categoryOptions(l10n).map((c) => DropdownMenuItem(` |

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep add_expense_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/finance/add_expense_page_golden_test.dart --reporter expanded` — expect passing.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/pages/finance/add_expense_page.dart
git commit -m "fix(app): migrate add_expense_page.dart hardcoded strings to AppLocalizations"
```

---
### Task 19: Migrate Settings misc A (`offline_mode_page.dart`, `kkm_settings_page.dart`, `scanner_settings_page.dart`)

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/settings/offline_mode_page.dart`
- Modify: `lib/presentation/pages/settings/kkm_settings_page.dart`
- Modify: `lib/presentation/pages/settings/scanner_settings_page.dart`

This task migrates all 41 counted offenders across these 3 files in one commit, since each is small individually. All three files already import `package:dukonpro/l10n/app_localizations.dart` and already have some `AppLocalizations.of(context)!` calls elsewhere in the same file (dialogs/snackbars) — none currently declares a local `l10n` variable inside `build()`; add `final l10n = AppLocalizations.of(context)!;` at the top of each file's `build()` for the new replacements.

**Cross-file reuse inside this bundle:** both `offline_mode_page.dart` (line 296) and `kkm_settings_page.dart` (line 320) render a section-header `Text('Настройки', ...)` — identical Russian text, identical role (a settings-section label). Reuse the existing generic key `settings` (`"Настройки"`, confirmed at `app_ru.arb:700`) in both files rather than minting a per-file key.

**Major reuse discovery:** `kkm_settings_page.dart`'s Bluetooth-printer connection UI is near-identical to an already-migrated generic printer-settings screen. `app_ru.arb` already holds `printerSettingsConnected` ("Подключён"), `printerSettingsNotConnected` ("Не подключён"), `printerSettingsDisconnectButton` ("Отключить"), `printerSettingsScanButton` ("Найти принтеры"), `printerSettingsScanningButton` ("Поиск..."), `printerSettingsFoundDevicesTitle` ("Найденные устройства"), `printerSettingsTestPrintButton` ("Тестовая печать"), `printerSettingsPrintingButton` ("Печать..."), and `printerSettingsConnectButton` ("Подключить") — all verified exact-value matches to this file's offenders. Reuse them all instead of minting `kkm*` duplicates.

#### `offline_mode_page.dart` (14 offenders)

Current offenders (verbatim):
```
97:              .snackSyncError('не удалось синхронизировать часть операций'),
189:        title: const Text('Офлайн-режим'),
233:                                  ? 'Всё синхронизировано'
234:                                  : '$_pendingOps операций в очереди',
248:                            'Последняя синхронизация: ${_formatDate(_lastSync!)}',
256:                            'Синхронизация ещё не выполнялась',
287:                        _syncing ? 'Синхронизация...' : 'Синхронизировать сейчас',
296:                  Text('Настройки',
327:                                Text('Авто-синхронизация',
331:                                Text('Синхронизировать при подключении к сети',
364-366:                            'В офлайн-режиме все операции сохраняются локально '
                                    'и автоматически синхронизируются при восстановлении '
                                    'подключения к интернету.',
378:                  Text('Данные',
```
(The 3 fragments at 364-366 are Dart adjacent-string-literal concatenation forming ONE sentence — the allow-list has them as 3 separate entries, but they must be replaced as a single full-sentence key per `.claude/rules/mobile-l10n.md`.)

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"settingsTileOfflineMode"\|"settings":' lib/l10n/app_ru.arb`
Expected: `settingsTileOfflineMode: "Офлайн-режим"` (exact match to the AppBar title) and `settings: "Настройки"` (exact match to the section label, shared with `kkm_settings_page.dart` below) — reuse both.

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "offlineSyncErrorPartialDetail": "не удалось синхронизировать часть операций",
  "@offlineSyncErrorPartialDetail": { "description": "Detail text passed into the generic `snackSyncError({error})` template when a manual sync partially fails" },
  "offlineAllSynced": "Всё синхронизировано",
  "offlinePendingOpsCount": "{count} операций в очереди",
  "@offlinePendingOpsCount": { "placeholders": { "count": { "type": "String" } } },
  "offlineLastSyncLabel": "Последняя синхронизация: {date}",
  "@offlineLastSyncLabel": { "placeholders": { "date": { "type": "String" } } },
  "offlineNeverSynced": "Синхронизация ещё не выполнялась",
  "offlineSyncingButton": "Синхронизация...",
  "offlineSyncNowButton": "Синхронизировать сейчас",
  "@offlineSyncNowButton": { "description": "Manual-sync button's default (non-syncing) label — currently hardcoded as the second branch of the same ternary as offlineSyncingButton; not previously caught by the lint tool because it shares a line with a counted offender" },
  "offlineAutoSyncLabel": "Авто-синхронизация",
  "offlineAutoSyncDescription": "Синхронизировать при подключении к сети",
  "offlineInfoBody": "В офлайн-режиме все операции сохраняются локально и автоматически синхронизируются при восстановлении подключения к интернету.",
  "offlineDataSectionLabel": "Данные",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `offline_mode_page.dart`**

| Find | Replace with |
|---|---|
| `.snackSyncError('не удалось синхронизировать часть операций'),` | `.snackSyncError(l10n.offlineSyncErrorPartialDetail),` |
| `title: const Text('Офлайн-режим'),` | `title: Text(l10n.settingsTileOfflineMode),` |
| `? 'Всё синхронизировано'` | `? l10n.offlineAllSynced` |
| `: '$_pendingOps операций в очереди',` | `: l10n.offlinePendingOpsCount(_pendingOps.toString()),` |
| `'Последняя синхронизация: ${_formatDate(_lastSync!)}',` | `l10n.offlineLastSyncLabel(_formatDate(_lastSync!)),` |
| `'Синхронизация ещё не выполнялась',` | `l10n.offlineNeverSynced,` |
| `_syncing ? 'Синхронизация...' : 'Синхронизировать сейчас',` | `_syncing ? l10n.offlineSyncingButton : l10n.offlineSyncNowButton,` |
| `Text('Настройки',` (section label above the auto-sync switch) | `Text(l10n.settings,` |
| `Text('Авто-синхронизация',` | `Text(l10n.offlineAutoSyncLabel,` |
| `Text('Синхронизировать при подключении к сети',` | `Text(l10n.offlineAutoSyncDescription,` |
| `'В офлайн-режиме все операции сохраняются локально '\n                            'и автоматически синхронизируются при восстановлении '\n                            'подключения к интернету.',` | `l10n.offlineInfoBody,` |
| `Text('Данные',` | `Text(l10n.offlineDataSectionLabel,` |

Add `final l10n = AppLocalizations.of(context)!;` at the top of `build(BuildContext context)` (the existing dialog method `_confirmClearCache` already has its own local `l10n` — leave that one alone).

#### `kkm_settings_page.dart` (14 offenders)

Current offenders (verbatim):
```
132: bytes.addAll('Тестовая печать\n'.codeUnits);
133: bytes.addAll('ККМ/Фискализация\n'.codeUnits);
145: title: const Text('ККМ / Фискализация'),
169-170: 'Фискализация чеков через подключённый ККМ-принтер. '
         'Убедитесь, что устройство зарегистрировано в налоговой.',
180: Text('Bluetooth принтер',
215: _connectedDevice != null ? 'Подключён' : 'Не подключён',
234: child: const Text('Отключить',
260: label: Text(_isScanning ? 'Поиск...' : 'Найти принтеры'),
267: Text('Найденные устройства',
310: child: const Text('Подключить'),
320: Text('Настройки',
346: const Text('Автопечать при продаже',
380: label: Text(_isPrinting ? 'Печать...' : 'Тестовая печать'),
```
Note: `'Не подключён'` (line 215), `'Найти принтеры'` (line 260), and `'Тестовая печать'` without the trailing `\n` (line 380) are **bonus** — each shares a line with a counted offender and was never surfaced by the lint tool's one-match-per-line regex, but they're genuinely hardcoded and all three happen to have exact reusable keys already (see Step 1).

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"settingsTileKkm"\|"settings":\|"printerSettingsConnected"\|"printerSettingsNotConnected"\|"printerSettingsDisconnectButton"\|"printerSettingsScanButton"\|"printerSettingsScanningButton"\|"printerSettingsFoundDevicesTitle"\|"printerSettingsTestPrintButton"\|"printerSettingsPrintingButton"\|"printerSettingsConnectButton"' lib/l10n/app_ru.arb`

Expected — all of these already exist with exact matching values, reuse every one:
- `settingsTileKkm`: `"ККМ / Фискализация"` (line 145's AppBar title)
- `settings`: `"Настройки"` (line 320's section label — same shared key as `offline_mode_page.dart` above)
- `printerSettingsConnected`: `"Подключён"` (line 215, first branch)
- `printerSettingsNotConnected`: `"Не подключён"` (line 215, bonus second branch)
- `printerSettingsDisconnectButton`: `"Отключить"` (line 234)
- `printerSettingsScanButton`: `"Найти принтеры"` (line 260, bonus second branch)
- `printerSettingsScanningButton`: `"Поиск..."` (line 260, first branch)
- `printerSettingsFoundDevicesTitle`: `"Найденные устройства"` (line 267)
- `printerSettingsConnectButton`: `"Подключить"` (line 310)
- `printerSettingsPrintingButton`: `"Печать..."` (line 380, first branch)
- `printerSettingsTestPrintButton`: `"Тестовая печать"` (line 380, bonus second branch — **verify** this key's value has no trailing `\n`; it must match the bare button text, not the byte-string variant at line 132, which keeps its own key below)

These key names carry a `printerSettings` prefix from wherever they first shipped, even though we're reusing them in a KKM (fiscal-printer) context — per `.claude/rules/mobile-l10n.md` the discriminator is the string's *meaning* ("connected"/"not connected"/"scanning..." etc.), not where it renders, so this reuse is correct despite the naming mismatch. Do not rename the existing keys (out of scope — they're used elsewhere already).

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "kkmTicketHeaderLine": "ККМ/Фискализация\n",
  "@kkmTicketHeaderLine": { "description": "Line printed on the raw ESC/POS test ticket bytes — includes a literal trailing newline; distinct from settingsTileKkm (\"ККМ / Фискализация\", with spaces, no newline), used in UI text" },
  "kkmTestPrintTicketLine": "Тестовая печать\n",
  "@kkmTestPrintTicketLine": { "description": "Line printed on the raw ESC/POS test ticket bytes — includes a literal trailing newline; distinct from printerSettingsTestPrintButton (\"Тестовая печать\", no newline), the visible button label" },
  "kkmFiscalNoteBody": "Фискализация чеков через подключённый ККМ-принтер. Убедитесь, что устройство зарегистрировано в налоговой.",
  "kkmBluetoothPrinterSectionLabel": "Bluetooth принтер",
  "kkmAutoPrintLabel": "Автопечать при продаже",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `kkm_settings_page.dart`**

| Find | Replace with |
|---|---|
| `bytes.addAll('Тестовая печать\n'.codeUnits);` | `bytes.addAll(l10n.kkmTestPrintTicketLine.codeUnits);` |
| `bytes.addAll('ККМ/Фискализация\n'.codeUnits);` | `bytes.addAll(l10n.kkmTicketHeaderLine.codeUnits);` |
| `title: const Text('ККМ / Фискализация'),` | `title: Text(l10n.settingsTileKkm),` |
| `'Фискализация чеков через подключённый ККМ-принтер. '\n                      'Убедитесь, что устройство зарегистрировано в налоговой.',` | `l10n.kkmFiscalNoteBody,` |
| `Text('Bluetooth принтер',` | `Text(l10n.kkmBluetoothPrinterSectionLabel,` |
| `_connectedDevice != null ? 'Подключён' : 'Не подключён',` | `_connectedDevice != null ? l10n.printerSettingsConnected : l10n.printerSettingsNotConnected,` |
| `child: const Text('Отключить',` | `child: Text(l10n.printerSettingsDisconnectButton,` |
| `label: Text(_isScanning ? 'Поиск...' : 'Найти принтеры'),` | `label: Text(_isScanning ? l10n.printerSettingsScanningButton : l10n.printerSettingsScanButton),` |
| `Text('Найденные устройства',` | `Text(l10n.printerSettingsFoundDevicesTitle,` |
| `child: const Text('Подключить'),` | `child: Text(l10n.printerSettingsConnectButton),` |
| `Text('Настройки',` | `Text(l10n.settings,` |
| `const Text('Автопечать при продаже',` | `Text(l10n.kkmAutoPrintLabel,` |
| `label: Text(_isPrinting ? 'Печать...' : 'Тестовая печать'),` | `label: Text(_isPrinting ? l10n.printerSettingsPrintingButton : l10n.printerSettingsTestPrintButton),` |

`_buildTestTicket()` is an `async` method of the State class, so `context`/`l10n` are reachable there too — either pass `l10n` in as a parameter or call `AppLocalizations.of(context)!` directly inside it (the State's inherited `context` getter is safe here since it's called synchronously from `_testPrint`, which already checks `mounted`). Add `final l10n = AppLocalizations.of(context)!;` at the top of `build(BuildContext context)`.

#### `scanner_settings_page.dart` (13 offenders)

Current offenders (verbatim):
```
74:        title: const Text('Сканер штрихкодов'),
84:                : const Text('Сохранить',
98:                  Text('Камера',
116:                            title: const Text('Задняя камера',
119:                            subtitle: const Text('Рекомендуется для сканирования',
135:                            title: const Text('Передняя камера',
138:                            subtitle: const Text('Фронтальная камера',
158:                  Text('Поведение',
173:                          'Звук при сканировании',
180:                          'Вибрация при сканировании',
187:                          'Авто-добавление в корзину',
197:                  Text('Форматы штрихкодов',
262:                          : const Text('Сохранить настройки',
```

No cross-file exact-value matches were found for this file's other 12 strings anywhere in `app_ru.arb` — mint them all as new, file-prefixed keys.

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"save":' lib/l10n/app_ru.arb`
Expected: `save: "Сохранить"` — reuse for line 84's AppBar action button (note: this is distinct from line 262's `"Сохранить настройки"`, a different, longer string — do not force-reuse `save` there, mint `scannerSaveSettingsButton` instead).

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "scannerPageTitle": "Сканер штрихкодов",
  "scannerCameraSectionLabel": "Камера",
  "scannerBackCameraLabel": "Задняя камера",
  "scannerBackCameraHint": "Рекомендуется для сканирования",
  "scannerFrontCameraLabel": "Передняя камера",
  "scannerFrontCameraHint": "Фронтальная камера",
  "scannerBehaviorSectionLabel": "Поведение",
  "scannerSoundLabel": "Звук при сканировании",
  "scannerVibrationLabel": "Вибрация при сканировании",
  "scannerAutoAddToCartLabel": "Авто-добавление в корзину",
  "scannerFormatsSectionLabel": "Форматы штрихкодов",
  "scannerSaveSettingsButton": "Сохранить настройки",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `scanner_settings_page.dart`**

| Find | Replace with |
|---|---|
| `title: const Text('Сканер штрихкодов'),` | `title: Text(l10n.scannerPageTitle),` |
| `: const Text('Сохранить',` (AppBar action) | `: Text(l10n.save,` |
| `Text('Камера',` | `Text(l10n.scannerCameraSectionLabel,` |
| `title: const Text('Задняя камера',` | `title: Text(l10n.scannerBackCameraLabel,` |
| `subtitle: const Text('Рекомендуется для сканирования',` | `subtitle: Text(l10n.scannerBackCameraHint,` |
| `title: const Text('Передняя камера',` | `title: Text(l10n.scannerFrontCameraLabel,` |
| `subtitle: const Text('Фронтальная камера',` | `subtitle: Text(l10n.scannerFrontCameraHint,` |
| `Text('Поведение',` | `Text(l10n.scannerBehaviorSectionLabel,` |
| `'Звук при сканировании',` | `l10n.scannerSoundLabel,` |
| `'Вибрация при сканировании',` | `l10n.scannerVibrationLabel,` |
| `'Авто-добавление в корзину',` | `l10n.scannerAutoAddToCartLabel,` |
| `Text('Форматы штрихкодов',` | `Text(l10n.scannerFormatsSectionLabel,` |
| `: const Text('Сохранить настройки',` | `: Text(l10n.scannerSaveSettingsButton,` |

Add `final l10n = AppLocalizations.of(context)!;` at the top of `build(BuildContext context)`.

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep -E 'offline_mode_page.dart|kkm_settings_page.dart|scanner_settings_page.dart'` — expect no output.
Run: `flutter analyze` — expect `No issues found!`.
Run: `find test -iname '*offline_mode*' -o -iname '*kkm_settings*' -o -iname '*scanner_settings*'` to locate any existing tests for these 3 pages, then `flutter test <paths found> --reporter expanded` — expect all passing. If none exist, skip.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json \
  lib/presentation/pages/settings/offline_mode_page.dart \
  lib/presentation/pages/settings/kkm_settings_page.dart \
  lib/presentation/pages/settings/scanner_settings_page.dart
git commit -m "fix(app): migrate settings misc A (offline/kkm/scanner) hardcoded strings to AppLocalizations"
```

---

### Task 20: Migrate Settings misc B (`edit_profile_page.dart`, `telegram_bot_settings_page.dart`, `language_settings_page.dart`)

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/settings/edit_profile_page.dart`
- Modify: `lib/presentation/pages/settings/telegram_bot_settings_page.dart`
- Modify: `lib/presentation/pages/settings/language_settings_page.dart`
- Modify: `tool/i18n-allowlist.txt` (deliberate proper-noun exceptions — see Step for `language_settings_page.dart`)

This task migrates all 26 counted offenders across these 3 files in one commit. `edit_profile_page.dart` and `language_settings_page.dart` already declare `final l10n = AppLocalizations.of(context)!;` inside `build()` — reuse that binding, don't add a second one. `telegram_bot_settings_page.dart` does not yet have one; add it.

**FYI (not part of this migration):** `edit_profile_page.dart`'s `_roleLabel` method already calls `l10n.warehouse`, `l10n.owner`, `l10n.adminRoleShort`, `l10n.cashier` — pre-existing, unrelated code. Leave it untouched.

**Shared reuse inside this bundle:** `edit_profile_page.dart` (line 161, header "Сохранить" button) and `language_settings_page.dart` (line 200, bottom "Сохранить" button) both use the plain generic `save` key ("Сохранить") — not a new bundle key, just noting both files reuse the same existing generic key rather than each minting their own.

#### `edit_profile_page.dart` (10 offenders)

Current offenders (verbatim):
```
156:                      const Text('Профиль',
161:                          child: const Text('Сохранить',
185:                                const Text('Изменить фото',
193:                          _buildField('Имя', _firstNameController, validator: (v) {
194:                            if (v == null || v.isEmpty) return 'Введите имя';
198:                          _buildField('Фамилия', _lastNameController),
203:                          _buildField('Телефон', _phoneController,
232:                              child: Text('Безопасность',
244:                                  title: const Text('Сменить пароль',
266:                                state is SettingsLoading ? 'Сохранение...' : 'Сохранить изменения',
```
Note: `'Сохранить изменения'` (line 266, second ternary branch) is **bonus** — same-line as the counted `'Сохранение...'`, missed by the lint tool's one-match-per-line regex.

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"enterName"\|"name":\|"profile":\|"changePassword"\|"phoneLabel"\|"save":' lib/l10n/app_ru.arb`
Expected all exist with exact matching values — reuse:
- `enterName`: `"Введите имя"` (line 194)
- `name`: `"Имя"` (line 193, field label)
- `profile`: `"Профиль"` (line 156)
- `changePassword`: `"Сменить пароль"` (line 244)
- `phoneLabel`: `"Телефон"` (line 203, field label)
- `save`: `"Сохранить"` (line 161)

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "editProfileSecuritySectionLabel": "Безопасность",
  "editProfileChangePhotoLabel": "Изменить фото",
  "editProfileLastNameLabel": "Фамилия",
  "editProfileSavingButton": "Сохранение...",
  "editProfileSaveChangesButton": "Сохранить изменения",
  "@editProfileSaveChangesButton": { "description": "Bottom save button's default (non-saving) label — shares a line with editProfileSavingButton in a ternary, missed by the lint tool's one-match-per-line scan" },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `edit_profile_page.dart`**

| Find | Replace with |
|---|---|
| `const Text('Профиль',` | `Text(l10n.profile,` |
| `child: const Text('Сохранить',` | `child: Text(l10n.save,` |
| `const Text('Изменить фото',` | `Text(l10n.editProfileChangePhotoLabel,` |
| `_buildField('Имя', _firstNameController, validator: (v) {` | `_buildField(l10n.name, _firstNameController, validator: (v) {` |
| `if (v == null || v.isEmpty) return 'Введите имя';` | `if (v == null || v.isEmpty) return l10n.enterName;` |
| `_buildField('Фамилия', _lastNameController),` | `_buildField(l10n.editProfileLastNameLabel, _lastNameController),` |
| `_buildField('Телефон', _phoneController,` | `_buildField(l10n.phoneLabel, _phoneController,` |
| `child: Text('Безопасность',` | `child: Text(l10n.editProfileSecuritySectionLabel,` |
| `title: const Text('Сменить пароль',` | `title: Text(l10n.changePassword,` |
| `state is SettingsLoading ? 'Сохранение...' : 'Сохранить изменения',` | `state is SettingsLoading ? l10n.editProfileSavingButton : l10n.editProfileSaveChangesButton,` |

#### `telegram_bot_settings_page.dart` (9 offenders)

Current offenders (verbatim):
```
74:        title: const Text('Telegram-бот'),
135:                                    _connected ? 'Подключён' : 'Не подключён',
181:                              child: Text('Подключённых клиентов',
199:                  Text('Как подключить клиентов',
215:                        _buildStep('1', 'Клиент находит бота $_botUsername в Telegram'),
217:                        _buildStep('2', 'Нажимает /start и вводит свой номер телефона'),
219-220:                        _buildStep('3',
                                    'Бот проверяет номер в базе клиентов и связывает аккаунт'),
222-223:                        _buildStep('4',
                                    'Клиент получает уведомления о продажах и долгах'),
273:                          _sendingTest ? 'Отправка...' : 'Тестовое сообщение',
```
Note: `'Тестовое сообщение'` (line 273, second ternary branch) is **bonus**, same one-match-per-line gap.

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"settingsTileTelegramBot"\|"printerSettingsConnected"\|"printerSettingsNotConnected"' lib/l10n/app_ru.arb`
Expected: `settingsTileTelegramBot: "Telegram-бот"` (exact match, line 74 — reuse). `printerSettingsConnected`/`printerSettingsNotConnected` also exist (`"Подключён"`/`"Не подключён"`, exact match to line 135) — reuse them here too, same generic-status-string reasoning as `kkm_settings_page.dart` in Task 19 (meaning matches: a boolean connected/not-connected indicator; the `printerSettings` name prefix is legacy naming from wherever it first shipped, not a scope restriction).

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "telegramLinkedCustomersLabel": "Подключённых клиентов",
  "telegramHowToConnectTitle": "Как подключить клиентов",
  "telegramStep1Text": "Клиент находит бота {username} в Telegram",
  "@telegramStep1Text": { "placeholders": { "username": { "type": "String" } } },
  "telegramStep2Text": "Нажимает /start и вводит свой номер телефона",
  "telegramStep3Text": "Бот проверяет номер в базе клиентов и связывает аккаунт",
  "telegramStep4Text": "Клиент получает уведомления о продажах и долгах",
  "telegramSendingButton": "Отправка...",
  "telegramTestMessageButton": "Тестовое сообщение",
  "@telegramTestMessageButton": { "description": "Test-message button's default (non-sending) label — shares a line with telegramSendingButton in a ternary, missed by the lint tool's one-match-per-line scan" },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `telegram_bot_settings_page.dart`**

Add `final l10n = AppLocalizations.of(context)!;` at the top of `build(BuildContext context)`.

| Find | Replace with |
|---|---|
| `title: const Text('Telegram-бот'),` | `title: Text(l10n.settingsTileTelegramBot),` |
| `_connected ? 'Подключён' : 'Не подключён',` | `_connected ? l10n.printerSettingsConnected : l10n.printerSettingsNotConnected,` |
| `child: Text('Подключённых клиентов',` | `child: Text(l10n.telegramLinkedCustomersLabel,` |
| `Text('Как подключить клиентов',` | `Text(l10n.telegramHowToConnectTitle,` |
| `_buildStep('1', 'Клиент находит бота $_botUsername в Telegram'),` | `_buildStep('1', l10n.telegramStep1Text(_botUsername)),` |
| `_buildStep('2', 'Нажимает /start и вводит свой номер телефона'),` | `_buildStep('2', l10n.telegramStep2Text),` |
| `_buildStep('3',\n                            'Бот проверяет номер в базе клиентов и связывает аккаунт'),` | `_buildStep('3', l10n.telegramStep3Text),` |
| `_buildStep('4',\n                            'Клиент получает уведомления о продажах и долгах'),` | `_buildStep('4', l10n.telegramStep4Text),` |
| `_sendingTest ? 'Отправка...' : 'Тестовое сообщение',` | `_sendingTest ? l10n.telegramSendingButton : l10n.telegramTestMessageButton,` |

`_sendTestMessage()` already declares its own local `l10n` inside the `if (mounted)` block for the success path — leave that one, it's fine as-is (or replace with the new build()-level `l10n` if you prefer one binding per file; either is acceptable, just don't leave two different unrelated local vars named `l10n` doing the same lookup redundantly if avoidable).

#### `language_settings_page.dart` (7 offenders)

Current offenders (verbatim):
```
20:    _Language('ru', 'Русский', 'Русский язык', '🇷🇺'),
21:    _Language('tg', 'Тоҷикӣ', 'Забони тоҷикӣ', '🇹🇯'),
22:    _Language('uz', 'Ўзбекча', "O'zbek tili", '🇺🇿'),
59:        title: const Text('Язык интерфейса'),
70:                  Text('Выберите язык',
177:                            'Для применения языка перезапустите приложение.',
200:                              : const Text('Сохранить',
```

- [ ] **Step 1: Handle the deliberate proper-noun exceptions first**

`settings_page.dart` already treats these exact same 3 language names (`'Тоҷикӣ'`, `'Ўзбекча'`, `'Русский'`) as deliberate, permanently-hardcoded exceptions (a language's own name doesn't change based on the current UI locale) — see that file's allow-list comment block. `language_settings_page.dart`'s `_languages` list (lines 20-22) contains the exact same 3 proper nouns, so apply the identical precedent here: do **not** migrate them to ARB keys.

Additionally, each `_Language` record's third positional argument is the language's **native self-name** (`'Русский язык'`, `'Забони тоҷикӣ'`) — for `ru` and `tg` these contain Cyrillic and are equally untranslatable proper nouns (a language's native name is inherently written in that language), but they were never surfaced by `check_i18n.dart` at all: the regex only captures the *first* Cyrillic-quoted match per line, and these are the *second* Cyrillic match on lines 20-21 (the `uz` row's native name, `"O'zbek tili"`, has no Cyrillic at all so it was never flagged either way). Treat both as the same kind of deliberate exception and allow-list them too, for consistency.

Add to `tool/i18n-allowlist.txt` by hand (not via `--dump-allowlist`, since these need the explanatory comment — append near the existing `settings_page.dart` exception block or as its own block):

```
# Deliberate exceptions — proper nouns, not translatable UI text (mirrors
# settings_page.dart's precedent from the 9-file migration project). A
# language's own name, and its native self-name, don't change based on
# the current UI locale.
lib/presentation/pages/settings/language_settings_page.dart::'Тоҷикӣ'
lib/presentation/pages/settings/language_settings_page.dart::'Ўзбекча'
lib/presentation/pages/settings/language_settings_page.dart::'Русский'
lib/presentation/pages/settings/language_settings_page.dart::'Русский язык'
lib/presentation/pages/settings/language_settings_page.dart::'Забони тоҷикӣ'
```
(Confirm the exact quoted forms via `dart run tool/check_i18n.dart 2>&1 | grep language_settings_page.dart` after Step 4 below — the native-name pair may not even attempt to surface given the tool's one-match-per-line limit, in which case those two lines are optional documentation-only additions, not required for the lint to pass; still worth adding so a future regex fix doesn't flag them as "new".)

- [ ] **Step 2: Check for reusable existing keys**

Run: `grep -n '"save":' lib/l10n/app_ru.arb`
Expected: `save: "Сохранить"` — reuse for line 200.

- [ ] **Step 3: New keys for `app_ru.arb`**

```json
  "languageSettingsPageTitle": "Язык интерфейса",
  "languageSettingsChooseLabel": "Выберите язык",
  "languageSettingsRestartNotice": "Для применения языка перезапустите приложение.",
```

- [ ] **Step 4: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 5: Replace literals in `language_settings_page.dart`**

| Find | Replace with |
|---|---|
| `title: const Text('Язык интерфейса'),` | `title: Text(l10n.languageSettingsPageTitle),` |
| `Text('Выберите язык',` | `Text(l10n.languageSettingsChooseLabel,` |
| `'Для применения языка перезапустите приложение.',` | `l10n.languageSettingsRestartNotice,` |
| `: const Text('Сохранить',` | `: Text(l10n.save,` |

Leave the `_Language('ru', 'Русский', 'Русский язык', '🇷🇺')` / `_languages` list untouched (Step 1's deliberate exceptions).

- [ ] **Step 6: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep -E 'edit_profile_page.dart|telegram_bot_settings_page.dart|language_settings_page.dart'` — expect only (at most) the two optional native-name documentation lines to be absent from output; the 3 counted proper nouns must produce zero output since they're allow-listed.
Run: `flutter analyze` — expect clean.
Run: `find test -iname '*edit_profile*' -o -iname '*telegram_bot_settings*' -o -iname '*language_settings*'` then `flutter test <paths found> --reporter expanded` if any exist.

- [ ] **Step 7: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json tool/i18n-allowlist.txt \
  lib/presentation/pages/settings/edit_profile_page.dart \
  lib/presentation/pages/settings/telegram_bot_settings_page.dart \
  lib/presentation/pages/settings/language_settings_page.dart
git commit -m "fix(app): migrate settings misc B (profile/telegram/language) hardcoded strings to AppLocalizations"
```

---

### Task 21: Migrate Product misc (`categories_page.dart`, `add_product_step3_page.dart`, `add_product_step1_page.dart`)

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/product/categories_page.dart`
- Modify: `lib/presentation/pages/product/add_product_step3_page.dart`
- Modify: `lib/presentation/pages/product/add_product_step1_page.dart`

This task migrates all 40 counted offenders across these 3 files in one commit. `categories_page.dart`, `add_product_step3_page.dart`, and `add_product_step1_page.dart` all already declare `final l10n = AppLocalizations.of(context)!;` inside `build()` — reuse that binding.

**Major shared reuse:** `add_product_step1_page.dart` and `add_product_step3_page.dart` are two steps of the same wizard and both render the same 3 step-indicator labels ("Основное" / "Цены" / "Склад"). `app_ru.arb` already holds these from a previously-migrated step 2 (`addProductStepBasic`, `addProductStepPrices`, `addProductStepStock`), plus `addProduct` ("Добавить товар"), `editProduct` ("Редактировать товар"), and `newProductTitle` ("Новый товар") — all exact matches. Reuse all six across both files rather than minting duplicates.

#### `categories_page.dart` (14 offenders)

Current offenders (verbatim):
```
27:    if (count == 1) return 'товар';
28:    if (count >= 2 && count <= 4) return 'товара';
29:    return 'товаров';
41:        title: Text(isEditing ? 'Редактировать категорию' : 'Новая категория'),
46:            labelText: 'Название',
55:            child: const Text('Отмена'),
77:            child: Text(isEditing ? 'Сохранить' : 'Создать'),
88:        title: const Text('Удалить категорию?'),
89:        content: Text('Вы уверены, что хотите удалить "$name"?'),
93:            child: const Text('Отмена'),
104:            child: const Text('Удалить',
117:        title: const Text('Категории'),
141:                title: 'Нет категорий',
142:                subtitle: 'Создайте первую категорию для ваших товаров',
143:                buttonText: 'Создать категорию',
```
Note: `'Новая категория'` (line 41, second ternary branch) and `'Создать'` (line 77, second ternary branch) are **bonus** — same-line, missed by the lint tool.

`_pluralizeProducts(int count)` (lines 26-30) is a plain method on the `CategoriesPage` `StatelessWidget` with no `BuildContext` — it's called from `build()` at `Text('${category.productCount} ${_pluralizeProducts(category.productCount)}')`. Change its signature to accept the resolved `l10n` (or `BuildContext`) so it can return localized forms: `String _pluralizeProducts(AppLocalizations l10n, int count)`, and update the call site to `_pluralizeProducts(l10n, category.productCount)`.

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"itemName"\|"cancel":\|"save":\|"create":\|"delete":' lib/l10n/app_ru.arb`
Expected all exist:
- `itemName`: `"Название"` — this is the file's own documented generic bare-name key ("reused across category/supplier/investment/discount name fields" per its `@itemName` description) — exact match for line 46, reuse it.
- `cancel`: `"Отмена"` — reuse for both dialog-cancel occurrences (lines 55 and 93).
- `save`: `"Сохранить"` (line 77, first branch).
- `create`: `"Создать"` (line 77, bonus second branch).
- `delete`: `"Удалить"` (line 104).

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "categoriesPageTitle": "Категории",
  "categoriesEditTitle": "Редактировать категорию",
  "categoriesNewTitle": "Новая категория",
  "@categoriesNewTitle": { "description": "Add-category dialog title's default (non-editing) branch — shares a line with categoriesEditTitle in a ternary, missed by the lint tool's one-match-per-line scan" },
  "categoriesEmptyTitle": "Нет категорий",
  "categoriesEmptySubtitle": "Создайте первую категорию для ваших товаров",
  "categoriesEmptyButton": "Создать категорию",
  "categoriesDeleteTitle": "Удалить категорию?",
  "categoriesDeleteConfirmBody": "Вы уверены, что хотите удалить \"{name}\"?",
  "@categoriesDeleteConfirmBody": { "description": "Delete-category confirmation body — same shape as discountsDeleteConfirmBody (a different, already-shipped feature-prefixed key with identical value pattern), kept separate rather than renaming that existing key to something generic, per the 'no unrelated refactoring' rule", "placeholders": { "name": { "type": "String" } } },
  "productCountOne": "товар",
  "@productCountOne": { "description": "Russian noun form of 'product' used after a count ending in 1 (e.g. '1 товар') — plain String per this file's no-ICU-plural convention, not a plural rule" },
  "productCountFew": "товара",
  "@productCountFew": { "description": "Russian noun form of 'product' used after a count of 2-4 (e.g. '3 товара')" },
  "productCountMany": "товаров",
  "@productCountMany": { "description": "Russian noun form of 'product' used after a count of 0, 5+, or 11-14 (e.g. '10 товаров')" },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `categories_page.dart`**

| Find | Replace with |
|---|---|
| `if (count == 1) return 'товар';` | `if (count == 1) return l10n.productCountOne;` |
| `if (count >= 2 && count <= 4) return 'товара';` | `if (count >= 2 && count <= 4) return l10n.productCountFew;` |
| `return 'товаров';` | `return l10n.productCountMany;` |
| `title: Text(isEditing ? 'Редактировать категорию' : 'Новая категория'),` | `title: Text(isEditing ? AppLocalizations.of(ctx)!.categoriesEditTitle : AppLocalizations.of(ctx)!.categoriesNewTitle),` |
| `labelText: 'Название',` | `labelText: AppLocalizations.of(ctx)!.itemName,` |
| `child: const Text('Отмена'),` (in `_showCategoryDialog`) | `child: Text(AppLocalizations.of(ctx)!.cancel),` |
| `child: Text(isEditing ? 'Сохранить' : 'Создать'),` | `child: Text(isEditing ? AppLocalizations.of(ctx)!.save : AppLocalizations.of(ctx)!.create),` |
| `title: const Text('Удалить категорию?'),` | `title: Text(AppLocalizations.of(ctx)!.categoriesDeleteTitle),` |
| `content: Text('Вы уверены, что хотите удалить "$name"?'),` | `content: Text(AppLocalizations.of(ctx)!.categoriesDeleteConfirmBody(name)),` |
| `child: const Text('Отмена'),` (in `_confirmDelete`) | `child: Text(AppLocalizations.of(ctx)!.cancel),` |
| `child: const Text('Удалить',` | `child: Text(AppLocalizations.of(ctx)!.delete,` |
| `title: const Text('Категории'),` | `title: Text(l10n.categoriesPageTitle),` |
| `title: 'Нет категорий',` | `title: l10n.categoriesEmptyTitle,` |
| `subtitle: 'Создайте первую категорию для ваших товаров',` | `subtitle: l10n.categoriesEmptySubtitle,` |
| `buttonText: 'Создать категорию',` | `buttonText: l10n.categoriesEmptyButton,` |
| `Text('${category.productCount} ${_pluralizeProducts(category.productCount)}',` | `Text('${category.productCount} ${_pluralizeProducts(l10n, category.productCount)}',` |
| `String _pluralizeProducts(int count) {` | `String _pluralizeProducts(AppLocalizations l10n, int count) {` |

Both `_showCategoryDialog` and `_confirmDelete` receive the outer `context` as a parameter and open their own `builder: (ctx) => AlertDialog(...)` — use `AppLocalizations.of(ctx)!` (the dialog's own context) for everything inside those `AlertDialog` widgets, matching the file's existing scoping style; use the outer `l10n` only in `build()` itself.

#### `add_product_step3_page.dart` (13 offenders)

Current offenders (verbatim):
```
80:        title: const Text('Новый товар'),
91:              'Товар сохранён. Синхронизация в фоне.',
124:                  _StepDot(index: 1, label: 'Основное', isCompleted: true),
126:                  _StepDot(index: 2, label: 'Цены', isCompleted: true),
128:                  _StepDot(index: 3, label: 'Склад', isActive: true),
142:                        label: 'Начальное количество *',
150:                          if (v == null || v.trim().isEmpty) return 'Введите количество';
157:                        label: 'Минимальный остаток',
174:                              labelText: 'Поставщик',
193:                      const Text('Фото товара',
223:                                    Text('Нажмите для загрузки',
242:                      text: 'Назад',
253:                      text: 'Добавить товар',
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"newProductTitle"\|"addProductStepBasic"\|"addProductStepPrices"\|"addProductStepStock"\|"supplier":\|"back":\|"addProduct":' lib/l10n/app_ru.arb`
Expected all exist with exact matching values — reuse:
- `newProductTitle`: `"Новый товар"` (line 80)
- `addProductStepBasic`: `"Основное"` (line 124)
- `addProductStepPrices`: `"Цены"` (line 126)
- `addProductStepStock`: `"Склад"` (line 128)
- `supplier`: `"Поставщик"` (line 174)
- `back`: `"Назад"` (line 242)
- `addProduct`: `"Добавить товар"` (line 253)

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "addProductSavedSyncingMessage": "Товар сохранён. Синхронизация в фоне.",
  "addProductInitialQuantityLabel": "Начальное количество *",
  "addProductQuantityRequiredError": "Введите количество",
  "addProductMinStockLabel": "Минимальный остаток",
  "addProductPhotoSectionLabel": "Фото товара",
  "addProductTapToUploadHint": "Нажмите для загрузки",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `add_product_step3_page.dart`**

| Find | Replace with |
|---|---|
| `title: const Text('Новый товар'),` | `title: Text(l10n.newProductTitle),` |
| `'Товар сохранён. Синхронизация в фоне.',` | `l10n.addProductSavedSyncingMessage,` |
| `_StepDot(index: 1, label: 'Основное', isCompleted: true),` | `_StepDot(index: 1, label: l10n.addProductStepBasic, isCompleted: true),` |
| `_StepDot(index: 2, label: 'Цены', isCompleted: true),` | `_StepDot(index: 2, label: l10n.addProductStepPrices, isCompleted: true),` |
| `_StepDot(index: 3, label: 'Склад', isActive: true),` | `_StepDot(index: 3, label: l10n.addProductStepStock, isActive: true),` |
| `label: 'Начальное количество *',` | `label: l10n.addProductInitialQuantityLabel,` |
| `if (v == null || v.trim().isEmpty) return 'Введите количество';` | `if (v == null || v.trim().isEmpty) return l10n.addProductQuantityRequiredError;` |
| `label: 'Минимальный остаток',` | `label: l10n.addProductMinStockLabel,` |
| `labelText: 'Поставщик',` | `labelText: l10n.supplier,` |
| `const Text('Фото товара',` | `Text(l10n.addProductPhotoSectionLabel,` |
| `Text('Нажмите для загрузки',` | `Text(l10n.addProductTapToUploadHint,` |
| `text: 'Назад',` | `text: l10n.back,` |
| `text: 'Добавить товар',` | `text: l10n.addProduct,` |

#### `add_product_step1_page.dart` (13 offenders)

Current offenders (verbatim):
```
135:        title: Text(_isEditing ? 'Редактировать товар' : 'Новый товар'),
150:                  _StepDot(index: 1, label: 'Основное', isActive: true),
152:                  _StepDot(index: 2, label: 'Цены', isActive: false),
154:                  _StepDot(index: 3, label: 'Склад', isActive: false),
202:                                    Text('Добавить фото',
209:                                    Text('JPG, PNG до 5MB',
219:                        label: 'Название товара *',
222:                          if (v == null || v.trim().isEmpty) return 'Введите название';
229:                        label: 'Артикул (SKU)',
235:                        label: 'Штрихкод',
252:                              labelText: 'Категория',
273:                        label: 'Описание',
285:                text: 'Далее',
```
Note: `'Новый товар'` (line 135, second ternary branch) is **bonus** — same-line as the counted `'Редактировать товар'`, but has an exact reusable key already (`newProductTitle`, confirmed in Task 21's `add_product_step3_page.dart` section above).

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"editProduct":\|"newProductTitle"\|"addProductStepBasic"\|"addProductStepPrices"\|"addProductStepStock"\|"next":\|"category":\|"description":\|"barcode":\|"createStoreNameRequiredError"' lib/l10n/app_ru.arb`
Expected all exist with exact matching values — reuse:
- `editProduct`: `"Редактировать товар"` (line 135, first branch)
- `newProductTitle`: `"Новый товар"` (line 135, bonus second branch — same key as `add_product_step3_page.dart` above)
- `addProductStepBasic` / `addProductStepPrices` / `addProductStepStock`: lines 150/152/154 (same shared keys as `add_product_step3_page.dart` above)
- `next`: `"Далее"` (line 285)
- `category`: `"Категория"` (line 252)
- `description`: `"Описание"` (line 273)
- `barcode`: `"Штрихкод"` (line 235)
- `createStoreNameRequiredError`: `"Введите название"` (line 222) — **verify the value matches exactly** before using: this key's Russian text is generic ("Enter the name") even though its key name and `@description` say "store name field"; that description exists to distinguish it from `enterName` ("Введите имя", a *person's* name), not to restrict its reuse to stores. Reusing it here for the product-name validator is a meaning-match per `.claude/rules/mobile-l10n.md`'s "discriminator is meaning, not render location" rule — renaming the key itself is out of scope (it's used elsewhere already, shipped in a prior project).

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "addProductNameRequiredLabel": "Название товара *",
  "addProductSkuLabel": "Артикул (SKU)",
  "@addProductSkuLabel": { "description": "SKU field label including the parenthetical hint — distinct from the bare `sku` key (\"Артикул\")" },
  "addPhotoLabel": "Добавить фото",
  "addProductImageSizeHint": "JPG, PNG до 5MB",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `add_product_step1_page.dart`**

| Find | Replace with |
|---|---|
| `title: Text(_isEditing ? 'Редактировать товар' : 'Новый товар'),` | `title: Text(_isEditing ? l10n.editProduct : l10n.newProductTitle),` |
| `_StepDot(index: 1, label: 'Основное', isActive: true),` | `_StepDot(index: 1, label: l10n.addProductStepBasic, isActive: true),` |
| `_StepDot(index: 2, label: 'Цены', isActive: false),` | `_StepDot(index: 2, label: l10n.addProductStepPrices, isActive: false),` |
| `_StepDot(index: 3, label: 'Склад', isActive: false),` | `_StepDot(index: 3, label: l10n.addProductStepStock, isActive: false),` |
| `Text('Добавить фото',` | `Text(l10n.addPhotoLabel,` |
| `Text('JPG, PNG до 5MB',` | `Text(l10n.addProductImageSizeHint,` |
| `label: 'Название товара *',` | `label: l10n.addProductNameRequiredLabel,` |
| `if (v == null || v.trim().isEmpty) return 'Введите название';` | `if (v == null || v.trim().isEmpty) return l10n.createStoreNameRequiredError;` |
| `label: 'Артикул (SKU)',` | `label: l10n.addProductSkuLabel,` |
| `label: 'Штрихкод',` | `label: l10n.barcode,` |
| `labelText: 'Категория',` | `labelText: l10n.category,` |
| `label: 'Описание',` | `label: l10n.description,` |
| `text: 'Далее',` | `text: l10n.next,` |

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep -E 'categories_page.dart|add_product_step3_page.dart|add_product_step1_page.dart'` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `find test -iname '*categories_page*' -o -iname '*add_product_step3*' -o -iname '*add_product_step1*'` then `flutter test <paths found> --reporter expanded` if any exist.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json \
  lib/presentation/pages/product/categories_page.dart \
  lib/presentation/pages/product/add_product_step3_page.dart \
  lib/presentation/pages/product/add_product_step1_page.dart
git commit -m "fix(app): migrate product misc (categories/add-product steps 1&3) hardcoded strings to AppLocalizations"
```

---

### Task 22: Migrate Staff misc (`permission_toggle_row.dart`, `staff_detail_page.dart`, `staff_list_page.dart`, `staff_card.dart`)

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/widgets/staff/permission_toggle_row.dart`
- Modify: `lib/presentation/pages/staff/staff_detail_page.dart`
- Modify: `lib/presentation/pages/staff/staff_list_page.dart`
- Modify: `lib/presentation/widgets/staff/staff_card.dart`
- Modify: `lib/presentation/pages/roles/roles_page.dart` (one-line companion fix — see `permission_toggle_row.dart` section; `roles_page.dart` itself has zero Cyrillic offenders and is not otherwise part of this task)

This task migrates all 43 counted offenders across these 4 files in one commit.

**Shared reuse inside this bundle:** all four role-label switches (`edit_profile_page.dart`'s from Task 20 aside) map `OWNER`/`ADMIN`/`CASHIER`/`WAREHOUSE` to `'Владелец'`/`'Админ'`/`'Кассир'`/`'Складовщик'` — `app_ru.arb` already has exact-match keys `owner`, `adminRoleShort`, `cashier`, `warehouse` for all four. Reuse across `staff_detail_page.dart` and `staff_card.dart` (both use the short/detailed forms identically). `staff_list_page.dart`'s own switch differs for two roles (see its section below) and needs its own additional keys for those two.

Also shared: `staff_detail_page.dart` (line 173) and `staff_list_page.dart` (line 198) both render an on-shift-status ternary whose first branch is `'На смене'` — mint **one** new key `staffOnShiftStatus` and reuse it in both files (their *second* branches differ in wording — `'Нет смены'` vs `'Не на смене'` — so those stay as two separate keys).

#### `permission_toggle_row.dart` (14 offenders)

Current offenders (verbatim):
```
27:        return 'Управление товарами';
29:        return 'Продажи';
31:        return 'Возвраты';
33:        return 'Просмотр отчётов';
35:        return 'Управление персоналом';
37:        return 'Управление расходами';
39:        return 'Управление покупателями';
41:        return 'Управление поставщиками';
43:        return 'Управление складом';
45:        return 'Управление долгами';
47:        return 'Настройки магазина';
49:        return 'Открытие/закрытие смены';
51:        return 'Применение скидок';
53:        return 'Управление зарплатой';
```

This is a `static String permissionLabel(String key)` method with no `BuildContext` parameter, called from `lib/presentation/pages/roles/roles_page.dart:167` as `PermissionToggleRow.permissionLabel(perm)` inside an `itemBuilder: (context, index) { ... }` closure that already has a `context` in scope. Change the method signature to accept `BuildContext` and update both the definition and its one call site.

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"manageProducts"\|"sales":\|"returns":\|"viewReports"\|"manageStaff"\|"manageCustomers"' lib/l10n/app_ru.arb`
Expected:
- `manageProducts`: `"Управление товарами"` — exact match (line 27), reuse.
- `sales`: `"Продажи"` — exact match (line 29), reuse.
- `returns`: `"Возвраты"` — exact match (line 31), reuse.
- `viewReports`: `"Просмотр отчётов"` — exact match (line 33), reuse.
- `manageStaff`: `"Управление сотрудниками"` — **does NOT match** line 35's `"Управление персоналом"` (different word choice) — do not reuse, mint a new key.
- `manageCustomers`: `"Управление клиентами"` — **does NOT match** line 39's `"Управление покупателями"` (клиентами vs покупателями) — do not reuse, mint a new key.

The remaining 8 cases (lines 37, 41, 43, 45, 47, 49, 51, 53) have no existing match anywhere in `app_ru.arb` — mint new keys for all of them.

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "permissionManageStaffLabel": "Управление персоналом",
  "@permissionManageStaffLabel": { "description": "Staff-permissions checklist row label — distinct from `manageStaff` (\"Управление сотрудниками\"), different wording used elsewhere for the same underlying permission" },
  "permissionManageExpensesLabel": "Управление расходами",
  "permissionManageCustomersLabel": "Управление покупателями",
  "@permissionManageCustomersLabel": { "description": "Staff-permissions checklist row label — distinct from `manageCustomers` (\"Управление клиентами\"), different wording used elsewhere for the same underlying permission" },
  "permissionManageSuppliersLabel": "Управление поставщиками",
  "permissionManageStockLabel": "Управление складом",
  "permissionManageDebtsLabel": "Управление долгами",
  "permissionManageSettingsLabel": "Настройки магазина",
  "permissionOpenCloseShiftLabel": "Открытие/закрытие смены",
  "permissionApplyDiscountsLabel": "Применение скидок",
  "permissionManagePayrollLabel": "Управление зарплатой",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

In `permission_toggle_row.dart`, add `import 'package:dukonpro/l10n/app_localizations.dart';` and change:

| Find | Replace with |
|---|---|
| `static String permissionLabel(String key) {` | `static String permissionLabel(BuildContext context, String key) {` |
| (first line inside the switch body) | add `final l10n = AppLocalizations.of(context)!;` |
| `return 'Управление товарами';` | `return l10n.manageProducts;` |
| `return 'Продажи';` | `return l10n.sales;` |
| `return 'Возвраты';` | `return l10n.returns;` |
| `return 'Просмотр отчётов';` | `return l10n.viewReports;` |
| `return 'Управление персоналом';` | `return l10n.permissionManageStaffLabel;` |
| `return 'Управление расходами';` | `return l10n.permissionManageExpensesLabel;` |
| `return 'Управление покупателями';` | `return l10n.permissionManageCustomersLabel;` |
| `return 'Управление поставщиками';` | `return l10n.permissionManageSuppliersLabel;` |
| `return 'Управление складом';` | `return l10n.permissionManageStockLabel;` |
| `return 'Управление долгами';` | `return l10n.permissionManageDebtsLabel;` |
| `return 'Настройки магазина';` | `return l10n.permissionManageSettingsLabel;` |
| `return 'Открытие/закрытие смены';` | `return l10n.permissionOpenCloseShiftLabel;` |
| `return 'Применение скидок';` | `return l10n.permissionApplyDiscountsLabel;` |
| `return 'Управление зарплатой';` | `return l10n.permissionManagePayrollLabel;` |

In `lib/presentation/pages/roles/roles_page.dart` (companion compile fix, required since the static method's signature changed — this file has no Cyrillic offenders of its own and is not part of any other task):

| Find | Replace with |
|---|---|
| `label: PermissionToggleRow.permissionLabel(perm),` | `label: PermissionToggleRow.permissionLabel(context, perm),` |

(The surrounding `itemBuilder: (context, index) { ... }` already provides `context` — no other changes needed in `roles_page.dart`.)

#### `staff_detail_page.dart` (14 offenders)

Current offenders (verbatim):
```
44:        return 'Владелец';
46:        return 'Админ';
48:        return 'Кассир';
50:        return 'Складовщик';
76:        title: const Text('Профиль сотрудника'),
164:                          _InfoColumn(
                              label: 'Оклад',
168:                          _InfoColumn(
                              label: 'Комиссия',
172:                          _InfoColumn(
                              label: 'Статус',
173:                            value: member.isOnShift ? 'На смене' : 'Нет смены',
187:                    Tab(text: 'Смены'),
188:                    Tab(text: 'Статистика'),
251:              child: Text('Нет смен', style: TextStyle(color: context.textSecondary, fontSize: 16)),
283:          _StatRow(label: 'Продажи сегодня', ...
285:          _StatRow(label: 'Дата регистрации', ...
```
Note: `'Нет смены'` (line 173, second ternary branch) is **bonus**, same-line as the counted `'На смене'`.

`_roleLabel(String role)` (lines 41-54) is an instance method of `_StaffDetailPageState`, a `State` subclass — it has the inherited `context` getter available directly, no parameter threading needed. `TabBar`'s `tabs: const [Tab(text: 'Смены'), Tab(text: 'Статистика')]` (lines 186-189) must drop the `const` since the new values aren't compile-time constants.

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"owner":\|"adminRoleShort"\|"cashier":\|"warehouse":\|"employeeDetail"\|"commission":\|"baseSalary"\|"shifts":\|"noShifts"\|"todaySales"' lib/l10n/app_ru.arb`
Expected:
- `owner`: `"Владелец"`, `adminRoleShort`: `"Админ"`, `cashier`: `"Кассир"`, `warehouse`: `"Складовщик"` — all exact matches (lines 44/46/48/50), reuse.
- `employeeDetail`: `"Профиль сотрудника"` — exact match (line 76), reuse.
- `commission`: `"Комиссия"` — exact match (line 168), reuse.
- `baseSalary`: `"Оклад"` — exact match (line 164), reuse.
- `shifts`: `"Смены"` — exact match (line 187), reuse.
- `noShifts`: `"Нет смен"` — exact match (line 251), reuse.
- `todaySales`: `"Продажи за сегодня"` — **does NOT match** line 283's `"Продажи сегодня"` (missing "за") — do not reuse, mint a new key. This is exactly the kind of near-miss the design spec's mandatory reuse-verification step exists to catch.

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "staffOnShiftStatus": "На смене",
  "@staffOnShiftStatus": { "description": "Staff on-shift status indicator — shared verbatim between staff_detail_page.dart and staff_list_page.dart" },
  "staffNotOnShiftStatusDetail": "Нет смены",
  "@staffNotOnShiftStatusDetail": { "description": "Staff detail page's not-on-shift status text — distinct wording from staff_list_page.dart's staffListNotOnShiftStatus (\"Не на смене\")" },
  "staffStatusLabel": "Статус",
  "staffTodaySalesLabel": "Продажи сегодня",
  "@staffTodaySalesLabel": { "description": "Staff detail stats-tab label — distinct from `todaySales` (\"Продажи за сегодня\"), different wording used elsewhere" },
  "staffStatsTabLabel": "Статистика",
  "staffRegistrationDateLabel": "Дата регистрации",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `staff_detail_page.dart`**

| Find | Replace with |
|---|---|
| `return 'Владелец';` | `return AppLocalizations.of(context)!.owner;` |
| `return 'Админ';` | `return AppLocalizations.of(context)!.adminRoleShort;` |
| `return 'Кассир';` | `return AppLocalizations.of(context)!.cashier;` |
| `return 'Складовщик';` | `return AppLocalizations.of(context)!.warehouse;` |
| `title: const Text('Профиль сотрудника'),` | `title: Text(l10n.employeeDetail),` |
| `label: 'Оклад',` | `label: l10n.baseSalary,` |
| `label: 'Комиссия',` | `label: l10n.commission,` |
| `label: 'Статус',` | `label: l10n.staffStatusLabel,` |
| `value: member.isOnShift ? 'На смене' : 'Нет смены',` | `value: member.isOnShift ? l10n.staffOnShiftStatus : l10n.staffNotOnShiftStatusDetail,` |
| `Tab(text: 'Смены'),` | `Tab(text: l10n.shifts),` |
| `Tab(text: 'Статистика'),` | `Tab(text: l10n.staffStatsTabLabel),` |
| `tabs: const [` (the two `Tab(...)` lines above) | `tabs: [` (drop `const`) |
| `child: Text('Нет смен', style: TextStyle(color: context.textSecondary, fontSize: 16)),` | `child: Text(AppLocalizations.of(context)!.noShifts, style: TextStyle(color: context.textSecondary, fontSize: 16)),` (this is inside `_ShiftsTab`, its own `StatelessWidget` with its own `build(BuildContext context)` — use that widget's own `context`) |
| `_StatRow(label: 'Продажи сегодня', ...)` | `_StatRow(label: AppLocalizations.of(context)!.staffTodaySalesLabel, ...)` (inside `_StatsTab`'s own `build(BuildContext context)`) |
| `_StatRow(label: 'Дата регистрации', ...)` | `_StatRow(label: AppLocalizations.of(context)!.staffRegistrationDateLabel, ...)` |

#### `staff_list_page.dart` (10 offenders)

Current offenders (verbatim):
```
65:      case 'ADMIN': return 'Администратор';
66:      case 'CASHIER': return 'Кассир';
67:      case 'WAREHOUSE': return 'Склад';
68:      case 'OWNER': return 'Владелец';
92:                  const Text('Сотрудники',
121:                        title: 'Сотрудников пока нет',
122:                        subtitle: 'Добавьте сотрудников для учёта смен и зарплаты',
123:                        buttonText: 'Добавить сотрудника',
198:                                              isOnShift ? 'На смене' : 'Не на смене',
207:                                                'Сегодня: ${_formatPrice(staff.todaySales!)}',
```
Note: `'Не на смене'` (line 198, second ternary branch) is **bonus**.

`_roleLabel`/`_roleBadgeColor` (lines 54-71) are instance methods of `_StaffListPageState`, a `State` subclass — the inherited `context` getter is available directly, no threading needed.

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"admin":\|"cashier":\|"owner":\|"addEmployee"' lib/l10n/app_ru.arb`
Expected:
- `admin`: `"Администратор"` — exact match (line 65), reuse.
- `cashier`: `"Кассир"` — exact match (line 66), reuse.
- `owner`: `"Владелец"` — exact match (line 68), reuse.
- `addEmployee`: `"Добавить сотрудника"` — exact match (line 123), reuse.

Line 67's `"Склад"` does **not** match the existing `warehouse` key (`"Складовщик"`, a different word — see Task 21's `add_product_step*` reuse of `addProductStepStock`, also `"Склад"` but a different meaning again) — mint a distinct new key.

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "staffRoleWarehouseShort": "Склад",
  "@staffRoleWarehouseShort": { "description": "Short-form warehouse-role badge label used in the staff list — distinct from `warehouse` (\"Складовщик\", the fuller staff-role label used on the staff detail page/card) and from `addProductStepStock` (same Russian word \"Склад\" but meaning the add-product wizard's stock/inventory step, an unrelated homograph)" },
  "staffListPageTitle": "Сотрудники",
  "staffListEmptyTitle": "Сотрудников пока нет",
  "staffListEmptySubtitle": "Добавьте сотрудников для учёта смен и зарплаты",
  "staffListNotOnShiftStatus": "Не на смене",
  "@staffListNotOnShiftStatus": { "description": "Staff list's not-on-shift status text — distinct wording from staff_detail_page.dart's staffNotOnShiftStatusDetail (\"Нет смены\")" },
  "staffListTodaySalesLine": "Сегодня: {amount}",
  "@staffListTodaySalesLine": { "placeholders": { "amount": { "type": "String" } } },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `staff_list_page.dart`**

| Find | Replace with |
|---|---|
| `case 'ADMIN': return 'Администратор';` | `case 'ADMIN': return AppLocalizations.of(context)!.admin;` |
| `case 'CASHIER': return 'Кассир';` | `case 'CASHIER': return AppLocalizations.of(context)!.cashier;` |
| `case 'WAREHOUSE': return 'Склад';` | `case 'WAREHOUSE': return AppLocalizations.of(context)!.staffRoleWarehouseShort;` |
| `case 'OWNER': return 'Владелец';` | `case 'OWNER': return AppLocalizations.of(context)!.owner;` |
| `const Text('Сотрудники',` | `Text(l10n.staffListPageTitle,` |
| `title: 'Сотрудников пока нет',` | `title: l10n.staffListEmptyTitle,` |
| `subtitle: 'Добавьте сотрудников для учёта смен и зарплаты',` | `subtitle: l10n.staffListEmptySubtitle,` |
| `buttonText: 'Добавить сотрудника',` | `buttonText: l10n.addEmployee,` |
| `isOnShift ? 'На смене' : 'Не на смене',` | `isOnShift ? l10n.staffOnShiftStatus : l10n.staffListNotOnShiftStatus,` |
| `'Сегодня: ${_formatPrice(staff.todaySales!)}',` | `l10n.staffListTodaySalesLine(_formatPrice(staff.todaySales!)),` |

`staffOnShiftStatus` here is the same key minted in `staff_detail_page.dart`'s section above — make sure this file's `flutter gen-l10n` run picks up the ARB addition from Step 2 of that section (both are edited in the same commit/ARB pass, so this is automatic — just don't duplicate the key definition).

#### `staff_card.dart` (5 offenders)

Current offenders (verbatim):
```
18:        return 'Владелец';
20:        return 'Админ';
22:        return 'Кассир';
24:        return 'Складовщик';
126:                  'сегодня',
```

`_roleLabel(String role)` (lines 15-28) is an instance method of `StaffCard`, a plain `StatelessWidget` (not a `State`) — it does **not** have an inherited `context`. It's called from `build(BuildContext context)` at line 47 as `_roleColor(context, staff.role)` (note: `_roleColor` already takes `context`) but `_roleLabel(staff.role)` at line 101 does not. Add a `BuildContext context` parameter to `_roleLabel` and update its one call site.

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"owner":\|"adminRoleShort"\|"cashier":\|"warehouse":\|"today":' lib/l10n/app_ru.arb`
Expected: `owner`/`adminRoleShort`/`cashier`/`warehouse` all exact matches (same as `staff_detail_page.dart` above) — reuse. `today`: `"Сегодня"` (capitalized) — **does NOT match** line 126's lowercase `'сегодня'` — do not reuse, mint a new key.

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "staffCardTodayLabel": "сегодня",
  "@staffCardTodayLabel": { "description": "Lowercase inline label under a staff card's today's-sales figure — distinct from the capitalized generic `today` (\"Сегодня\")" },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `staff_card.dart`**

| Find | Replace with |
|---|---|
| `String _roleLabel(String role) {` | `String _roleLabel(BuildContext context, String role) {` |
| `return 'Владелец';` | `return AppLocalizations.of(context)!.owner;` |
| `return 'Админ';` | `return AppLocalizations.of(context)!.adminRoleShort;` |
| `return 'Кассир';` | `return AppLocalizations.of(context)!.cashier;` |
| `return 'Складовщик';` | `return AppLocalizations.of(context)!.warehouse;` |
| `_roleLabel(staff.role),` | `_roleLabel(context, staff.role),` |
| `'сегодня',` | `AppLocalizations.of(context)!.staffCardTodayLabel,` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` at the top of the file (not currently imported).

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep -E 'permission_toggle_row.dart|staff_detail_page.dart|staff_list_page.dart|staff_card.dart'` — expect no output.
Run: `flutter analyze` — expect clean (pay particular attention to `roles_page.dart` compiling with the changed static-method signature).
Run: `find test -iname '*permission_toggle_row*' -o -iname '*staff_detail_page*' -o -iname '*staff_list_page*' -o -iname '*staff_card*' -o -iname '*roles_page*'` then `flutter test <paths found> --reporter expanded` if any exist.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json \
  lib/presentation/widgets/staff/permission_toggle_row.dart \
  lib/presentation/pages/staff/staff_detail_page.dart \
  lib/presentation/pages/staff/staff_list_page.dart \
  lib/presentation/widgets/staff/staff_card.dart \
  lib/presentation/pages/roles/roles_page.dart
git commit -m "fix(app): migrate staff misc (permissions/detail/list/card) hardcoded strings to AppLocalizations"
```

---

### Task 23: Migrate POS misc (`receipt_widget.dart`, `sale_success_page.dart`, `cash_payment_page.dart`, `receipt_preview_page.dart`)

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/widgets/pos/receipt_widget.dart`
- Modify: `lib/presentation/pages/pos/sale_success_page.dart`
- Modify: `lib/presentation/pages/pos/cash_payment_page.dart`
- Modify: `lib/presentation/pages/pos/receipt_preview_page.dart`

This task migrates all 27 counted offenders across these 4 files in one commit. `cash_payment_page.dart` and `receipt_preview_page.dart` already declare `final l10n = AppLocalizations.of(context)!;` inside `build()` — reuse that binding. `receipt_widget.dart` and `sale_success_page.dart` do not yet have one; add it.

**Major reuse discovery:** `receipt_widget.dart`'s row labels line up almost entirely with existing generic keys already used across the finance/reports screens: `payment` ("Оплата"), `paid` ("Оплачено"), `subtotal` ("Подытог"), `change` ("Сдача"), `discount` ("Скидка"), `amount` ("Сумма"), and `product` ("Товар") — all exact matches. Only the caps-lock `"ИТОГО"` (distinct from `total`: `"Итого"`, different case) and the abbreviated `"Кол."` column header need new keys.

#### `receipt_widget.dart` (10 offenders)

Current offenders (verbatim):
```
70:                  'Товар',
81:                  'Кол.',
94:                  'Сумма',
155:          _buildTotalRow(context, 'Подытог', Formatters.price(sale.subtotal)),
157:            _buildTotalRow(context, 'Скидка', '- ${Formatters.price(sale.discount)}'),
162:            'ИТОГО',
171:          _buildTotalRow(context, 'Оплата', sale.paymentType),
172:          _buildTotalRow(context, 'Оплачено', Formatters.price(sale.paidAmount)),
174:            _buildTotalRow(context, 'Сдача', Formatters.price(sale.change)),
178:            'Спасибо за покупку!',
```

`_buildTotalRow(BuildContext context, String label, String value, {...})` (line 191) already takes `context` as its first parameter — no signature changes needed, just replace the literal `label` arguments at each call site using a local `l10n` declared in `build()`.

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"product":\|"amount":\|"subtotal":\|"discount":\|"total":\|"payment":\|"paid":\|"change":' lib/l10n/app_ru.arb`
Expected all exist with exact matching values — reuse:
- `product`: `"Товар"` (line 70)
- `amount`: `"Сумма"` (line 94)
- `subtotal`: `"Подытог"` (line 155)
- `discount`: `"Скидка"` (line 157)
- `payment`: `"Оплата"` (line 171)
- `paid`: `"Оплачено"` (line 172)
- `change`: `"Сдача"` (line 174)

`total` is `"Итого"` (title case) — **does NOT match** line 162's `"ИТОГО"` (all caps) — do not reuse, mint a new key.

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "receiptQtyAbbrev": "Кол.",
  "receiptTotalCaps": "ИТОГО",
  "@receiptTotalCaps": { "description": "All-caps grand-total label on the printed/previewed receipt — distinct from `total` (\"Итого\", title case), used elsewhere" },
  "receiptThankYouMessage": "Спасибо за покупку!",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `receipt_widget.dart`**

Add `final l10n = AppLocalizations.of(context)!;` at the top of `build(BuildContext context)`.

| Find | Replace with |
|---|---|
| `'Товар',` | `l10n.product,` |
| `'Кол.',` | `l10n.receiptQtyAbbrev,` |
| `'Сумма',` | `l10n.amount,` |
| `_buildTotalRow(context, 'Подытог', Formatters.price(sale.subtotal)),` | `_buildTotalRow(context, l10n.subtotal, Formatters.price(sale.subtotal)),` |
| `_buildTotalRow(context, 'Скидка', '- ${Formatters.price(sale.discount)}'),` | `_buildTotalRow(context, l10n.discount, '- ${Formatters.price(sale.discount)}'),` |
| `'ИТОГО',` | `l10n.receiptTotalCaps,` |
| `_buildTotalRow(context, 'Оплата', sale.paymentType),` | `_buildTotalRow(context, l10n.payment, sale.paymentType),` |
| `_buildTotalRow(context, 'Оплачено', Formatters.price(sale.paidAmount)),` | `_buildTotalRow(context, l10n.paid, Formatters.price(sale.paidAmount)),` |
| `_buildTotalRow(context, 'Сдача', Formatters.price(sale.change)),` | `_buildTotalRow(context, l10n.change, Formatters.price(sale.change)),` |
| `'Спасибо за покупку!',` | `l10n.receiptThankYouMessage,` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` (not currently imported).

#### `sale_success_page.dart` (7 offenders)

Current offenders (verbatim):
```
120:              const Text('Продажа оформлена!',
127:                Text('Сдача: ${_formatPrice(sale.change)}',
144:                  label: const Text('Печатать чек',
162:                  label: const Text('Отправить в Telegram',
177:                  child: const Text('Новая продажа',
209:                Share.share('Чек #${sale.receiptNo}\nИтого: ${sale.total.toStringAsFixed(2)} сом.');
217:                Share.share('Чек #${sale.receiptNo}, Итого: ${sale.total.toStringAsFixed(2)} сом.');
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"newSale":\|"saleSuccess":\|"printReceipt":' lib/l10n/app_ru.arb`
Expected:
- `newSale`: `"Новая продажа"` — exact match (line 177), reuse.
- `saleSuccess`: `"Продажа оформлена"` (no exclamation mark) — **does NOT match** line 120's `"Продажа оформлена!"` — do not reuse, mint a new key. This is another exact instance of the reuse-verification trap the design spec warns about.
- `printReceipt`: `"Печать чека"` — **does NOT match** line 144's `"Печатать чек"` (different verb form) — do not reuse, mint a new key.

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "saleSuccessTitle": "Продажа оформлена!",
  "@saleSuccessTitle": { "description": "Sale-success screen's big headline — distinct from `saleSuccess` (\"Продажа оформлена\", no exclamation mark), used elsewhere (e.g. a snackbar)" },
  "saleSuccessChangeLine": "Сдача: {amount}",
  "@saleSuccessChangeLine": { "placeholders": { "amount": { "type": "String" } } },
  "saleSuccessPrintButton": "Печатать чек",
  "@saleSuccessPrintButton": { "description": "Sale-success screen's print button — distinct from `printReceipt` (\"Печать чека\", a noun-form label used elsewhere)" },
  "saleSuccessSendToTelegramButton": "Отправить в Telegram",
  "saleSuccessReceiptShareTextWhatsapp": "Чек #{receiptNo}\nИтого: {total} сом.",
  "@saleSuccessReceiptShareTextWhatsapp": { "description": "Share.share() text sent to WhatsApp — line-break separated; distinct from the SMS variant, which uses a comma separator instead", "placeholders": { "receiptNo": { "type": "String" }, "total": { "type": "String" } } },
  "saleSuccessReceiptShareTextSms": "Чек #{receiptNo}, Итого: {total} сом.",
  "@saleSuccessReceiptShareTextSms": { "description": "Share.share() text sent via SMS — comma separated; distinct from the WhatsApp variant, which uses a line break instead", "placeholders": { "receiptNo": { "type": "String" }, "total": { "type": "String" } } },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `sale_success_page.dart`**

Add `final l10n = AppLocalizations.of(context)!;` at the top of `build(BuildContext context)`. In `_showShareOptions(BuildContext context)`, add its own `final l10n = AppLocalizations.of(context)!;` too (it's a separate method, not nested inside `build`).

| Find | Replace with |
|---|---|
| `const Text('Продажа оформлена!',` | `Text(l10n.saleSuccessTitle,` |
| `Text('Сдача: ${_formatPrice(sale.change)}',` | `Text(l10n.saleSuccessChangeLine(_formatPrice(sale.change)),` |
| `label: const Text('Печатать чек',` | `label: Text(l10n.saleSuccessPrintButton,` |
| `label: const Text('Отправить в Telegram',` | `label: Text(l10n.saleSuccessSendToTelegramButton,` |
| `child: const Text('Новая продажа',` | `child: Text(l10n.newSale,` |
| `Share.share('Чек #${sale.receiptNo}\nИтого: ${sale.total.toStringAsFixed(2)} сом.');` | `Share.share(l10n.saleSuccessReceiptShareTextWhatsapp(sale.receiptNo.toString(), sale.total.toStringAsFixed(2)));` |
| `Share.share('Чек #${sale.receiptNo}, Итого: ${sale.total.toStringAsFixed(2)} сом.');` | `Share.share(l10n.saleSuccessReceiptShareTextSms(sale.receiptNo.toString(), sale.total.toStringAsFixed(2)));` |

(The `\n`-variant is the WhatsApp `ListTile`'s `onTap` at line 209; the comma-variant is the SMS `ListTile`'s `onTap` at line 217 — double-check you're matching the right one to the right `ListTile` when editing, since the two calls are visually similar.)

#### `cash_payment_page.dart` (7 offenders)

Current offenders (verbatim):
```
94:                          tooltip: 'Назад',
98:                        const Text('Оплата наличными',
119:                                Text('Сумма к оплате',
132:                            child: Text('Получено от клиента',
186:                                      child: const Text('Без сдачи',
209:                                  Text(change >= 0 ? 'Сдача' : 'Недостаточно',
246:                          isProcessing ? 'Обработка...' : 'Завершить и печатать чек',
```
Note: `'Недостаточно'` (line 209, second ternary branch) and `'Завершить и печатать чек'` (line 246, second ternary branch) are **bonus**, both same-line, missed by the lint tool.

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"back":\|"processing":\|"change":\|"a11yWithoutChange"' lib/l10n/app_ru.arb`
Expected:
- `back`: `"Назад"` — exact match (line 94), reuse.
- `processing`: `"Обработка..."` — exact match (line 246), reuse.
- `change`: `"Сдача"` — exact match (line 209, first branch; same key already reused in `receipt_widget.dart` above), reuse.
- `a11yWithoutChange`: `"Без сдачи"` — same value as line 186's visible button text, but that key is a `Semantics` `label:` (accessibility/tooltip role) already used at this file's own line 174 for the surrounding `Semantics` wrapper — per this codebase's established convention (e.g. `a11yShare` vs `share` kept as two separate keys despite identical values), keep the **visible** text on a separate key rather than reusing the a11y one.

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "cashPaymentPageTitle": "Оплата наличными",
  "cashPaymentAmountToPayLabel": "Сумма к оплате",
  "cashPaymentReceivedFromCustomerLabel": "Получено от клиента",
  "cashPaymentNoChangeButton": "Без сдачи",
  "@cashPaymentNoChangeButton": { "description": "Visible button label — same value as the `a11yWithoutChange` semantic label wrapping this same button, kept as a separate key per this codebase's a11y-vs-visible-text convention" },
  "cashPaymentInsufficientLabel": "Недостаточно",
  "cashPaymentCompleteButton": "Завершить и печатать чек",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `cash_payment_page.dart`**

| Find | Replace with |
|---|---|
| `tooltip: 'Назад',` | `tooltip: l10n.back,` |
| `const Text('Оплата наличными',` | `Text(l10n.cashPaymentPageTitle,` |
| `Text('Сумма к оплате',` | `Text(l10n.cashPaymentAmountToPayLabel,` |
| `child: Text('Получено от клиента',` | `child: Text(l10n.cashPaymentReceivedFromCustomerLabel,` |
| `child: const Text('Без сдачи',` | `child: Text(l10n.cashPaymentNoChangeButton,` |
| `Text(change >= 0 ? 'Сдача' : 'Недостаточно',` | `Text(change >= 0 ? l10n.change : l10n.cashPaymentInsufficientLabel,` |
| `isProcessing ? 'Обработка...' : 'Завершить и печатать чек',` | `isProcessing ? l10n.processing : l10n.cashPaymentCompleteButton,` |

#### `receipt_preview_page.dart` (3 offenders)

Current offenders (verbatim):
```
71:        title: const Text('Чек'),
102:                      text: 'Поделиться',
111:                      text: 'Печать',
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"receipt":\|"share":' lib/l10n/app_ru.arb`
Expected:
- `receipt`: `"Чек"` — exact match (line 71), reuse.
- `share`: `"Поделиться"` — exact match (line 102; distinct from `a11yShare`, a tooltip label used elsewhere in this same file at line 78 — this is the visible button text), reuse.

Line 111's bare `"Печать"` has no existing exact match (the closest, `printReceipt`, is `"Печать чека"`, a longer phrase) — mint a new key.

- [ ] **Step 2: New keys for `app_ru.arb`**

```json
  "receiptPreviewPrintButton": "Печать",
  "@receiptPreviewPrintButton": { "description": "Bare 'Print' button on the receipt preview screen — distinct from `printReceipt` (\"Печать чека\", a longer phrase used elsewhere)" },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals in `receipt_preview_page.dart`**

| Find | Replace with |
|---|---|
| `title: const Text('Чек'),` | `title: Text(l10n.receipt),` |
| `text: 'Поделиться',` | `text: l10n.share,` |
| `text: 'Печать',` | `text: l10n.receiptPreviewPrintButton,` |

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep -E 'receipt_widget.dart|sale_success_page.dart|cash_payment_page.dart|receipt_preview_page.dart'` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `find test -iname '*receipt_widget*' -o -iname '*sale_success_page*' -o -iname '*cash_payment_page*' -o -iname '*receipt_preview_page*'` then `flutter test <paths found> --reporter expanded` if any exist.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json \
  lib/presentation/widgets/pos/receipt_widget.dart \
  lib/presentation/pages/pos/sale_success_page.dart \
  lib/presentation/pages/pos/cash_payment_page.dart \
  lib/presentation/pages/pos/receipt_preview_page.dart
git commit -m "fix(app): migrate POS misc (receipt widget/sale success/cash payment/receipt preview) hardcoded strings to AppLocalizations"
```

---
### Task 24: Migrate Finance misc (`currencies_page.dart`, `expense_card.dart`, `investment_list_page.dart`, `period_selector.dart`, `profit_summary_card.dart`, `stat_summary_row.dart`)

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/finance/currencies_page.dart`
- Modify: `lib/presentation/widgets/finance/expense_card.dart`
- Modify: `lib/presentation/pages/finance/investment_list_page.dart`
- Modify: `lib/presentation/widgets/finance/period_selector.dart`
- Modify: `lib/presentation/widgets/finance/profit_summary_card.dart`
- Modify: `lib/presentation/widgets/finance/stat_summary_row.dart`

This task migrates all 34 offenders across these 6 files in one commit, since each is small individually.

#### `currencies_page.dart` (12 offenders)

Current offenders (verbatim):
```
38:      'USD': 'Доллар США',
39:      'RUB': 'Российский рубль',
40:      'EUR': 'Евро',
41:      'CNY': 'Китайский юань',
183:        title: const Text('Курсы валют'),
210:          TextButton(onPressed: _loadRates, child: const Text('Повторить')),
224:            'НБТ — Национальный банк Таджикистана',
341:            'Нет данных за 30 дней',
378:            'Динамика за 30 дней',
472:            'Конвертер',
488:                    labelText: 'Сумма',
520:            'Результат (в TJS):',
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"retry"\|"amount":' lib/l10n/app_ru.arb`
Expected: `retry: "Повторить"` and `amount: "Сумма"` already exist — reuse both. No existing key holds the 4 currency-label values, the page title, the two "no history"/"chart title" strings, the NBT bank-name line, or the converter-result label — run `grep -n 'Доллар США\|Российский рубль\|Курсы валют\|Конвертер\|НБТ — Национальный банк' lib/l10n/app_ru.arb` to confirm (expect no output), then mint new keys below.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

Add as a new contiguous block (no existing currency-feature block exists — add near `amount`/`day`/`week` or any other convenient finance-adjacent spot):

```json
  "currenciesPageTitle": "Курсы валют",
  "nbtBankLabel": "НБТ — Национальный банк Таджикистана",
  "currenciesHistoryChartTitle": "Динамика за 30 дней",
  "currenciesNoHistoryData": "Нет данных за 30 дней",
  "currenciesConverterTitle": "Конвертер",
  "currenciesConvertedResultLabel": "Результат (в TJS):",
  "currencyUsd": "Доллар США",
  "currencyRub": "Российский рубль",
  "currencyEur": "Евро",
  "currencyCny": "Китайский юань",
```

`currencyUsd`/`currencyRub`/`currencyEur`/`currencyCny` are deliberately unprefixed (not `currenciesUsd`) since they're generic currency-name labels plausibly reused anywhere a currency needs a human-readable name (e.g. a future pricing/subscription currency picker), per the reuse-discipline rule.

- [ ] **Step 3: Replace literals in `currencies_page.dart`**

**Important:** the `labels` map (lines 37-42) lives inside `_CurrencyRate.fromJson`, a `factory` constructor on a plain data class with no `BuildContext`. Rather than threading `BuildContext` through the model layer, restructure so the model only carries `code` and localization happens at render time (where `context` already exists, e.g. line 269's `context.textPrimary`):

1. In `_CurrencyRate`, delete the `label` field, delete it from the constructor and from `fromJson`'s body, and delete the `labels` const map entirely.
2. In `_CurrenciesPageState`, add:
   ```dart
   String _currencyLabel(BuildContext context, String code) {
     final l10n = AppLocalizations.of(context)!;
     switch (code) {
       case 'USD': return l10n.currencyUsd;
       case 'RUB': return l10n.currencyRub;
       case 'EUR': return l10n.currencyEur;
       case 'CNY': return l10n.currencyCny;
       default: return code;
     }
   }
   ```
3. At line 273 (`rate.label` inside `_buildCurrencyCard`, which already has `context` in scope), replace `rate.label` with `_currencyLabel(context, rate.code)`.

The `import 'package:dukonpro/l10n/app_localizations.dart';` at line 11 already exists — no new import needed.

| Find | Replace with |
|---|---|
| `title: const Text('Курсы валют'),` | `title: Text(AppLocalizations.of(context)!.currenciesPageTitle),` |
| `child: const Text('Повторить')` | `child: Text(AppLocalizations.of(context)!.retry)` |
| `'НБТ — Национальный банк Таджикистана',` | `AppLocalizations.of(context)!.nbtBankLabel,` |
| `'Нет данных за 30 дней',` | `AppLocalizations.of(context)!.currenciesNoHistoryData,` |
| `'Динамика за 30 дней',` | `AppLocalizations.of(context)!.currenciesHistoryChartTitle,` |
| `'Конвертер',` | `AppLocalizations.of(context)!.currenciesConverterTitle,` |
| `labelText: 'Сумма',` | `labelText: AppLocalizations.of(context)!.amount,` |
| `'Результат (в TJS):',` | `AppLocalizations.of(context)!.currenciesConvertedResultLabel,` |

`_buildError()`, `_buildContent()`, `_buildHistoryChart(code)` and `_buildConverter()` are all `State` methods, so `context` is available via the inherited getter at every one of these call sites without threading.

#### `expense_card.dart` (7 offenders)

Current offenders (verbatim):
```
17:      case 'PURCHASE': return 'Закупка';
18:      case 'RENT': return 'Аренда';
19:      case 'SALARY': return 'Зарплата';
20:      case 'UTILITIES': return 'Коммунальные';
21:      case 'TRANSPORT': return 'Транспорт';
22:      case 'MARKETING': return 'Маркетинг';
23:      default: return 'Другое';
```

- [ ] **Step 4: Check for reusable existing keys**

Run: `grep -n '"purchase":\|"rent":\|"salary":\|"utilities":\|"transport":\|"marketing":\|"other":' lib/l10n/app_ru.arb`
Expected: all 7 already exist with exactly matching values — `purchase: "Закупка"`, `rent: "Аренда"`, `salary: "Зарплата"`, `utilities: "Коммунальные"`, `transport: "Транспорт"`, `marketing: "Маркетинг"`, `other: "Другое"`. **No new keys needed for this file** — full reuse.

- [ ] **Step 5: Replace literals in `expense_card.dart`**

`_categoryLabel(String category)` is an instance method on a `StatelessWidget` (no inherited `context`), called once at line 59 from `build(context)` — thread `context` through:

| Find | Replace with |
|---|---|
| `String _categoryLabel(String category) {` | `String _categoryLabel(BuildContext context, String category) {` |
| `case 'PURCHASE': return 'Закупка';` | `case 'PURCHASE': return AppLocalizations.of(context)!.purchase;` |
| `case 'RENT': return 'Аренда';` | `case 'RENT': return AppLocalizations.of(context)!.rent;` |
| `case 'SALARY': return 'Зарплата';` | `case 'SALARY': return AppLocalizations.of(context)!.salary;` |
| `case 'UTILITIES': return 'Коммунальные';` | `case 'UTILITIES': return AppLocalizations.of(context)!.utilities;` |
| `case 'TRANSPORT': return 'Транспорт';` | `case 'TRANSPORT': return AppLocalizations.of(context)!.transport;` |
| `case 'MARKETING': return 'Маркетинг';` | `case 'MARKETING': return AppLocalizations.of(context)!.marketing;` |
| `default: return 'Другое';` | `default: return AppLocalizations.of(context)!.other;` |
| `Text(_categoryLabel(expense.category), ...)` | `Text(_categoryLabel(context, expense.category), ...)` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file's imports (currently missing).

#### `investment_list_page.dart` (6 offenders)

Current offenders (verbatim):
```
33:    (null, 'Все'),
34:    ('ACTIVE', 'Активно'),
35:    ('COMPLETED', 'Завершено'),
36:    ('CANCELLED', 'Отменено'),
62:        return 'Активно';
63:        return 'Завершено';
...
66:        return 'Отменено';
80:            appBar: AppBar(title: const Text('Вложения')),
167:                                    Text('Вложений пока нет',
```

(`'Активно'`/`'Завершено'`/`'Отменено'` each appear twice — once in the `_statuses` list, once in `_statusLabel` — but are the same content, so the allow-list counts each value once; 6 distinct entries total: `Все`, `Активно`, `Завершено`, `Отменено`, `Вложения`, `Вложений пока нет`.)

- [ ] **Step 6: Check for reusable existing keys**

Run: `grep -n '"all":\|"completed":\|"cancelled":' lib/l10n/app_ru.arb`
Expected: `all: "Все"` matches exactly — reuse. **Do NOT reuse** `completed: "Завершена"` or `cancelled: "Отменена"` — those are feminine-agreement forms (for a different noun elsewhere) and do not match this file's neuter `"Завершено"`/`"Отменено"` character-for-character. Also run `grep -n '"Активно"\|Вложения' lib/l10n/app_ru.arb` — expect no exact match for the bare status labels or the page title/empty-state text (only `investmentCreated`/`investmentUpdated`/`investmentDeleted` exist, which are different snackbar sentences, not reusable here).

- [ ] **Step 7: Add new keys to `app_ru.arb`**

Add near the existing `investmentCreated`/`investmentUpdated`/`investmentDeleted` block:

```json
  "investments": "Вложения",
  "investmentEmptyState": "Вложений пока нет",
  "investmentStatusActive": "Активно",
  "investmentStatusCompleted": "Завершено",
  "investmentStatusCancelled": "Отменено",
```

- [ ] **Step 8: Replace literals in `investment_list_page.dart`**

**Important:** `_statuses` (lines 32-37) is a `final` field initialized inline on the `State` object — this runs before the widget is mounted, so `context` is not safely available there. Convert it to a method taking `BuildContext`:

```dart
List<(String?, String)> _statuses(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return [
    (null, l10n.all),
    ('ACTIVE', l10n.investmentStatusActive),
    ('COMPLETED', l10n.investmentStatusCompleted),
    ('CANCELLED', l10n.investmentStatusCancelled),
  ];
}
```

Update both call sites inside the `Builder(builder: (context) {...})` subtree (line 104's `itemCount: _statuses.length` and line 107's `final s = _statuses[index];`) to `_statuses(context).length` / `_statuses(context)[index]` — that `context` is the `Builder`'s own, already in scope.

`_statusLabel(String status)` (lines 59-70) is an instance method with no inherited `context` — thread it through; it's called at line 247 from inside `itemBuilder: (context, index)`, which has `context`:

| Find | Replace with |
|---|---|
| `String _statusLabel(String status) {` | `String _statusLabel(String status, BuildContext context) {` |
| `case 'ACTIVE':\n        return 'Активно';` | `case 'ACTIVE':\n        return AppLocalizations.of(context)!.investmentStatusActive;` |
| `case 'COMPLETED':\n        return 'Завершено';` | `case 'COMPLETED':\n        return AppLocalizations.of(context)!.investmentStatusCompleted;` |
| `case 'CANCELLED':\n        return 'Отменено';` | `case 'CANCELLED':\n        return AppLocalizations.of(context)!.investmentStatusCancelled;` |
| `_statusLabel(inv.status),` | `_statusLabel(inv.status, context),` |
| `appBar: AppBar(title: const Text('Вложения')),` | `appBar: AppBar(title: Text(AppLocalizations.of(context)!.investments)),` |
| `Text('Вложений пока нет',` | `Text(AppLocalizations.of(context)!.investmentEmptyState,` |

`AppLocalizations` is already imported (line 1).

#### `period_selector.dart` (4 offenders)

Current offenders (verbatim):
```
15:      ('day', 'День'),
16:      ('week', 'Неделя'),
17:      ('month', 'Месяц'),
18:      ('year', 'Год'),
```

- [ ] **Step 9: Check for reusable existing keys**

Run: `grep -n '"day":\|"week":\|"month":\|"year":' lib/l10n/app_ru.arb`
Expected: `day: "День"`, `week: "Неделя"`, `month: "Месяц"`, `year: "Год"` all exist with exactly matching values. **No new keys needed** — full reuse.

- [ ] **Step 10: Replace literals in `period_selector.dart`**

`periods` is a local variable inside `build(BuildContext context)` — `context` is already in scope.

| Find | Replace with |
|---|---|
| `('day', 'День'),` | `('day', AppLocalizations.of(context)!.day),` |
| `('week', 'Неделя'),` | `('week', AppLocalizations.of(context)!.week),` |
| `('month', 'Месяц'),` | `('month', AppLocalizations.of(context)!.month),` |
| `('year', 'Год'),` | `('year', AppLocalizations.of(context)!.year),` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing).

#### `profit_summary_card.dart` (3 offenders)

Current offenders (verbatim):
```
26:          _buildRow(context, 'Доход', income, AppColors.success),
28:          _buildRow(context, 'Расходы', expenses, AppColors.error),
30:          _buildRow(context, 'Прибыль', profit, profit >= 0 ? AppColors.success : AppColors.error, isBold: true),
```

- [ ] **Step 11: Check for reusable existing keys**

Run: `grep -n '"income":\|"expenses":\|"profit":' lib/l10n/app_ru.arb`
Expected: `income: "Доход"`, `expenses: "Расходы"`, `profit: "Прибыль"` all exist with exactly matching values. **No new keys needed** — full reuse.

- [ ] **Step 12: Replace literals in `profit_summary_card.dart`**

`_buildRow` already receives `context` as its first parameter, called from `build(context)` — no threading needed.

| Find | Replace with |
|---|---|
| `_buildRow(context, 'Доход', income, AppColors.success),` | `_buildRow(context, AppLocalizations.of(context)!.income, income, AppColors.success),` |
| `_buildRow(context, 'Расходы', expenses, AppColors.error),` | `_buildRow(context, AppLocalizations.of(context)!.expenses, expenses, AppColors.error),` |
| `_buildRow(context, 'Прибыль', profit, profit >= 0 ? AppColors.success : AppColors.error, isBold: true),` | `_buildRow(context, AppLocalizations.of(context)!.profit, profit, profit >= 0 ? AppColors.success : AppColors.error, isBold: true),` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing).

#### `stat_summary_row.dart` (2 offenders)

Current offenders (verbatim):
```
23:                Text('Продаж', style: TextStyle(fontSize: 12, color: context.textSecondary)),
36:                Text('Средний чек', style: TextStyle(fontSize: 12, color: context.textSecondary)),
```

- [ ] **Step 13: Check for reusable existing keys**

Run: `grep -n '"avgCheck":\|"sales":' lib/l10n/app_ru.arb`
Expected: `avgCheck: "Средний чек"` exists exactly — reuse. `sales: "Продажи"` exists but is the WRONG grammatical case (nominative plural "Продажи") for this file's genitive-plural caption `"Продаж"` (used under a bare count number) — do not reuse; confirm with `grep -n '": "Продаж"' lib/l10n/app_ru.arb` (expect no output) and mint a new key.

- [ ] **Step 14: Add new keys to `app_ru.arb`**

```json
  "salesCountLabel": "Продаж",
  "@salesCountLabel": { "description": "Genitive-plural caption under a bare sales-count number in a stat tile (e.g. finance dashboard) — distinct from `sales` (\"Продажи\", nominative plural, used as a section/label heading elsewhere)" },
```

- [ ] **Step 15: Replace literals in `stat_summary_row.dart`**

| Find | Replace with |
|---|---|
| `Text('Продаж', style: TextStyle(fontSize: 12, color: context.textSecondary)),` | `Text(AppLocalizations.of(context)!.salesCountLabel, style: TextStyle(fontSize: 12, color: context.textSecondary)),` |
| `Text('Средний чек', style: TextStyle(fontSize: 12, color: context.textSecondary)),` | `Text(AppLocalizations.of(context)!.avgCheck, style: TextStyle(fontSize: 12, color: context.textSecondary)),` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing).

- [ ] **Step 16: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors.

- [ ] **Step 17: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep -E 'currencies_page.dart|expense_card.dart|investment_list_page.dart|period_selector.dart|profit_summary_card.dart|stat_summary_row.dart'` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/finance/currencies_page_golden_test.dart test/presentation/pages/finance/investment_list_page_golden_test.dart test/presentation/widgets/finance/expense_card_golden_test.dart test/presentation/widgets/finance/period_selector_golden_test.dart test/presentation/widgets/finance/profit_summary_card_golden_test.dart test/presentation/widgets/finance/stat_summary_row_golden_test.dart --reporter expanded` — expect all passing (if any golden fails, verify per the spec's baseline-check technique whether it pre-exists at the parent commit before treating it as a regression).

- [ ] **Step 18: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json \
  lib/presentation/pages/finance/currencies_page.dart \
  lib/presentation/widgets/finance/expense_card.dart \
  lib/presentation/pages/finance/investment_list_page.dart \
  lib/presentation/widgets/finance/period_selector.dart \
  lib/presentation/widgets/finance/profit_summary_card.dart \
  lib/presentation/widgets/finance/stat_summary_row.dart
git commit -m "fix(app): migrate finance misc hardcoded strings to AppLocalizations"
```

---

### Task 25: Migrate Zakat + shifts misc (`zakat_history_page.dart`, `zakat_breakdown_card.dart`, `current_shift_card.dart`, `open_shift_page.dart`, `shift_card.dart`)

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/zakat/zakat_history_page.dart`
- Modify: `lib/presentation/widgets/zakat/zakat_breakdown_card.dart`
- Modify: `lib/presentation/widgets/shifts/current_shift_card.dart`
- Modify: `lib/presentation/pages/shifts/open_shift_page.dart`
- Modify: `lib/presentation/widgets/shifts/shift_card.dart`

This task migrates all 37 tracked offenders (plus 2 untracked ones the lint tool's one-match-per-line regex silently missed — see `current_shift_card.dart`/`shift_card.dart` notes below) across these 5 files in one commit.

#### `zakat_history_page.dart` (9 offenders)

Current offenders (verbatim):
```
65:                  const Text('История закята',
96:                              title: 'Нет расчётов закята',
97:                              subtitle: 'Рассчитайте закят в калькуляторе, чтобы история появилась здесь',
122:                              Text('Всего выплачено:',
132:                                'за ${state.total > 0 ? state.total : state.payments.length} выплат',
166:                                      Text('Выплата закята',
169:                                      Text('Оплачен $dateStr',
180:                                    Text('Облагаемая: ${_formatPrice(payment.totalAssets)}',
203:                              child: const Text('Загрузить ещё'),
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"zakatHistory":\|Загрузить ещё\|"История закята"\|"Выплата закята"' lib/l10n/app_ru.arb`
Expected: `zakatHistory: "История выплат"` exists but is a **different sentence** from this page's own header `"История закята"` — do not reuse (near-miss). No key holds `"Загрузить ещё"`, `"Нет расчётов закята"`, `"Рассчитайте закят..."`, `"Всего выплачено:"`, `"Выплата закята"`, or the two interpolated lines — all need new keys.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "zakatHistoryPageTitle": "История закята",
  "zakatHistoryEmptyTitle": "Нет расчётов закята",
  "zakatHistoryEmptySubtitle": "Рассчитайте закят в калькуляторе, чтобы история появилась здесь",
  "zakatHistoryTotalPaidLabel": "Всего выплачено:",
  "zakatHistoryPaymentsCountLine": "за {count} выплат",
  "zakatHistoryPaymentTitle": "Выплата закята",
  "zakatHistoryPaidOnLine": "Оплачен {date}",
  "zakatHistoryTaxableLine": "Облагаемая: {amount}",
  "loadMore": "Загрузить ещё",
```

Placeholder metadata:

```json
  "@zakatHistoryPaymentsCountLine": {
    "placeholders": { "count": { "type": "String" } }
  },
  "@zakatHistoryPaidOnLine": {
    "placeholders": { "date": { "type": "String" } }
  },
  "@zakatHistoryTaxableLine": {
    "placeholders": { "amount": { "type": "String" } }
  },
```

`loadMore` is deliberately unprefixed — a generic pagination "load more" button, plausibly reused by any other paginated list in the app.

- [ ] **Step 3: Replace literals in `zakat_history_page.dart`**

`l10n` is already bound at the top of `build()` (line 49) and captured by every nested closure in this file (the `BlocBuilder`'s `builder`, the `.map` callback) — no separate `dialogContext`/`ctx` needed anywhere in this file.

**Important:** the empty-state `ListView`'s `children: const [...]` (lines 92-99) and the `AppEmptyState(...)` inside it are both `const` — since `l10n.zakatHistoryEmptyTitle`/`l10n.zakatHistoryEmptySubtitle` are not compile-time constants, drop `const` from both the list literal and the `AppEmptyState(...)` instantiation (the `SizedBox(height: 120)` sibling can keep its own `const`).

| Find | Replace with |
|---|---|
| `const Text('История закята',` | `Text(l10n.zakatHistoryPageTitle,` |
| `title: 'Нет расчётов закята',` | `title: l10n.zakatHistoryEmptyTitle,` |
| `subtitle: 'Рассчитайте закят в калькуляторе, чтобы история появилась здесь',` | `subtitle: l10n.zakatHistoryEmptySubtitle,` |
| `Text('Всего выплачено:',` | `Text(l10n.zakatHistoryTotalPaidLabel,` |
| `'за ${state.total > 0 ? state.total : state.payments.length} выплат',` | `l10n.zakatHistoryPaymentsCountLine((state.total > 0 ? state.total : state.payments.length).toString()),` |
| `Text('Выплата закята',` | `Text(l10n.zakatHistoryPaymentTitle,` |
| `Text('Оплачен $dateStr',` | `Text(l10n.zakatHistoryPaidOnLine(dateStr),` |
| `Text('Облагаемая: ${_formatPrice(payment.totalAssets)}',` | `Text(l10n.zakatHistoryTaxableLine(_formatPrice(payment.totalAssets)),` |
| `child: const Text('Загрузить ещё'),` | `child: Text(l10n.loadMore),` |

#### `zakat_breakdown_card.dart` (8 offenders)

Current offenders (verbatim):
```
19:          const Text('Разбивка активов', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
21:          _row(context, 'Товарные запасы', calculation.stockValue),
22:          _row(context, 'Дебиторская задолженность', calculation.receivables),
23:          _row(context, 'Кредиторская задолженность', -calculation.payables, isNegative: true),
25:          _row(context, 'Чистые активы', calculation.netAssets, isBold: true),
27:          _row(context, 'Нисаб', calculation.nisabAmount),
32:              const Text('Закят (2.5%)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
41:            Text('Активы ниже нисаба. Закят не обязателен.', style: TextStyle(color: context.textSecondary, fontSize: 12)),
```

- [ ] **Step 4: Check for reusable existing keys**

Run: `grep -n '"receivables":\|"payables":\|"netAssets":\|"stockValue":\|"nisabAmount":\|"nisabThreshold":\|"zakatDue":' lib/l10n/app_ru.arb`
Expected: `receivables: "Дебиторская задолженность"`, `payables: "Кредиторская задолженность"`, and `netAssets: "Чистые активы"` all match this file's text exactly — reuse all three. **Do NOT reuse** `stockValue: "Стоимость товаров"` for line 21's `'Товарные запасы'` (different wording, near-miss), and do **NOT reuse** `nisabAmount: "Сумма нисаба"` / `nisabThreshold: "Порог нисаба"` for line 27's bare `'Нисаб'` (neither matches — both are longer, differently-worded labels), and do **NOT reuse** `zakatDue: "Сумма закята"` for line 32's `'Закят (2.5%)'` (different wording/role — this is a card heading, not the amount label). Mint new keys for these four plus the title and warning sentence.

- [ ] **Step 5: Add new keys to `app_ru.arb`**

Add near the existing `stockValue`/`receivables`/`payables`/`netAssets`/`nisabAmount` block:

```json
  "zakatBreakdownTitle": "Разбивка активов",
  "zakatBreakdownStockLabel": "Товарные запасы",
  "@zakatBreakdownStockLabel": { "description": "Zakat breakdown card — stock-value row label; distinct wording from `stockValue` (\"Стоимость товаров\"), a different label used elsewhere for the same concept" },
  "zakatBreakdownNisabLabel": "Нисаб",
  "@zakatBreakdownNisabLabel": { "description": "Zakat breakdown card — bare nisab-threshold row label; distinct from `nisabAmount` (\"Сумма нисаба\") and `nisabThreshold` (\"Порог нисаба\"), longer labels used elsewhere" },
  "zakatBreakdownDueLabel": "Закят (2.5%)",
  "@zakatBreakdownDueLabel": { "description": "Zakat breakdown card — heading above the computed zakat-due amount; distinct from `zakatDue` (\"Сумма закята\"), a differently-worded label used elsewhere" },
  "zakatBelowNisabMessage": "Активы ниже нисаба. Закят не обязателен.",
```

- [ ] **Step 6: Replace literals in `zakat_breakdown_card.dart`**

All calls are made directly from `build(BuildContext context)` or via `_row(context, ...)`, which already receives `context` — no threading needed.

| Find | Replace with |
|---|---|
| `const Text('Разбивка активов', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),` | `Text(AppLocalizations.of(context)!.zakatBreakdownTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),` |
| `_row(context, 'Товарные запасы', calculation.stockValue),` | `_row(context, AppLocalizations.of(context)!.zakatBreakdownStockLabel, calculation.stockValue),` |
| `_row(context, 'Дебиторская задолженность', calculation.receivables),` | `_row(context, AppLocalizations.of(context)!.receivables, calculation.receivables),` |
| `_row(context, 'Кредиторская задолженность', -calculation.payables, isNegative: true),` | `_row(context, AppLocalizations.of(context)!.payables, -calculation.payables, isNegative: true),` |
| `_row(context, 'Чистые активы', calculation.netAssets, isBold: true),` | `_row(context, AppLocalizations.of(context)!.netAssets, calculation.netAssets, isBold: true),` |
| `_row(context, 'Нисаб', calculation.nisabAmount),` | `_row(context, AppLocalizations.of(context)!.zakatBreakdownNisabLabel, calculation.nisabAmount),` |
| `const Text('Закят (2.5%)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),` | `Text(AppLocalizations.of(context)!.zakatBreakdownDueLabel, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),` |
| `Text('Активы ниже нисаба. Закят не обязателен.', style: TextStyle(color: context.textSecondary, fontSize: 12)),` | `Text(AppLocalizations.of(context)!.zakatBelowNisabMessage, style: TextStyle(color: context.textSecondary, fontSize: 12)),` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing).

#### `current_shift_card.dart` (9 tracked offenders + 1 untracked)

Current offenders (verbatim):
```
55:    return '${hours}ч ${minutes}м';
82:                      'Текущая смена',
87:                      '${widget.shift.staffName ?? "Сотрудник"} - ${_formatElapsed(_elapsed)}',
100:                  'Активна',
109:              _StatItem(label: 'Продажи', value: '${widget.shift.salesTotal.toStringAsFixed(0)} TJS'),
110:              _StatItem(label: 'Кол-во', value: '${widget.shift.salesCount}'),
111:              _StatItem(label: 'Наличные', value: '${widget.shift.cashSales.toStringAsFixed(0)} TJS'),
112:              _StatItem(label: 'Карта', value: '${widget.shift.cardSales.toStringAsFixed(0)} TJS'),
121:              label: const Text('Закрыть смену'),
```

This is a `StatefulWidget`, so `context` is available directly in every `State` method (no threading needed anywhere in this file).

- [ ] **Step 7: Check for reusable existing keys**

Run: `grep -n '"shiftsDurationFormat"\|"shiftsActiveStatus"\|"closeShift":\|"currentShift":\|"cash":\|"card":\|"quantityShort":\|"sales":' lib/l10n/app_ru.arb`
Expected: `shiftsDurationFormat: "{hours}ч {minutes}м"` matches the `_formatElapsed` format exactly (String-typed `hours`/`minutes` placeholders, same as here) — reuse. `shiftsActiveStatus: "Активна"`, `closeShift: "Закрыть смену"`, `currentShift: "Текущая смена"`, `cash: "Наличные"`, `card: "Карта"`, `quantityShort: "Кол-во"`, and `sales: "Продажи"` all already exist with exactly matching values — reuse every one of them. No key holds the bare fallback label `"Сотрудник"` — confirm with `grep -n '": "Сотрудник"' lib/l10n/app_ru.arb` (expect no output); this needs a new key **shared with `shift_card.dart` below**, which uses the identical bare `'Сотрудник'` fallback.

- [ ] **Step 8: Add new keys to `app_ru.arb`**

```json
  "unknownStaffLabel": "Сотрудник",
  "@unknownStaffLabel": { "description": "Generic fallback label shown in place of a staff member's name when none is recorded (current-shift card, shift history card) — distinct from `shiftsUnknownCashier` (\"Не указан\"), a different fallback wording used on the shifts history page" },
```

(Reused by both `current_shift_card.dart` and `shift_card.dart` in this same bundle — mint it once here.)

- [ ] **Step 9: Replace literals in `current_shift_card.dart`**

| Find | Replace with |
|---|---|
| `return '${hours}ч ${minutes}м';` | `return AppLocalizations.of(context)!.shiftsDurationFormat(hours.toString(), minutes.toString());` |
| `'Текущая смена',` | `AppLocalizations.of(context)!.currentShift,` |
| `'${widget.shift.staffName ?? "Сотрудник"} - ${_formatElapsed(_elapsed)}',` | `'${widget.shift.staffName ?? AppLocalizations.of(context)!.unknownStaffLabel} - ${_formatElapsed(_elapsed)}',` |
| `'Активна',` | `AppLocalizations.of(context)!.shiftsActiveStatus,` |
| `_StatItem(label: 'Продажи', value: ...)` | `_StatItem(label: AppLocalizations.of(context)!.sales, value: ...)` |
| `_StatItem(label: 'Кол-во', value: ...)` | `_StatItem(label: AppLocalizations.of(context)!.quantityShort, value: ...)` |
| `_StatItem(label: 'Наличные', value: ...)` | `_StatItem(label: AppLocalizations.of(context)!.cash, value: ...)` |
| `_StatItem(label: 'Карта', value: ...)` | `_StatItem(label: AppLocalizations.of(context)!.card, value: ...)` |
| `label: const Text('Закрыть смену'),` | `label: Text(AppLocalizations.of(context)!.closeShift),` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing). Remove the `// ignore: unnecessary_brace_in_string_interps` comment above `_formatElapsed`'s old return line since it no longer applies.

#### `open_shift_page.dart` (7 offenders)

Current offenders (verbatim):
```
46:      appBar: AppBar(title: const Text('Открыть смену')),
80:                        'Начало смены',
85:                        'Укажите сумму наличных в кассе на начало смены',
95:                  label: 'Сумма наличных (TJS)',
99:                    if (v == null || v.isEmpty) return 'Введите сумму';
100:                    if (double.tryParse(v) == null) return 'Некорректная сумма';
101:                    if (double.parse(v) < 0) return 'Сумма не может быть отрицательной';
109:                      text: 'Открыть смену',
```

(8 literal call sites, 7 distinct values — `'Открыть смену'` appears twice, at line 46 and line 109.)

- [ ] **Step 10: Check for reusable existing keys**

Run: `grep -n '"openShift":\|"invalidAmount":\|"shiftsCashAmountRequired":\|"shiftsCashAmountNegative":' lib/l10n/app_ru.arb`
Expected: `openShift: "Открыть смену"` matches exactly — reuse for **both** occurrences (appbar title and submit button). `invalidAmount: "Некорректная сумма"` matches exactly — reuse. `shiftsCashAmountRequired: "Введите сумму"` and `shiftsCashAmountNegative: "Сумма не может быть отрицательной"` both match exactly (their descriptions say "close-shift dialog" but the value and meaning are identical for this open-shift form) — reuse both. No key holds `"Начало смены"`, `"Укажите сумму наличных в кассе на начало смены"`, or `"Сумма наличных (TJS)"` — confirm with `grep -n 'Начало смены\|Сумма наличных (TJS)' lib/l10n/app_ru.arb` (expect no output).

- [ ] **Step 11: Add new keys to `app_ru.arb`**

Add near the existing `openShift`/`shiftsCashAmountRequired` block:

```json
  "openShiftHeading": "Начало смены",
  "openShiftSubtitle": "Укажите сумму наличных в кассе на начало смены",
  "openShiftCashLabel": "Сумма наличных (TJS)",
```

- [ ] **Step 12: Replace literals in `open_shift_page.dart`**

`build(BuildContext context)` doesn't currently bind a local `l10n`; add one (`final l10n = AppLocalizations.of(context)!;`) at the top since it's used at 5+ call sites, matching this file's own existing style (it already calls `AppLocalizations.of(context)!.snackShiftOpened` once at line 50 — fold that into the same `l10n` binding too).

| Find | Replace with |
|---|---|
| `appBar: AppBar(title: const Text('Открыть смену')),` | `appBar: AppBar(title: Text(l10n.openShift)),` |
| `'Начало смены',` | `l10n.openShiftHeading,` |
| `'Укажите сумму наличных в кассе на начало смены',` | `l10n.openShiftSubtitle,` |
| `label: 'Сумма наличных (TJS)',` | `label: l10n.openShiftCashLabel,` |
| `if (v == null || v.isEmpty) return 'Введите сумму';` | `if (v == null || v.isEmpty) return l10n.shiftsCashAmountRequired;` |
| `if (double.tryParse(v) == null) return 'Некорректная сумма';` | `if (double.tryParse(v) == null) return l10n.invalidAmount;` |
| `if (double.parse(v) < 0) return 'Сумма не может быть отрицательной';` | `if (double.parse(v) < 0) return l10n.shiftsCashAmountNegative;` |
| `text: 'Открыть смену',` | `text: l10n.openShift,` |

Note the `validator` callback (lines 98-103) is a plain closure defined inside `build()`, so it captures the outer `l10n` — no separate context needed.

#### `shift_card.dart` (4 tracked offenders + 1 untracked)

Current offenders (verbatim):
```
33:    return '${hours}ч ${minutes}м';
68:                          shift.staffName ?? 'Сотрудник',
79:                            isOpen ? 'Открыта' : 'Закрыта',
105:                    '${shift.salesCount} продаж',
```

**Note:** line 79's ternary `isOpen ? 'Открыта' : 'Закрыта'` has two Cyrillic literals on one line; `check_i18n.dart`'s regex only reports the first match per line, so only `'Открыта'` is allow-listed — `'Закрыта'` is a real, untracked offender on the same line and must be migrated too (same root cause as `payment_form.dart`'s untracked `'Карта'` and `notifications_page.dart`'s untracked `'Запрос отклонён'` elsewhere in this project — always read the full line, don't trust the allow-list count alone).

This is a `StatelessWidget` — `_formatDuration` is an instance method with no inherited `context`, so it needs `BuildContext` threaded explicitly (unlike `current_shift_card.dart`'s `State` methods).

- [ ] **Step 13: Check for reusable existing keys**

Run: `grep -n '"shiftsOpenStatus":\|"shiftsClosedStatus":\|"shiftsDurationFormat":' lib/l10n/app_ru.arb`
Expected: `shiftsDurationFormat: "{hours}ч {minutes}м"` matches — reuse (same as `current_shift_card.dart` above; both files must reuse this one existing key, not mint duplicates). `shiftsOpenStatus: "Открыта"` matches line 79's true-branch exactly — reuse. **Do NOT reuse** `shiftsClosedStatus: "Сдано"` for line 79's false-branch `'Закрыта'` — different wording (near-miss); mint a new key. `unknownStaffLabel` was already minted in Step 8 above for `current_shift_card.dart` — reuse it here too for line 68's bare `'Сотрудник'` fallback (do not mint a second key).

- [ ] **Step 14: Add new keys to `app_ru.arb`**

```json
  "shiftCardClosedStatus": "Закрыта",
  "@shiftCardClosedStatus": { "description": "Shift card status badge for a closed shift — distinct from `shiftsClosedStatus` (\"Сдано\"), a different wording used in the shift history list" },
  "shiftCardSalesCountLine": "{count} продаж",
```

Placeholder metadata:

```json
  "@shiftCardSalesCountLine": {
    "placeholders": { "count": { "type": "String" } }
  },
```

- [ ] **Step 15: Replace literals in `shift_card.dart`**

| Find | Replace with |
|---|---|
| `String _formatDuration(DateTime open, DateTime? close) {` | `String _formatDuration(BuildContext context, DateTime open, DateTime? close) {` |
| `return '${hours}ч ${minutes}м';` | `return AppLocalizations.of(context)!.shiftsDurationFormat(hours.toString(), minutes.toString());` |
| `shift.staffName ?? 'Сотрудник',` | `shift.staffName ?? AppLocalizations.of(context)!.unknownStaffLabel,` |
| `isOpen ? 'Открыта' : 'Закрыта',` | `isOpen ? AppLocalizations.of(context)!.shiftsOpenStatus : AppLocalizations.of(context)!.shiftCardClosedStatus,` |
| `'${shift.salesCount} продаж',` | `AppLocalizations.of(context)!.shiftCardSalesCountLine(shift.salesCount.toString()),` |
| `'${_formatDuration(shift.openedAt, shift.closedAt)}'` (inside the line-91 composite) | `'${_formatDuration(context, shift.openedAt, shift.closedAt)}'` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing). Remove the now-unneeded `// ignore: unnecessary_brace_in_string_interps` comment above the old `_formatDuration` return line.

- [ ] **Step 16: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors.

- [ ] **Step 17: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep -E 'zakat_history_page.dart|zakat_breakdown_card.dart|current_shift_card.dart|open_shift_page.dart|shift_card.dart'` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/zakat/zakat_history_page_golden_test.dart test/presentation/widgets/zakat/zakat_breakdown_card_golden_test.dart test/presentation/widgets/shifts/current_shift_card_golden_test.dart test/presentation/pages/shifts/open_shift_page_golden_test.dart test/presentation/widgets/shifts/shift_card_golden_test.dart --reporter expanded` — expect all passing (verify any golden mismatch against the parent-commit baseline before treating it as a regression, per the spec's golden-test technique).

- [ ] **Step 18: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json \
  lib/presentation/pages/zakat/zakat_history_page.dart \
  lib/presentation/widgets/zakat/zakat_breakdown_card.dart \
  lib/presentation/widgets/shifts/current_shift_card.dart \
  lib/presentation/pages/shifts/open_shift_page.dart \
  lib/presentation/widgets/shifts/shift_card.dart
git commit -m "fix(app): migrate zakat and shifts misc hardcoded strings to AppLocalizations"
```

---

### Task 26: Migrate Supplier/stock/debt misc (`supplier_list_page.dart`, `stock_intake_page.dart`, `customer_debts_page.dart`, `payment_form.dart`)

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/supplier/supplier_list_page.dart`
- Modify: `lib/presentation/pages/stock/stock_intake_page.dart`
- Modify: `lib/presentation/pages/debt/customer_debts_page.dart`
- Modify: `lib/presentation/widgets/debt/payment_form.dart`

This task migrates all 37 tracked offenders (plus 1 untracked one — see `payment_form.dart` below) across these 4 files in one commit.

#### `supplier_list_page.dart` (12 offenders)

Current offenders (verbatim):
```
82:        title: const Text('Новый поставщик'),
89:                labelText: 'Название',
90:                hintText: 'Введите название поставщика',
99:                labelText: 'Телефон',
110:            child: const Text('Отмена'),
143:            child: const Text('Добавить'),
169:                  const Text('Поставщики',
193:                    hintText: 'Поиск поставщика',
222:                        title: 'Поставщиков пока нет',
223:                        subtitle: 'Добавьте первого поставщика, чтобы отслеживать поставки и долги',
224:                        buttonText: 'Добавить поставщика',
246:                                const Text('Наш долг',
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"cancel":\|"phoneLabel":\|"itemName":\|"suppliers":\|"addSupplier":\|"customerListAddConfirm":\|"newSupplier":\|"ourDebt":' lib/l10n/app_ru.arb`
Expected: `cancel: "Отмена"`, `phoneLabel: "Телефон"`, `itemName: "Название"`, `suppliers: "Поставщики"`, `addSupplier: "Добавить поставщика"`, `newSupplier: "Новый поставщик"`, and `ourDebt: "Наш долг"` all exist with exactly matching values — reuse all seven (`addSupplier` covers **both** the toolbar tooltip already using it at line 173 and this task's empty-state button at line 224 — same value, same key). `customerListAddConfirm: "Добавить"` also matches this file's line-143 confirm button exactly; it's screen-prefixed from an earlier task but its *meaning* (a generic dialog "Add" confirm) matches per the reuse-regardless-of-render-location rule — reuse it rather than minting a duplicate-valued key. No key holds `"Поставщиков пока нет"`, `"Добавьте первого поставщика..."`, `"Поиск поставщика"`, or `"Введите название поставщика"` — confirm with `grep -n 'Поставщиков пока нет\|Поиск поставщика\|Введите название поставщика' lib/l10n/app_ru.arb` (expect no output).

- [ ] **Step 2: Add new keys to `app_ru.arb`**

Add near the existing `suppliers`/`addSupplier`/`newSupplier`/`ourDebt` block:

```json
  "supplierListEmptyTitle": "Поставщиков пока нет",
  "supplierListEmptySubtitle": "Добавьте первого поставщика, чтобы отслеживать поставки и долги",
  "supplierListSearchHint": "Поиск поставщика",
  "supplierListNameHint": "Введите название поставщика",
```

- [ ] **Step 3: Replace literals in `supplier_list_page.dart`**

`l10n` is already bound at the top of `build()` (line 152) and used for `l10n.back`/`l10n.addSupplier`. The dialog `builder: (dialogContext) => AlertDialog(...)` (lines 81-147) has its own `dialogContext` distinct from the page's — use `AppLocalizations.of(dialogContext)!` for everything inside that builder, matching the established convention from the prior 9-file project's `customer_list_page.dart` task.

| Find | Replace with |
|---|---|
| `title: const Text('Новый поставщик'),` | `title: Text(AppLocalizations.of(dialogContext)!.newSupplier),` |
| `labelText: 'Название',` | `labelText: AppLocalizations.of(dialogContext)!.itemName,` |
| `hintText: 'Введите название поставщика',` | `hintText: AppLocalizations.of(dialogContext)!.supplierListNameHint,` |
| `labelText: 'Телефон',` | `labelText: AppLocalizations.of(dialogContext)!.phoneLabel,` |
| `child: const Text('Отмена'),` | `child: Text(AppLocalizations.of(dialogContext)!.cancel),` |
| `child: const Text('Добавить'),` | `child: Text(AppLocalizations.of(dialogContext)!.customerListAddConfirm),` |
| `const Text('Поставщики',` | `Text(l10n.suppliers,` |
| `hintText: 'Поиск поставщика',` | `hintText: l10n.supplierListSearchHint,` |
| `title: 'Поставщиков пока нет',` | `title: l10n.supplierListEmptyTitle,` |
| `subtitle: 'Добавьте первого поставщика, чтобы отслеживать поставки и долги',` | `subtitle: l10n.supplierListEmptySubtitle,` |
| `buttonText: 'Добавить поставщика',` | `buttonText: l10n.addSupplier,` |
| `const Text('Наш долг',` | `Text(l10n.ourDebt,` |

#### `stock_intake_page.dart` (12 offenders)

Current offenders (verbatim):
```
103:          title: const Text('Приход товара'),
111:                hint: 'Найти товар для прихода',
155:            'Найдите товар для оформления прихода',
196:                    'Товары не найдены',
261:              'Остаток: ${product.quantity} ${_getUnitDisplayName(product.unit)}',
338:                          'Цена: ${Formatters.price(product.sellPrice, currency: currency)}',
342:                          'Остаток: ${product.quantity} ${_getUnitDisplayName(product.unit)}',
363:            'Количество',
375:              hintText: 'Введите количество',
393:            'Себестоимость (за единицу)',
407:              hintText: 'Введите себестоимость',
435:                  'Итоговая стоимость',
455:            text: 'Сохранить',
```

(13 literal call sites, 12 distinct values — the `'Остаток: ...'` composite appears twice, at lines 261 and 342, with identical content.)

- [ ] **Step 4: Check for reusable existing keys**

Run: `grep -n '"save":\|"quantity":\|"stockIntake":\|"costPriceRequiredError":' lib/l10n/app_ru.arb`
Expected: `save: "Сохранить"`, `quantity: "Количество"`, `stockIntake: "Приход товара"`, and `costPriceRequiredError: "Введите себестоимость"` all match exactly — reuse all four. No key holds `"Найти товар для прихода"`, `"Найдите товар для оформления прихода"`, `"Товары не найдены"`, the `"Остаток: ..."` line, the `"Цена: ..."` line, `"Введите количество"`, `"Себестоимость (за единицу)"`, or `"Итоговая стоимость"` — confirm with `grep -n 'Товары не найдены\|Введите количество\|Итоговая стоимость' lib/l10n/app_ru.arb` (expect no output).

- [ ] **Step 5: Add new keys to `app_ru.arb`**

```json
  "noProductsFound": "Товары не найдены",
  "enterQuantityHint": "Введите количество",
  "stockIntakeSearchHint": "Найти товар для прихода",
  "stockIntakeEmptyState": "Найдите товар для оформления прихода",
  "stockIntakeRemainingLine": "Остаток: {quantity} {unit}",
  "stockIntakePriceLine": "Цена: {price}",
  "stockIntakeCostPerUnitLabel": "Себестоимость (за единицу)",
  "stockIntakeTotalCostLabel": "Итоговая стоимость",
```

`noProductsFound` and `enterQuantityHint` are deliberately unprefixed — both are generic enough to plausibly recur on other product-search/quantity-entry screens (e.g. `product_list_page.dart`, task 13 of this same project) rather than being intake-specific.

Placeholder metadata:

```json
  "@stockIntakeRemainingLine": {
    "placeholders": { "quantity": { "type": "String" }, "unit": { "type": "String" } }
  },
  "@stockIntakePriceLine": {
    "placeholders": { "price": { "type": "String" } }
  },
```

- [ ] **Step 6: Replace literals in `stock_intake_page.dart`**

All call sites are inside `State` methods (`build`, `_buildEmptyState`, `_buildProductSearchResults`, `_buildProductItem`, `_buildIntakeForm`), so `context` is available via the inherited getter everywhere — no threading needed. Note the two identical `'Остаток: ...'` occurrences (lines 261 and 342) both need the same replacement.

| Find | Replace with |
|---|---|
| `title: const Text('Приход товара'),` | `title: Text(AppLocalizations.of(context)!.stockIntake),` |
| `hint: 'Найти товар для прихода',` | `hint: AppLocalizations.of(context)!.stockIntakeSearchHint,` |
| `'Найдите товар для оформления прихода',` | `AppLocalizations.of(context)!.stockIntakeEmptyState,` |
| `'Товары не найдены',` | `AppLocalizations.of(context)!.noProductsFound,` |
| `'Остаток: ${product.quantity} ${_getUnitDisplayName(product.unit)}',` (both occurrences, lines 261 and 342) | `AppLocalizations.of(context)!.stockIntakeRemainingLine(product.quantity.toString(), _getUnitDisplayName(product.unit)),` |
| `'Цена: ${Formatters.price(product.sellPrice, currency: currency)}',` | `AppLocalizations.of(context)!.stockIntakePriceLine(Formatters.price(product.sellPrice, currency: currency)),` |
| `'Количество',` | `AppLocalizations.of(context)!.quantity,` |
| `hintText: 'Введите количество',` | `hintText: AppLocalizations.of(context)!.enterQuantityHint,` |
| `'Себестоимость (за единицу)',` | `AppLocalizations.of(context)!.stockIntakeCostPerUnitLabel,` |
| `hintText: 'Введите себестоимость',` | `hintText: AppLocalizations.of(context)!.costPriceRequiredError,` |
| `'Итоговая стоимость',` | `AppLocalizations.of(context)!.stockIntakeTotalCostLabel,` |
| `text: 'Сохранить',` | `text: AppLocalizations.of(context)!.save,` |

(The `const` on the `Text('Количество', ...)` and `Text('Себестоимость (за единицу)', ...)` wrappers at lines 362 and 392 must be dropped since the replacement is no longer a compile-time constant.)

#### `customer_debts_page.dart` (8 offenders)

Current offenders (verbatim):
```
115:            AppSnackbar.info(context, 'Платёж сохранён офлайн — отправим при подключении');
137:                      Text('Общий долг', style: TextStyle(fontSize: 14, color: context.textSecondary)),
147:                const Text('Продажи с долгом', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
150:                  Center(child: Text('Нет продаж с долгом', style: TextStyle(color: context.textSecondary)))
170:                                    Text('Чек #$receiptNo', style: const TextStyle(fontWeight: FontWeight.w600)),
179:                                        child: const Text('Просрочено',
192:                                Text('Итого: ${total.toStringAsFixed(2)} TJS', style: TextStyle(fontSize: 13, color: context.textSecondary)),
203:                                label: const Text('Принять оплату'),
```

- [ ] **Step 7: Check for reusable existing keys**

Run: `grep -n '"totalDebt":\|"paymentQueuedOfflineMessage":\|"dashboardSaleReceiptLabel":\|"payrollTotalLine":\|"creditsAcceptPayment":' lib/l10n/app_ru.arb`
Expected: `totalDebt: "Общий долг"` matches exactly — reuse. `paymentQueuedOfflineMessage: "Платёж сохранён офлайн — отправим при подключении"` matches exactly — reuse. `dashboardSaleReceiptLabel: "Чек #{receiptNo}"` matches this file's `'Чек #$receiptNo'` composite exactly — reuse. `payrollTotalLine: "Итого: {amount} TJS"` matches this file's `'Итого: ...'` composite exactly (its name is payroll-specific but its value/meaning is a generic "Total: {amount} TJS" line) — reuse. **Do NOT reuse** `creditsAcceptPayment: "Принять платёж"` for line 203's `'Принять оплату'` — different wording (near-miss); this needs a new, shared key (see `payment_form.dart` below, which uses the identical string). No key holds `"Продажи с долгом"`, `"Нет продаж с долгом"`, or `"Просрочено"` — confirm with `grep -n 'Продажи с долгом\|Нет продаж с долгом\|"Просрочено"' lib/l10n/app_ru.arb` (expect no output).

- [ ] **Step 8: Add new keys to `app_ru.arb`**

```json
  "customerDebtsSalesTitle": "Продажи с долгом",
  "customerDebtsEmptyState": "Нет продаж с долгом",
  "overdueLabel": "Просрочено",
  "acceptDebtPayment": "Принять оплату",
  "@acceptDebtPayment": { "description": "'Accept payment' action on the customer-debts page and the payment-form sheet it opens — distinct from `creditsAcceptPayment` (\"Принять платёж\"), a different wording used on the credits screen" },
```

`overdueLabel` is deliberately unprefixed — a generic "overdue" badge, plausibly reused on other debt/invoice-aging displays. `acceptDebtPayment` is minted here and **reused by `payment_form.dart` below** — do not mint it a second time there.

- [ ] **Step 9: Replace literals in `customer_debts_page.dart`**

`l10n` is already bound at the top of `build()` (line 96) and captured by the `BlocConsumer`'s `listener`/`builder` closures — use it throughout.

| Find | Replace with |
|---|---|
| `AppSnackbar.info(context, 'Платёж сохранён офлайн — отправим при подключении');` | `AppSnackbar.info(context, l10n.paymentQueuedOfflineMessage);` |
| `Text('Общий долг', style: TextStyle(fontSize: 14, color: context.textSecondary)),` | `Text(l10n.totalDebt, style: TextStyle(fontSize: 14, color: context.textSecondary)),` |
| `const Text('Продажи с долгом', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),` | `Text(l10n.customerDebtsSalesTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),` |
| `Center(child: Text('Нет продаж с долгом', style: TextStyle(color: context.textSecondary)))` | `Center(child: Text(l10n.customerDebtsEmptyState, style: TextStyle(color: context.textSecondary)))` |
| `Text('Чек #$receiptNo', style: const TextStyle(fontWeight: FontWeight.w600)),` | `Text(l10n.dashboardSaleReceiptLabel(receiptNo), style: const TextStyle(fontWeight: FontWeight.w600)),` |
| `child: const Text('Просрочено',` | `child: Text(l10n.overdueLabel,` |
| `Text('Итого: ${total.toStringAsFixed(2)} TJS', style: TextStyle(fontSize: 13, color: context.textSecondary)),` | `Text(l10n.payrollTotalLine(total.toStringAsFixed(2)), style: TextStyle(fontSize: 13, color: context.textSecondary)),` |
| `label: const Text('Принять оплату'),` | `label: Text(l10n.acceptDebtPayment),` |

#### `payment_form.dart` (5 tracked offenders + 1 untracked)

Current offenders (verbatim):
```
50:          const Text('Принять оплату', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
52:          Text('Максимум: ${widget.maxAmount.toStringAsFixed(2)} TJS', style: TextStyle(color: context.textSecondary, fontSize: 13)),
56:            label: 'Сумма',
78:                    m == 'CASH' ? 'Наличные' : 'Карта',
87:          AppTextField(controller: _notesController, label: 'Заметки', maxLines: 2),
90:            text: 'Принять оплату',
```

**Note:** line 78's ternary `m == 'CASH' ? 'Наличные' : 'Карта'` has two Cyrillic literals on one line; `check_i18n.dart`'s regex only reports the first match per line, so only `'Наличные'` is allow-listed — `'Карта'` is a real, untracked 6th offender on that same line (same pattern as `shift_card.dart`'s `'Закрыта'` in Task 25).

This file already has some `AppLocalizations` calls (`l10n.invalidAmount`/`l10n.amountExceedsMax` inside `_validateAmount`, lines 33-38) — that's pre-existing, unrelated code from an earlier change; leave it as-is and only touch the 6 literals above.

- [ ] **Step 10: Check for reusable existing keys**

Run: `grep -n '"notes":\|"amount":\|"cash":\|"card":' lib/l10n/app_ru.arb`
Expected: `notes: "Заметки"`, `amount: "Сумма"`, `cash: "Наличные"`, and `card: "Карта"` all match exactly — reuse all four. `acceptDebtPayment: "Принять оплату"` was minted in Step 8 above (in `customer_debts_page.dart`'s section of this same task) — reuse it for **both** occurrences here (the form heading and the submit button), do not mint a duplicate. No key holds the `"Максимум: ..."` composite — confirm with `grep -n 'Максимум:' lib/l10n/app_ru.arb` (expect no output).

- [ ] **Step 11: Add new keys to `app_ru.arb`**

```json
  "paymentFormMaxAmountLine": "Максимум: {amount} TJS",
```

Placeholder metadata:

```json
  "@paymentFormMaxAmountLine": {
    "placeholders": { "amount": { "type": "String" } }
  },
```

- [ ] **Step 12: Replace literals in `payment_form.dart`**

`_PaymentFormState.build(BuildContext context)` has `context` in scope directly (it's a `State` method); `_validateAmount` already resolves its own `l10n` locally — leave that pattern alone and bind a similar local `l10n` at the top of `build()` for the 6 literals below.

| Find | Replace with |
|---|---|
| `const Text('Принять оплату', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),` | `Text(l10n.acceptDebtPayment, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),` |
| `Text('Максимум: ${widget.maxAmount.toStringAsFixed(2)} TJS', style: TextStyle(color: context.textSecondary, fontSize: 13)),` | `Text(l10n.paymentFormMaxAmountLine(widget.maxAmount.toStringAsFixed(2)), style: TextStyle(color: context.textSecondary, fontSize: 13)),` |
| `label: 'Сумма',` | `label: l10n.amount,` |
| `m == 'CASH' ? 'Наличные' : 'Карта',` | `m == 'CASH' ? l10n.cash : l10n.card,` |
| `AppTextField(controller: _notesController, label: 'Заметки', maxLines: 2),` | `AppTextField(controller: _notesController, label: l10n.notes, maxLines: 2),` |
| `text: 'Принять оплату',` | `text: l10n.acceptDebtPayment,` |

- [ ] **Step 13: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors.

- [ ] **Step 14: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep -E 'supplier_list_page.dart|stock_intake_page.dart|customer_debts_page.dart|payment_form.dart'` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/supplier/supplier_list_page_golden_test.dart test/presentation/pages/stock/stock_intake_page_golden_test.dart test/presentation/pages/debt/customer_debts_page_golden_test.dart test/presentation/widgets/debt/payment_form_golden_test.dart --reporter expanded` — expect all passing (verify any golden mismatch against the parent-commit baseline before treating it as a regression).

- [ ] **Step 15: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json \
  lib/presentation/pages/supplier/supplier_list_page.dart \
  lib/presentation/pages/stock/stock_intake_page.dart \
  lib/presentation/pages/debt/customer_debts_page.dart \
  lib/presentation/widgets/debt/payment_form.dart
git commit -m "fix(app): migrate supplier, stock intake, and debt misc hardcoded strings to AppLocalizations"
```

---

### Task 27: Migrate Notifications + payroll widget + dashboard widget (`notifications_page.dart`, `month_selector.dart`, `sale_list_item.dart`)

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/notifications/notifications_page.dart`
- Modify: `lib/presentation/widgets/payroll/month_selector.dart`
- Modify: `lib/presentation/widgets/dashboard/sale_list_item.dart`

This task migrates all 28 tracked offenders (plus 1 untracked one — see `notifications_page.dart` below) across these 3 files in one commit.

#### `notifications_page.dart` (13 tracked offenders + 1 untracked)

Current offenders (verbatim):
```
140:        _error = 'Магазин не выбран';
252:            decision == 'APPROVED' ? 'Доступ предоставлен' : 'Запрос отклонён',
262:              'Не удалось обработать запрос — возможно, он уже неактивен',
272:    if (diff.inSeconds < 60) return 'только что';
273:    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
274:    if (diff.inHours < 24) return '${diff.inHours} ч назад';
275:    if (diff.inDays < 7) return '${diff.inDays} д назад';
314:        title: const Text('Уведомления',
322:            tooltip: 'Настройки',
396:              child: const Text('Повторить'),
410:          Text('Нет уведомлений',
532:                              child: const Text('Отклонить'),
554:                                  : const Text('Разрешить'),
```

**Note:** line 252's ternary has two Cyrillic literals on one line (`'Доступ предоставлен'` and `'Запрос отклонён'`); `check_i18n.dart`'s regex only reports the first match per line, so `'Запрос отклонён'` is a real, untracked 14th offender that must be migrated alongside it.

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"retry":\|"justNow":\|"minutesAgo":\|"hoursAgo":\|"daysAgo":\|"settings":\|"notifications":' lib/l10n/app_ru.arb`
Expected: `retry: "Повторить"`, `settings: "Настройки"`, and `notifications: "Уведомления"` match exactly — reuse all three. `justNow: "только что"` matches exactly — reuse. `minutesAgo: "{minutes} мин назад"` and `hoursAgo: "{hours} ч назад"` match this file's composites exactly — reuse both. **Do NOT reuse** `daysAgo: "{days} дн назад"` for line 275 — the ARB value uses the abbreviation `"дн"` (two letters) while this file's literal uses `"д"` (one letter); confirm the mismatch with `grep -n '"daysAgo"' lib/l10n/app_ru.arb` before proceeding — mint a distinctly-named new key instead of silently changing either wording. No key holds `"Магазин не выбран"`, `"Доступ предоставлен"`, `"Запрос отклонён"`, `"Не удалось обработать запрос..."`, `"Нет уведомлений"`, `"Отклонить"`, or `"Разрешить"` — confirm with `grep -n 'Магазин не выбран\|Доступ предоставлен\|"Отклонить"\|"Разрешить"' lib/l10n/app_ru.arb` (expect no output).

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "noStoreSelected": "Магазин не выбран",
  "decline": "Отклонить",
  "allow": "Разрешить",
  "notificationsEmptyState": "Нет уведомлений",
  "impersonationAccessGranted": "Доступ предоставлен",
  "impersonationRequestRejected": "Запрос отклонён",
  "impersonationRequestFailedMessage": "Не удалось обработать запрос — возможно, он уже неактивен",
  "daysAgoShort": "{days} д назад",
  "@daysAgoShort": { "description": "Relative time — single-letter-abbreviated days-ago, e.g. '3 д назад'; distinct from `daysAgo` (\"{days} дн назад\"), a differently-abbreviated form used elsewhere" },
```

`noStoreSelected`, `decline`, and `allow` are deliberately unprefixed — all three are generic enough to recur elsewhere (a "no store selected" guard, and generic accept/decline buttons for any approval flow, not just impersonation).

Placeholder metadata:

```json
  "@daysAgoShort": {
    "placeholders": { "days": { "type": "String" } }
  },
```

(Merge this placeholders block into the single `@daysAgoShort` entry above rather than duplicating the key.)

- [ ] **Step 3: Replace literals in `notifications_page.dart`**

`_load`, `_respondToImpersonation`, and `_timeAgo` are all `State` methods — `context` is available via the inherited getter in each, so bind a local `l10n` at the top of each method that needs it (or reuse the file's existing `build()`-level access pattern).

| Find | Replace with |
|---|---|
| `_error = 'Магазин не выбран';` | `_error = AppLocalizations.of(context)!.noStoreSelected;` |
| `decision == 'APPROVED' ? 'Доступ предоставлен' : 'Запрос отклонён',` | `decision == 'APPROVED' ? AppLocalizations.of(context)!.impersonationAccessGranted : AppLocalizations.of(context)!.impersonationRequestRejected,` |
| `'Не удалось обработать запрос — возможно, он уже неактивен',` | `AppLocalizations.of(context)!.impersonationRequestFailedMessage,` |
| `if (diff.inSeconds < 60) return 'только что';` | `if (diff.inSeconds < 60) return AppLocalizations.of(context)!.justNow;` |
| `if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';` | `if (diff.inMinutes < 60) return AppLocalizations.of(context)!.minutesAgo(diff.inMinutes.toString());` |
| `if (diff.inHours < 24) return '${diff.inHours} ч назад';` | `if (diff.inHours < 24) return AppLocalizations.of(context)!.hoursAgo(diff.inHours.toString());` |
| `if (diff.inDays < 7) return '${diff.inDays} д назад';` | `if (diff.inDays < 7) return AppLocalizations.of(context)!.daysAgoShort(diff.inDays.toString());` |
| `title: const Text('Уведомления',` | `title: Text(AppLocalizations.of(context)!.notifications,` |
| `tooltip: 'Настройки',` | `tooltip: AppLocalizations.of(context)!.settings,` |
| `child: const Text('Повторить'),` | `child: Text(AppLocalizations.of(context)!.retry),` |
| `Text('Нет уведомлений',` | `Text(AppLocalizations.of(context)!.notificationsEmptyState,` |
| `child: const Text('Отклонить'),` | `child: Text(AppLocalizations.of(context)!.decline),` |
| `: const Text('Разрешить'),` | `: Text(AppLocalizations.of(context)!.allow),` |

`_timeAgo` (line 270) takes no `BuildContext` parameter today — thread one through: `String _timeAgo(DateTime dt, BuildContext context)`, updating its single call site at line 363 to `_timeAgo(n.createdAt, context)` (already inside `itemBuilder: (context, i)`, which has `context`).

#### `month_selector.dart` (12 offenders — all reuse existing keys, no new keys)

Current offenders (verbatim):
```
18:    'Январь',
19:    'Февраль',
20:    'Март',
21:    'Апрель',
22:    'Май',
23:    'Июнь',
24:    'Июль',
25:    'Август',
26:    'Сентябрь',
27:    'Октябрь',
28:    'Ноябрь',
29:    'Декабрь',
```

- [ ] **Step 4: Check for reusable existing keys**

Run: `grep -n '"month[A-Z][a-z]*":' lib/l10n/app_ru.arb`
Expected: `monthJanuary: "Январь"`, `monthFebruary: "Февраль"`, `monthMarch: "Март"`, `monthApril: "Апрель"`, `monthMay: "Май"`, `monthJune: "Июнь"`, `monthJuly: "Июль"`, `monthAugust: "Август"`, `monthSeptember: "Сентябрь"`, `monthOctober: "Октябрь"`, `monthNovember: "Ноябрь"`, `monthDecember: "Декабрь"` — all 12 already exist, minted in Task 7 of the prior merged 9-file project (`payroll_page.dart`) specifically so this file could reuse them. **Verify every value matches character-for-character** (they do, per the grep above) and **do not mint any new month-name keys** — this file needs zero ARB additions.

- [ ] **Step 5: Replace literals in `month_selector.dart`**

**Important:** `_monthNames` (lines 17-30) is a `static const List<String>` — `AppLocalizations.of(context)` cannot be called in a `static const` initializer. Convert it to an instance method taking `BuildContext`, matching the pattern established in Task 5 (`my_stores_page.dart`'s category map) and Task 7 (`payroll_page.dart`'s own month list) of the prior project:

```dart
List<String> _monthNames(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return [
    l10n.monthJanuary, l10n.monthFebruary, l10n.monthMarch, l10n.monthApril,
    l10n.monthMay, l10n.monthJune, l10n.monthJuly, l10n.monthAugust,
    l10n.monthSeptember, l10n.monthOctober, l10n.monthNovember, l10n.monthDecember,
  ];
}
```

Delete the old `static const _monthNames = [...]` field entirely.

| Find | Replace with |
|---|---|
| `'${_monthNames[month - 1]} $year',` | `'${_monthNames(context)[month - 1]} $year',` |

The call site is inside `build(BuildContext context)` (line 68), so `context` is already in scope. Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing).

#### `sale_list_item.dart` (3 offenders — all reuse existing keys, no new keys)

Current offenders (verbatim):
```
107:        badgeLabel = 'Наличные';
111:        badgeLabel = 'Карта';
115:        badgeLabel = 'В долг';
```

- [ ] **Step 6: Check for reusable existing keys**

Run: `grep -n '"cash":\|"card":\|"debt":' lib/l10n/app_ru.arb`
Expected: `cash: "Наличные"`, `card: "Карта"`, and `debt: "В долг"` all exist with exactly matching values — reuse all three. **No new keys needed for this file** — full reuse.

- [ ] **Step 7: Replace literals in `sale_list_item.dart`**

`_buildPaymentBadge(BuildContext context)` already receives `context` (line 100) — no threading needed.

| Find | Replace with |
|---|---|
| `badgeLabel = 'Наличные';` | `badgeLabel = AppLocalizations.of(context)!.cash;` |
| `badgeLabel = 'Карта';` | `badgeLabel = AppLocalizations.of(context)!.card;` |
| `badgeLabel = 'В долг';` | `badgeLabel = AppLocalizations.of(context)!.debt;` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing).

- [ ] **Step 8: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors.

- [ ] **Step 9: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep -E 'notifications_page.dart|month_selector.dart|sale_list_item.dart'` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/notifications/notifications_page_golden_test.dart test/presentation/widgets/payroll/month_selector_golden_test.dart test/presentation/widgets/dashboard/sale_list_item_golden_test.dart --reporter expanded` — expect all passing (verify any golden mismatch against the parent-commit baseline before treating it as a regression).

- [ ] **Step 10: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json \
  lib/presentation/pages/notifications/notifications_page.dart \
  lib/presentation/widgets/payroll/month_selector.dart \
  lib/presentation/widgets/dashboard/sale_list_item.dart
git commit -m "fix(app): migrate notifications, month selector, and sale list item hardcoded strings to AppLocalizations"
```

---

### Task 28: Migrate Common widgets misc (`offline_banner.dart`, `barcode_scanner_sheet.dart`, `app_dialog.dart`, `impersonation_banner.dart`, `phone_input_field.dart`, `app_search_bar.dart`, `app_error_widget.dart`, `app_bottom_sheet.dart`)

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/widgets/common/offline_banner.dart`
- Modify: `lib/presentation/widgets/common/barcode_scanner_sheet.dart`
- Modify: `lib/presentation/widgets/common/app_dialog.dart`
- Modify: `lib/presentation/widgets/home/impersonation_banner.dart`
- Modify: `lib/presentation/widgets/common/phone_input_field.dart`
- Modify: `lib/presentation/widgets/common/app_search_bar.dart`
- Modify: `lib/presentation/widgets/common/app_error_widget.dart`
- Modify: `lib/presentation/widgets/common/app_bottom_sheet.dart`

This task migrates all 17 offenders across these 8 files in one commit, since each is small individually. Two of these files (`barcode_scanner_sheet.dart`, `app_bottom_sheet.dart`) currently hardcode the **Tajik** word `'Пӯшидан'` ("Close") as a Russian-locale tooltip — this is an existing, unrelated bug (wrong language, not just missing localization) that gets fixed as a side effect of migrating it to the already-existing `close` key; likewise `app_dialog.dart` hardcodes Tajik `'Тасдиқ'`/`'Бекор'` ("Confirm"/"Cancel") as default parameter values. Fixing the wrong-language text is in scope here since it's literally the same literal being extracted, not an unrelated change.

#### `offline_banner.dart` (6 offenders)

Current offenders (verbatim):
```
87:          ? 'Офлайн режим · $_pendingCount в очереди'
88:          : 'Нет подключения к интернету';
92:      message = 'Синхронизация...';
96:      message = 'Ошибка синхронизации · $_pendingCount не отправлено';
100:      message = '$_pendingCount операций ожидают синхронизации';
133:                  'Повторить',
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"retry":\|"offline":\|"snackSyncError":' lib/l10n/app_ru.arb`
Expected: `retry: "Повторить"` matches exactly — reuse. **Do NOT reuse** `offline: "Нет подключения к интернету. Работаем офлайн."` for line 88 — it's a longer, two-sentence value, not a character-for-character match for this file's bare `'Нет подключения к интернету'`. **Do NOT reuse** `snackSyncError: "Ошибка синхронизации: {error}"` for line 96 — different composite shape (a colon+error-message form, not this file's `· {count} не отправлено` form). No key covers any of these 5 composites/strings — confirm with `grep -n 'Офлайн режим\|операций ожидают синхронизации' lib/l10n/app_ru.arb` (expect no output).

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "offlineBannerNoConnection": "Нет подключения к интернету",
  "offlineBannerQueuedMessage": "Офлайн режим · {count} в очереди",
  "offlineBannerSyncing": "Синхронизация...",
  "offlineBannerSyncErrorMessage": "Ошибка синхронизации · {count} не отправлено",
  "offlineBannerPendingMessage": "{count} операций ожидают синхронизации",
```

Placeholder metadata:

```json
  "@offlineBannerQueuedMessage": {
    "placeholders": { "count": { "type": "String" } }
  },
  "@offlineBannerSyncErrorMessage": {
    "placeholders": { "count": { "type": "String" } }
  },
  "@offlineBannerPendingMessage": {
    "placeholders": { "count": { "type": "String" } }
  },
```

- [ ] **Step 3: Replace literals in `offline_banner.dart`**

All literals sit inside `build(BuildContext context)` (a `State` method) — `context` is available directly.

| Find | Replace with |
|---|---|
| `? 'Офлайн режим · $_pendingCount в очереди'` | `? AppLocalizations.of(context)!.offlineBannerQueuedMessage(_pendingCount.toString())` |
| `: 'Нет подключения к интернету';` | `: AppLocalizations.of(context)!.offlineBannerNoConnection;` |
| `message = 'Синхронизация...';` | `message = AppLocalizations.of(context)!.offlineBannerSyncing;` |
| `message = 'Ошибка синхронизации · $_pendingCount не отправлено';` | `message = AppLocalizations.of(context)!.offlineBannerSyncErrorMessage(_pendingCount.toString());` |
| `message = '$_pendingCount операций ожидают синхронизации';` | `message = AppLocalizations.of(context)!.offlineBannerPendingMessage(_pendingCount.toString());` |
| `'Повторить',` | `AppLocalizations.of(context)!.retry,` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing).

#### `barcode_scanner_sheet.dart` (3 offenders)

Current offenders (verbatim):
```
94:                    'Сканер штрихкода',
111:                  tooltip: 'Пӯшидан',
152:              'Наведите камеру на штрихкод',
```

- [ ] **Step 4: Check for reusable existing keys**

Run: `grep -n '"close":' lib/l10n/app_ru.arb`
Expected: `close: "Закрыть"` exists — reuse for line 111's tooltip (this also fixes the pre-existing Tajik-instead-of-Russian bug noted above). No key covers `"Сканер штрихкода"` or `"Наведите камеру на штрихкод"` — confirm with `grep -n 'Сканер штрихкода\|Наведите камеру' lib/l10n/app_ru.arb` (expect no output).

- [ ] **Step 5: Add new keys to `app_ru.arb`**

```json
  "barcodeScannerTitle": "Сканер штрихкода",
  "barcodeScannerHint": "Наведите камеру на штрихкод",
```

- [ ] **Step 6: Replace literals in `barcode_scanner_sheet.dart`**

All literals sit inside `build(BuildContext context)` (a `State` method) — `context` is available directly.

| Find | Replace with |
|---|---|
| `'Сканер штрихкода',` | `AppLocalizations.of(context)!.barcodeScannerTitle,` |
| `tooltip: 'Пӯшидан',` | `tooltip: AppLocalizations.of(context)!.close,` |
| `'Наведите камеру на штрихкод',` | `AppLocalizations.of(context)!.barcodeScannerHint,` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing).

#### `app_dialog.dart` (2 offenders)

Current offenders (verbatim):
```
13:    String confirmText = 'Тасдиқ',
14:    String cancelText = 'Бекор',
```

**Important:** these are **default parameter values** on `AppDialog.show(...)`, a `static` method — default values must be compile-time constants in Dart, so `AppLocalizations.of(context)` cannot be called here directly. Restructure so the defaults are resolved inside `_AppDialogContent.build(BuildContext context)`, which does have `context`:

1. Change the `show` signature: `String? confirmText` and `String? cancelText` (drop the `'Тасдиқ'`/`'Бекор'` literals and the required-ness), and pass them through unchanged (still nullable) to `_AppDialogContent`.
2. Change `_AppDialogContent`'s fields to `final String? confirmText;` / `final String? cancelText;` and its constructor params to match (no longer `required`).
3. In `_AppDialogContent.build(BuildContext context)`, resolve the nullable inputs to their localized defaults before use:
   ```dart
   final l10n = AppLocalizations.of(context)!;
   final resolvedConfirmText = confirmText ?? l10n.confirm;
   final resolvedCancelText = cancelText ?? l10n.cancel;
   ```
4. Replace the two `Text(cancelText, ...)` / `Text(confirmText, ...)` widgets (lines 114 and 143) with `Text(resolvedCancelText, ...)` / `Text(resolvedConfirmText, ...)`.

- [ ] **Step 7: Check for reusable existing keys**

Run: `grep -n '"confirm":\|"cancel":' lib/l10n/app_ru.arb`
Expected: `confirm: "Подтвердить"` and `cancel: "Отмена"` both exist — reuse both as the new localized defaults (replacing the incorrect Tajik defaults `'Тасдиқ'`/`'Бекор'`). **No new keys needed for this file.**

- [ ] **Step 8: Replace literals in `app_dialog.dart`**

| Find | Replace with |
|---|---|
| `String confirmText = 'Тасдиқ',` | `String? confirmText,` |
| `String cancelText = 'Бекор',` | `String? cancelText,` |
| `final String confirmText;` | `final String? confirmText;` |
| `final String cancelText;` | `final String? cancelText;` |
| `required this.confirmText,` | `this.confirmText,` |
| `required this.cancelText,` | `this.cancelText,` |
| `Text(\n                cancelText,` | `Text(\n                resolvedCancelText,` |
| `Text(\n                confirmText,` | `Text(\n                resolvedConfirmText,` |

Add the `final l10n = ...`/`resolvedConfirmText`/`resolvedCancelText` local variables at the top of `_AppDialogContent.build()` as described above, and add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing).

**Verify no call site relies on the old defaults being non-null strings** — run `grep -rn 'AppDialog.show(' lib/ --include="*.dart"` and spot-check that none pass `confirmText`/`cancelText` in a way that assumes non-nullability (they're only ever *passed in*, never read back out, so this should be safe, but confirm before replacing).

#### `impersonation_banner.dart` (2 offenders)

Current offenders (verbatim):
```
101:              'Вы вошли как поддержка Dukon',
124:                : const Text('Завершить сессию'),
```

- [ ] **Step 9: Check for reusable existing keys**

Run: `grep -n 'Вы вошли как поддержка\|Завершить сессию' lib/l10n/app_ru.arb`
Expected: no output — no existing key covers either string; mint both new.

- [ ] **Step 10: Add new keys to `app_ru.arb`**

```json
  "impersonationBannerMessage": "Вы вошли как поддержка Dukon",
  "impersonationBannerEndSession": "Завершить сессию",
```

- [ ] **Step 11: Replace literals in `impersonation_banner.dart`**

Both literals sit inside `build(BuildContext context)` (a `State` method) — `context` is available directly. Drop `const` from both `Text(...)` wrappers (lines 100-108 and 124) since the replacement calls are no longer compile-time constants.

| Find | Replace with |
|---|---|
| `'Вы вошли как поддержка Dukon',` | `AppLocalizations.of(context)!.impersonationBannerMessage,` |
| `: const Text('Завершить сессию'),` | `: Text(AppLocalizations.of(context)!.impersonationBannerEndSession),` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing).

#### `phone_input_field.dart` (1 offender)

Current offender (verbatim):
```
29:        labelText: 'Номер телефона',
```

- [ ] **Step 12: Check for reusable existing keys**

Run: `grep -n '"phone":\|"phoneLabel":' lib/l10n/app_ru.arb`
Expected: `phone: "Номер телефона"` matches exactly (distinct from the shorter `phoneLabel: "Телефон"`) — reuse `phone`. **No new keys needed for this file.**

- [ ] **Step 13: Replace literals in `phone_input_field.dart`**

`build(BuildContext context)` (a `StatelessWidget`) already receives `context` — no threading needed.

| Find | Replace with |
|---|---|
| `labelText: 'Номер телефона',` | `labelText: AppLocalizations.of(context)!.phone,` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing).

#### `app_search_bar.dart` (1 offender)

Current offender (verbatim):
```
14:    this.hint = 'Поиск...',
```

**Important:** same structural problem as `app_dialog.dart` above — `hint` is a **default parameter value** on the widget's `const` constructor, so it must be a compile-time constant and cannot call `AppLocalizations.of(context)`. Restructure:

1. Change `this.hint = 'Поиск...'` to `this.hint` (drop the default; keep the field required or make it nullable — since some call sites may rely on the default, prefer nullable: change `final String hint;` to `final String? hint;` and drop `required`... actually simplest: keep the field name `hint` typed `String?` with no default, and resolve the fallback in `build()`).
2. In `_AppSearchBarState.build(BuildContext context)`, add: `final resolvedHint = widget.hint ?? AppLocalizations.of(context)!.searchPlaceholder;`
3. Replace `hintText: widget.hint,` (line 75) with `hintText: resolvedHint,`.

- [ ] **Step 14: Check for reusable existing keys**

Run: `grep -n '"search":\|"Поиск\.\.\."' lib/l10n/app_ru.arb`
Expected: `search: "Поиск"` exists but does **not** match (missing the ellipsis, different value) — do not reuse. `printerSettingsScanningButton: "Поиск..."` matches this string's exact text but is a completely different meaning (a printer-discovery button, not a search-field placeholder) — coincidental value match, do **not** reuse (different meaning). Mint a new key.

- [ ] **Step 15: Add new keys to `app_ru.arb`**

```json
  "searchPlaceholder": "Поиск...",
```

`searchPlaceholder` is deliberately unprefixed — the default placeholder text for any search field in the app, not specific to one screen.

- [ ] **Step 16: Replace literals in `app_search_bar.dart`**

| Find | Replace with |
|---|---|
| `final String hint;` | `final String? hint;` |
| `this.hint = 'Поиск...',` | `this.hint,` |
| `hintText: widget.hint,` | `hintText: widget.hint ?? AppLocalizations.of(context)!.searchPlaceholder,` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing). Double-check every call site of `AppSearchBar` still compiles with `hint` now nullable — run `grep -rn 'AppSearchBar(' lib/ --include="*.dart"` and confirm none of them read `.hint` back with a non-null assumption (they only set it, so this should be safe).

#### `app_error_widget.dart` (1 offender)

Current offender (verbatim):
```
33:                text: 'Повторить',
```

- [ ] **Step 17: Check for reusable existing keys**

Run: `grep -n '"retry":' lib/l10n/app_ru.arb`
Expected: `retry: "Повторить"` matches exactly — reuse. **No new keys needed for this file.**

- [ ] **Step 18: Replace literals in `app_error_widget.dart`**

`build(BuildContext context)` (a `StatelessWidget`) already receives `context` — no threading needed.

| Find | Replace with |
|---|---|
| `text: 'Повторить',` | `text: AppLocalizations.of(context)!.retry,` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing).

#### `app_bottom_sheet.dart` (1 offender)

Current offender (verbatim):
```
105:                  tooltip: 'Пӯшидан',
```

- [ ] **Step 19: Check for reusable existing keys**

Run: `grep -n '"close":' lib/l10n/app_ru.arb`
Expected: `close: "Закрыть"` exists — reuse (fixes the same Tajik-instead-of-Russian bug as `barcode_scanner_sheet.dart` above; both files should reuse this one existing key, no new mint needed here). **No new keys needed for this file.**

- [ ] **Step 20: Replace literals in `app_bottom_sheet.dart`**

`_AppBottomSheetContent.build(BuildContext context)` (a `StatelessWidget`) already receives `context` — no threading needed.

| Find | Replace with |
|---|---|
| `tooltip: 'Пӯшидан',` | `tooltip: AppLocalizations.of(context)!.close,` |

Add `import 'package:dukonpro/l10n/app_localizations.dart';` to this file (currently missing).

- [ ] **Step 21: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors.

- [ ] **Step 22: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep -E 'offline_banner.dart|barcode_scanner_sheet.dart|app_dialog.dart|impersonation_banner.dart|phone_input_field.dart|app_search_bar.dart|app_error_widget.dart|app_bottom_sheet.dart'` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/widgets/common/barcode_scanner_sheet_golden_test.dart test/presentation/widgets/common/app_dialog_golden_test.dart test/presentation/widgets/common/app_bottom_sheet_golden_test.dart test/presentation/widgets/common/app_search_bar_test.dart test/presentation/widgets/home/impersonation_banner_test.dart --reporter expanded` — expect all passing (verify any golden mismatch against the parent-commit baseline before treating it as a regression). `offline_banner.dart`, `phone_input_field.dart`, and `app_error_widget.dart` have no dedicated test file — rely on `flutter analyze` plus a manual sanity check via the `run` skill if available.

- [ ] **Step 23: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart l10n_untranslated.json \
  lib/presentation/widgets/common/offline_banner.dart \
  lib/presentation/widgets/common/barcode_scanner_sheet.dart \
  lib/presentation/widgets/common/app_dialog.dart \
  lib/presentation/widgets/home/impersonation_banner.dart \
  lib/presentation/widgets/common/phone_input_field.dart \
  lib/presentation/widgets/common/app_search_bar.dart \
  lib/presentation/widgets/common/app_error_widget.dart \
  lib/presentation/widgets/common/app_bottom_sheet.dart
git commit -m "fix(app): migrate common widgets misc hardcoded strings to AppLocalizations"
```

---
### Task 29: Final allow-list regeneration + full verification

**Files:**
- Modify: `tool/i18n-allowlist.txt`

- [ ] **Step 1: Regenerate the allow-list one last time**

Run: `dart run tool/check_i18n.dart --dump-allowlist`

This captures the final state: the 6 deliberate `settings_page.dart`
proper-noun exceptions (already hand-added in a prior, already-merged
project, and confirmed present in this fresh dump too — if
`--dump-allowlist` overwrites the file and loses the comment header,
re-add that comment block by hand after this command, since
`--dump-allowlist` only writes the raw entries), plus every
pre-existing, still-unmigrated string outside this plan's 61 files
(the 6 Bloc files deferred as Track 3, and anything discovered mid-plan
that turned out to be genuinely out of scope — untouched, unrelated to
this project).

- [ ] **Step 2: Verify the lint passes clean**

Run: `dart run tool/check_i18n.dart`
Expected: `check_i18n: scanned <N> files, no new hardcoded Cyrillic strings.`, exit 0.

- [ ] **Step 3: Confirm all 61 files are individually clean**

Run each of the following and confirm zero output for all sixty-one:
```bash
dart run tool/check_i18n.dart 2>&1 | grep subscription_page.dart
dart run tool/check_i18n.dart 2>&1 | grep reports_page.dart
dart run tool/check_i18n.dart 2>&1 | grep product_detail_page.dart
dart run tool/check_i18n.dart 2>&1 | grep receipt_template_page.dart
dart run tool/check_i18n.dart 2>&1 | grep pos_checkout_page.dart
dart run tool/check_i18n.dart 2>&1 | grep transaction_detail_page.dart
dart run tool/check_i18n.dart 2>&1 | grep zakat_settings_page.dart
dart run tool/check_i18n.dart 2>&1 | grep zakat_calculator_page.dart
dart run tool/check_i18n.dart 2>&1 | grep finance_dashboard_page.dart
dart run tool/check_i18n.dart 2>&1 | grep sales_history_page.dart
dart run tool/check_i18n.dart 2>&1 | grep sales_filter_sheet.dart
dart run tool/check_i18n.dart 2>&1 | grep customer_detail_page.dart
dart run tool/check_i18n.dart 2>&1 | grep product_list_page.dart
dart run tool/check_i18n.dart 2>&1 | grep notification_settings_page.dart
dart run tool/check_i18n.dart 2>&1 | grep refund_page.dart
dart run tool/check_i18n.dart 2>&1 | grep add_adjustment_page.dart
dart run tool/check_i18n.dart 2>&1 | grep add_investment_page.dart
dart run tool/check_i18n.dart 2>&1 | grep add_expense_page.dart
dart run tool/check_i18n.dart 2>&1 | grep offline_mode_page.dart
dart run tool/check_i18n.dart 2>&1 | grep kkm_settings_page.dart
dart run tool/check_i18n.dart 2>&1 | grep scanner_settings_page.dart
dart run tool/check_i18n.dart 2>&1 | grep edit_profile_page.dart
dart run tool/check_i18n.dart 2>&1 | grep telegram_bot_settings_page.dart
dart run tool/check_i18n.dart 2>&1 | grep language_settings_page.dart
dart run tool/check_i18n.dart 2>&1 | grep categories_page.dart
dart run tool/check_i18n.dart 2>&1 | grep add_product_step3_page.dart
dart run tool/check_i18n.dart 2>&1 | grep add_product_step1_page.dart
dart run tool/check_i18n.dart 2>&1 | grep permission_toggle_row.dart
dart run tool/check_i18n.dart 2>&1 | grep staff_detail_page.dart
dart run tool/check_i18n.dart 2>&1 | grep staff_list_page.dart
dart run tool/check_i18n.dart 2>&1 | grep staff_card.dart
dart run tool/check_i18n.dart 2>&1 | grep receipt_widget.dart
dart run tool/check_i18n.dart 2>&1 | grep sale_success_page.dart
dart run tool/check_i18n.dart 2>&1 | grep cash_payment_page.dart
dart run tool/check_i18n.dart 2>&1 | grep receipt_preview_page.dart
dart run tool/check_i18n.dart 2>&1 | grep currencies_page.dart
dart run tool/check_i18n.dart 2>&1 | grep expense_card.dart
dart run tool/check_i18n.dart 2>&1 | grep investment_list_page.dart
dart run tool/check_i18n.dart 2>&1 | grep period_selector.dart
dart run tool/check_i18n.dart 2>&1 | grep profit_summary_card.dart
dart run tool/check_i18n.dart 2>&1 | grep stat_summary_row.dart
dart run tool/check_i18n.dart 2>&1 | grep zakat_history_page.dart
dart run tool/check_i18n.dart 2>&1 | grep zakat_breakdown_card.dart
dart run tool/check_i18n.dart 2>&1 | grep current_shift_card.dart
dart run tool/check_i18n.dart 2>&1 | grep open_shift_page.dart
dart run tool/check_i18n.dart 2>&1 | grep shift_card.dart
dart run tool/check_i18n.dart 2>&1 | grep supplier_list_page.dart
dart run tool/check_i18n.dart 2>&1 | grep stock_intake_page.dart
dart run tool/check_i18n.dart 2>&1 | grep customer_debts_page.dart
dart run tool/check_i18n.dart 2>&1 | grep payment_form.dart
dart run tool/check_i18n.dart 2>&1 | grep notifications_page.dart
dart run tool/check_i18n.dart 2>&1 | grep month_selector.dart
dart run tool/check_i18n.dart 2>&1 | grep sale_list_item.dart
dart run tool/check_i18n.dart 2>&1 | grep offline_banner.dart
dart run tool/check_i18n.dart 2>&1 | grep barcode_scanner_sheet.dart
dart run tool/check_i18n.dart 2>&1 | grep app_dialog.dart
dart run tool/check_i18n.dart 2>&1 | grep impersonation_banner.dart
dart run tool/check_i18n.dart 2>&1 | grep phone_input_field.dart
dart run tool/check_i18n.dart 2>&1 | grep app_search_bar.dart
dart run tool/check_i18n.dart 2>&1 | grep app_error_widget.dart
dart run tool/check_i18n.dart 2>&1 | grep app_bottom_sheet.dart
```

Note: `settings_page.dart` is deliberately NOT in this list — its 6
remaining allow-list entries are the proper-noun exceptions from the
prior project, expected to persist, not offenders to clear. The 6 Bloc
files (`printer_bloc.dart`, `expense_bloc.dart`, `zakat_bloc.dart`,
`settings_bloc.dart`, `subscription_bloc.dart`, `debt_bloc.dart`) are
also deliberately NOT in this list — Track 3, out of scope, their
allow-list entries are expected to remain.

- [ ] **Step 4: Full analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Full test suite**

Run: `flutter test --reporter expanded`
Expected: no NEW failures relative to the pre-existing baseline (18
known golden-image pixel-diff failures from the macOS/Linux tolerance
gap documented in `test/flutter_test_config.dart` — cross-check any
local golden failure against real CI on Linux before treating it as a
regression from this work, using the throwaway-worktree-at-parent-commit
technique established throughout this branch's predecessor).

- [ ] **Step 6: Commit**

```bash
git add tool/i18n-allowlist.txt
git commit -m "fix(app): final allow-list regeneration after ADR-0002 Track 2 migration"
```

No further commit for this task beyond this — it's the checkpoint
before the final whole-branch review (with special attention to
cross-task ARB key duplication, given 28 independently-dispatched
migration tasks each did their own live ARB reuse-check against a
moving target — the prior, smaller project already caught exactly one
such duplicate in its own final review), pushing, and watching real CI
go green, then `superpowers:finishing-a-development-branch`.
