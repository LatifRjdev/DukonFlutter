# Design — Spec E "Flutter UX Cleanup" (P2/P3 from G.2)

**Date:** 2026-05-16
**Scope:** 5 sub-sections — zakat_calculator polish, zakat_history pagination/refresh, zakat_settings validators + clock injection, investment_bloc UX flicker + l10n + tests, dead `stock-movements.controller.ts` cleanup. Plus a small backend slice to add `ZakatSettings.cashOnHand` so the calculator's "include cash" flag has a real value to read.
**Decisions:** All auto-mode (P2/P3 cluster, no business decisions needed).

## Summary

The G.2 audit (commit `a6cd50e`) flagged 16 P2 + 13 P3 findings;
Specs A and D resolved the P1 cluster + structural P2s on
backend. This spec closes the user-facing UX cluster + 1 backend
slice required to make the cash-on-hand flag functional. After
this spec the G.2 backlog is fully drained.

## Sub-section A — `zakat_calculator_page.dart` polish + cashOnHand backend

### A.1: Hardcoded "2.5%" UI strings

**File:** `app/lib/presentation/pages/zakat/zakat_calculator_page.dart`

Two literal strings include `2.5%`:
- Line 100: `'Закят — 2.5% от имущества, хранящегося 1 лунный год'`
- Line 197: `'СУММА ЗАКЯТА (2.5%):'`

Replace with templated strings reading `state.calculation.zakatRate`:
- Line 100: `'Закят — ${calc.zakatRate.toStringAsFixed(1)}% от имущества, хранящегося 1 лунный год'`
- Line 197: `'СУММА ЗАКЯТА (${calc.zakatRate.toStringAsFixed(1)}%):'`

If `calc.zakatRate` is on `Calculation` entity but not exposed,
add to entity + remote-datasource mapping.

### A.2: Cash-on-hand input — backend + UI slice

**Backend changes:**
- `api/prisma/schema.prisma`: `ZakatSettings.cashOnHand Decimal @default(0) @db.Decimal(12,2)`
- New migration `<ts>_zakat_cash_on_hand` adds the column + CHECK `>= 0`
- `api/src/modules/zakat/dto/upsert-zakat-settings.dto.ts`: add `cashOnHand?: number` with `@IsOptional()` `@IsNumber()` `@Min(0)`
- `api/src/modules/zakat/zakat.service.ts` `calculate()`:
  - Read `settings.cashOnHand` instead of hardcoded `0`
  - When `settings.includeCash === false`, treat as 0
  - Add to `breakdown.cashOnHand` returned to client (already present in shape)

**UI changes:** input lives on `zakat_settings_page.dart` (sub-section
C), not the calculator. Calculator just consumes
`calc.breakdown.cashOnHand` for the totals row.

### A.3: `_formatPrice` hardcodes TJS

**File:** `app/lib/presentation/pages/zakat/zakat_calculator_page.dart`
line 23-26 — change signature `_formatPrice(double v)` to
`_formatPrice(double v, String currency)` and pass
`store.currency` from `BlocBuilder<StoreBloc, StoreState>` at the
call sites.

If `StoreBloc.state.currency` is missing (state surface check),
lift it via `(state as StoreLoaded).store.currency`.

## Sub-section B — `zakat_history_page.dart`

### B.1: Pagination

Page currently loads all payments. Add cursor-based load-more:
- `ZakatPaymentsRequested` event gains `int page = 1, int limit = 20`
- `ZakatBloc` handler passes them to remote datasource
- API endpoint `GET /api/stores/:storeId/zakat/payments`: confirm
  it accepts `?page=&limit=` query params; if not, add. (Likely
  already supports — most other admin lists do.)
- `ZakatLoaded` state gains `int total, int totalPages, int currentPage`
- Page UI: render list + "Загрузить ещё" button at bottom when
  `currentPage < totalPages`. Tap dispatches `ZakatPaymentsRequested(page: currentPage + 1)`.

### B.2: RefreshIndicator

Wrap the ListView in `RefreshIndicator` whose `onRefresh` callback
dispatches `ZakatPaymentsRequested(page: 1)` and awaits the next
emission via a Completer or by listening to the bloc state.

Standard Flutter pattern; ~10 lines.

### B.3: Client-side sort assertion

Server returns sorted (verify in service: `orderBy: { paidAt: 'desc' }`).
Add a unit test in `zakat.service.spec.ts` asserting the order. No
client code change.

## Sub-section C — `zakat_settings_page.dart`

### C.1: Validator on nisab field

The `nisabAmount` `TextFormField` currently has only
`keyboardType: TextInputType.number` — no validator. Add:
```dart
validator: (v) {
  if (v == null || v.isEmpty) return 'Обязательное поле';
  final parsed = double.tryParse(v);
  if (parsed == null) return 'Введите число';
  if (parsed < 0) return 'Не может быть отрицательным';
  return null;
},
```

Same for `cashOnHand` (added in A.2).

### C.2: Currency from store

Display strings hardcode `' TJS'`:
- `suffixText: 'TJS'`
- `'~ 78,200 TJS'`

Pull from `StoreBloc.state` and substitute. If StoreBloc isn't
already wrapped around this page via `MultiBlocProvider`, add it
at the route level (page is opened from settings menu — verify
parent providers).

### C.3: `_pickDate` uses raw `DateTime.now()`

Apply the established `now: DateTime Function()?` injection pattern
(used in CurrentShiftCard, ShiftCard, CreditSalePage,
AddExpensePage, AddInvestmentPage). Page constructor accepts
`now`; `_pickDate` uses `(widget.now ?? DateTime.now)()`. Tests
(if any golden) freeze the clock.

## Sub-section D — `investment_bloc/`

### D.1: UI flicker on filter tap

`InvestmentLoading()` clears the previous list, forcing the page
to render the spinner branch. Fix by:
- Add `bool isRefreshing` field to `InvestmentLoaded`
- Bloc `_onListRequested`:
  ```dart
  if (state is InvestmentLoaded) {
    emit((state as InvestmentLoaded).copyWith(isRefreshing: true));
  } else {
    emit(InvestmentLoading());
  }
  // ... fetch ...
  emit(InvestmentLoaded(..., isRefreshing: false));
  ```
- Page consumes `isRefreshing` to render a small spinner overlay
  on top of the list, instead of replacing the whole body.

### D.2: `InvestmentActionSuccess` overwritten

Bloc currently does:
```dart
emit(InvestmentActionSuccess('Вложение добавлено'));
add(InvestmentListRequested(storeId: event.storeId)); // synchronous → emits Loading right away
```

`BlocBuilder` consumers miss the Success state because it's
overwritten in the same micro-task. Fix:
```dart
emit(InvestmentActionSuccess(InvestmentL10n.created));
await Future<void>.delayed(Duration.zero);
add(InvestmentListRequested(storeId: event.storeId));
```

(Or: `await Future.microtask(() => add(...))`.)

`BlocListener` consumers see every state, so the snackbar already
fires. The fix matters for `BlocBuilder` consumers (e.g. an
indicator that flashes for the success state).

### D.3: No `investment_bloc_test.dart`

New file `app/test/presentation/blocs/investment/investment_bloc_test.dart`
following `auth_bloc_test.dart` / `debt_bloc_test.dart` pattern.
Tests:
1. `InvestmentListRequested` → emits Loading then Loaded on success
2. `InvestmentListRequested` when state is already Loaded → emits
   Loaded(isRefreshing: true) then Loaded(isRefreshing: false)
   (no Loading flicker)
3. `InvestmentSummaryRequested` → emits Loading then SummaryLoaded
4. `InvestmentCreateRequested` happy → emits ActionSuccess then
   triggers list refresh
5. `InvestmentDeleteRequested` failure → emits Error
6. Filter switch (`status: 'COMPLETED'`) → bloc passes filter to repo

### D.4: Hardcoded Russian success strings (l10n)

Bloc emits:
- `'Вложение добавлено'`
- `'Вложение обновлено'`
- `'Вложение удалено'`

Move to l10n. Two options:

**Option A (recommended): emit l10n KEYS, page resolves**
- Add 3 keys to `app_ru.arb` / `app_tg.arb` / `app_uz.arb`:
  `investmentCreated`, `investmentUpdated`, `investmentDeleted`
- Bloc emits `InvestmentActionSuccess(InvestmentL10nKey.created)`
  (enum-based, type-safe)
- Page's `BlocListener` resolves: `AppLocalizations.of(context)!.investmentCreated`

**Option B: emit raw key string**
- Bloc emits `InvestmentActionSuccess('investmentCreated')`
- Page maps string → AppLocalizations getter

Recommend A (enum-safe). Adds `app/lib/presentation/blocs/investment/investment_l10n_key.dart` — small enum file.

## Sub-section E — Dead code cleanup

`api/src/modules/products/stock-movements.controller.ts` is
declared `@Controller('stores/:storeId/stock-movements')` but
**not registered in any module** (per Spec B finding). The "real"
stock-movement endpoint lives on `ProductsController` at
`POST /stores/:storeId/products/:productId/stock-movements`.

Action: `git rm api/src/modules/products/stock-movements.controller.ts`.

Verify before deleting:
```bash
grep -rn "StockMovementsController\b" api/src/modules/
```
Expected: only the file itself contains the class definition. If
it appears in any `imports: [...]` or `controllers: [...]` array,
escalate — file is reachable.

## Files touched

**Backend (sub-section A.2 + B.3 + E):**
- `api/prisma/schema.prisma`
- `api/prisma/migrations/<ts>_zakat_cash_on_hand/migration.sql`
- `api/src/modules/zakat/dto/upsert-zakat-settings.dto.ts`
- `api/src/modules/zakat/zakat.service.ts`
- `api/src/modules/zakat/zakat.service.spec.ts`
- DELETE: `api/src/modules/products/stock-movements.controller.ts`

**Flutter:**
- `app/lib/presentation/pages/zakat/zakat_calculator_page.dart`
- `app/lib/presentation/pages/zakat/zakat_settings_page.dart`
- `app/lib/presentation/pages/zakat/zakat_history_page.dart`
- `app/lib/presentation/blocs/zakat/zakat_event.dart`
- `app/lib/presentation/blocs/zakat/zakat_state.dart`
- `app/lib/presentation/blocs/zakat/zakat_bloc.dart`
- `app/lib/presentation/blocs/investment/investment_state.dart`
- `app/lib/presentation/blocs/investment/investment_bloc.dart`
- `app/lib/presentation/blocs/investment/investment_l10n_key.dart` (new)
- `app/lib/presentation/pages/finance/investment_list_page.dart`
- `app/lib/l10n/app_ru.arb` + `app_tg.arb` + `app_uz.arb`
- `app/lib/l10n/app_localizations*.dart` (regenerated by `flutter gen-l10n`)
- `app/test/presentation/blocs/investment/investment_bloc_test.dart` (new)

## Acceptance

- API: `npm test` ≥223 unit (was 222, +1 if needed for cashOnHand calc), `npm run test:e2e` ≥11
- Flutter: `dart analyze lib/` 0, `flutter test` ≥441 (was 435, +6 investment_bloc tests; goldens may need re-baseline if zakat pages have any — verify)
- 0 tsc errors
- Live probes:
  - Open zakat calculator → "Закят — X.X%" matches `settings.zakatRate`
  - Set cash-on-hand=1000 → next calculator load shows totalAssets += 1000
  - Open zakat history → pull-to-refresh works + "Загрузить ещё" appears with >20 records
  - Open zakat settings on USD store → suffix shows "USD" not "TJS"
  - Investment list filter tap → no flicker, smooth swap
  - Investment add → snackbar in current locale (RU/TG/UZ)

## Out of scope

- Multi-currency conversion (only PROPAGATES `store.currency`; no
  per-currency rate math)
- Backfilling existing `ZakatSettings.cashOnHand` rows (default 0
  via migration default)
- Investment ROI math (audit confirmed not present; future feature)
- Sync queue for zakat reads
- Refactoring `InvestmentSummary` (G.2 audit said it's OK)
- Full l10n audit beyond the 3 investment-bloc strings flagged

## Risks

- **`flutter gen-l10n` regen** may produce git-tracked diffs in
  `app_localizations*.dart`. If those files are gitignored, only
  the ARB files commit. If not, commit the regen as a separate
  chore commit.
- **Pagination assumes server endpoint accepts `page/limit`** —
  verify; if not, add to controller.
- **`StoreBloc.state` shape may not expose currency directly** —
  verify in step-1 of the implementation; lift via state.store.currency
  if needed.
- **`investment_l10n_key.dart` enum file** is a tiny new file
  (~10 lines). Reviewer might prefer raw strings for simplicity.
  Both options work; A is type-safe.

## Test results gate

After implementation:
- API: `npm test` (≥223 unit) + `npm run test:e2e` (≥11)
- App: `flutter test` (≥441) + `dart analyze lib/` (0)
- 0 tsc errors
- 1 new schema migration committed
- 1 dead controller file deleted
- 6 new bloc tests committed

## Ship plan

~1.5 days. 5 sub-sections.
- **E first** (~5 min — just `git rm` + verify)
- **A.2 backend slice** (~30 min — schema + migration + service)
- **A.1 + A.3 + C.1 + C.2 + C.3** (Flutter polish, ~30 min each)
- **B.1 + B.2 + B.3** (pagination + refresh, ~45 min)
- **D.1 + D.2** (bloc UX, ~30 min)
- **D.3** (bloc tests, ~45 min)
- **D.4** (l10n keys + bloc/page wiring, ~30 min)
- Final gate
