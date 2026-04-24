# Mobile i18n Backlog — Sprint 2 Follow-up

**Origin:** Sprint 1 Task 6 (prod-blocker Mobile #7) downgraded from BLOCKER to HIGH on 2026-04-24.

**Reason:** Full scan revealed 396 hardcoded Russian `Text('...')` strings across 79 presentation files — 4× the originally-estimated 100+. Fixing all of them would exceed Sprint 1's 1-week timebox. App can ship ru-only at first launch and finish tg/uz in a dedicated post-launch sprint.

## Scope

- **396** `Text('Russian')` call-sites
- **79** presentation files (pages + widgets)
- Current `.arb` files already contain ~900 keys (ru/tg/uz at parity). New keys needed: ~150-200 unique strings (many pages duplicate common labels like "Сохранить", "Удалить", "Выбрать период", etc.)

## Top-20 highest-volume files (where to start)

| Count | File |
|---|---|
| 21 | `lib/presentation/pages/finance/reports_page.dart` |
| 16 | `lib/presentation/pages/settings/receipt_template_page.dart` |
| 16 | `lib/presentation/pages/product/product_detail_page.dart` |
| 14 | `lib/presentation/pages/settings/subscription_page.dart` |
| 13 | `lib/presentation/pages/shifts/shifts_page.dart` |
| 11 | `lib/presentation/pages/product/import_products_page.dart` |
| 11 | `lib/presentation/pages/pos/pos_checkout_page.dart` |
| 11 | `lib/presentation/pages/inventory/inventory_count_page.dart` |
| 10 | `lib/presentation/pages/zakat/zakat_calculator_page.dart` |
| 10 | `lib/presentation/pages/settings/settings_page.dart` |
| 10 | `lib/presentation/pages/settings/scanner_settings_page.dart` |
| 10 | `lib/presentation/pages/pos/credit_sale_page.dart` |
| 9 | `lib/presentation/pages/shifts/z_report_page.dart` |
| 9 | `lib/presentation/pages/settings/offline_mode_page.dart` |
| 9 | `lib/presentation/pages/debt/debts_overview_page.dart` |
| 8 | `lib/presentation/pages/zakat/zakat_settings_page.dart` |
| 8 | `lib/presentation/pages/finance/credits_page.dart` |
| 7 | `lib/presentation/pages/settings/printer_settings_page.dart` |
| 7 | `lib/presentation/pages/sales/transaction_detail_page.dart` |
| 7 | `lib/presentation/pages/sales/refund_page.dart` |

Full list: `/tmp/i18n-scope.txt` (regenerate via `grep -rlE "Text\('[А-Яа-яЁё]" app/lib/presentation | xargs -I{} sh -c 'printf "%3d %s\n" "$(grep -cE \"Text.*[А-Я]\" {})" "{}"' | sort -rn`).

## Suggested Sprint 2 approach

Mirror the 5B.2.b / Sprint 6-7 pattern:

1. **Cluster by feature** (POS / Product / Finance / Settings / Shifts / Zakat / Misc).
2. **One subagent per cluster** — dedup strings against existing arb keys first (`back`, `close`, `save`, etc. are already there), then add new keys + migrate call-sites.
3. **Translation quality** — ru verbatim, tg/uz best-effort consistent with existing arb patterns. Flag uncertain translations for native-speaker review.
4. **Acceptance per cluster:** `flutter analyze lib/ → 0 issues`, `flutter test → 363/363 pass`, commit as `refactor(l10n): migrate <cluster> to AppLocalizations`.

Estimated effort: 1-2 developer-days via subagents. Outside Sprint 1 because it doesn't gate store submission (store accepts ru-only).

## Shipping consequences

- **Play Store / App Store submission:** no gate. Both stores accept ru-only listings.
- **User experience for tg/uz locale users:** they will see Russian text across these 79 files. Acceptable for initial launch (target market is ru-primary), but should be closed before post-launch MAU growth into non-ru regions.
- **Risk of release:** zero. Only UX quality degradation for a subset of users.

## Recommendation

Complete in Sprint 2 (post-launch, week 2-3). No hard deadline from stores or compliance.
