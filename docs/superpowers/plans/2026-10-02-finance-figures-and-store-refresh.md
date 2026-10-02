# Correct Finance Figures and Store-Switch Refresh — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every finance figure the app shows match reality, and make switching stores refresh the screens.

**Architecture:** The API gains a shared cost-of-goods-sold aggregate and returns the three fields the app already asks for but never receives. The app's gross/net profit formulas are corrected to use it. Separately, the session-keyed provider tree from `2082dc8` gains a second level keyed on the selected store.

**Tech Stack:** NestJS + Prisma + Jest (`api/`), Flutter + flutter_bloc (`app/`). API on `:4455` under prefix `api`, served from compiled `dist/` so changes need `npm run build` plus a restart. Android emulator `emulator-5554`. Postgres container `dukonpro-db` on `:5435`.

**Spec:** `docs/superpowers/specs/2026-10-02-finance-figures-and-store-refresh-design.md`

---

## The seeded data these tasks verify against

Both QA stores already contain known data, so every figure below is checkable rather than merely plausible. **Do not reseed.**

| | value |
|---|---|
| 10 products | cost `10×i`, price `25×i`, i = 1..10, 50 units each |
| 3 sales | p1×2 + p2×1, p3×3, p10×1 |
| 2 expenses | RENT 300, TRANSPORT 120 |
| **revenue** | **575** |
| **COGS** | **230** |
| **expenses** | **420** |
| **gross profit** | **345** (575 − 230) |
| **net profit** | **−75** (345 − 420) |
| sales count / avg check | 3 / 191.67 |

Stores: BUSINESS `ccb89fc3-95e9-47d0-9437-8c1079cbc4c2`, PREMIUM `edcba5c4-b020-4665-ac9f-097489a32e6b`.
Logins: `+992920777001` / `x8R9s5msWiEzBYWL`, `+992920777002` / `yfgYAi5oHqm38w8x`.

## Facts established before writing this plan

- `SaleItem` snapshots `costPrice` (`schema.prisma`). **All 17 sale items across all 6 stores with sales have it populated** — zero NULLs — so COGS is correct retroactively. Verified by SQL, not assumed.
- `SELECT SUM((quantity - "refundedQuantity") * "costPrice")` over the BUSINESS store's items returns exactly **230.00**.
- `finances.service.ts:68-86` — `getOverview` computes `todayExpenses` internally at `:69` but **does not return it**; `todayProfit` at `:74` is `todayRevenue - todayExpenses`.
- `finances.service.ts:230-241` — `getSummary` returns only `salesByDay`, `expensesByDay`, `expensesByCategory`, `period`, `startDate`, `endDate`. No totals at all.
- `app/lib/data/datasources/remote/dashboard_remote_datasource.dart:50-51` reads `todayCost` (fallback `costOfGoods`) and `todayExpenses` (fallback `expenses`) — all four absent, so both default to 0.
- `app/lib/data/datasources/remote/finance_remote_datasource.dart:50-67` sums `salesByDay`/`expensesByDay` itself and sets `profit: totalIncome - totalExpenses` at `:65`.
- `app/lib/domain/entities/finance_summary.dart` — `FinanceSummary` has `totalIncome`, `totalExpenses`, `profit`, `salesCount`, `avgCheck`, `topProducts`. **No cost field** — one must be added.
- `app/lib/presentation/pages/finance/finance_dashboard_page.dart:200` renders `s.profit` as «Валовая прибыль»; `:211` renders `s.profit - s.totalExpenses` as «Чистая прибыль».
- `app/lib/app.dart` after `2082dc8`: `_sessionKeyOf(AuthState)` at `:44`; root `MultiBlocProvider` holds `AuthBloc` + `SettingsBloc`; the keyed `MultiBlocProvider` with **24** providers sits inside `MaterialApp.router`'s `builder:` at `:97`, behind a `BlocBuilder<AuthBloc, AuthState>` at `:108`.
- `StoreState` has `StoreLoaded({required stores, selectedStore})` — `selectedStore` is nullable.

## File structure

| File | Responsibility | Task |
|---|---|---|
| `api/src/modules/finances/finances.service.ts` | COGS helper; overview, summary **and dashboard** gain fields | 1, 2 |
| `api/src/modules/finances/finances.service.spec.ts` | **new** — pins COGS and the new fields | 1, 2 |
| `app/lib/domain/entities/finance_summary.dart` | gains `totalCost` | 3 |
| `app/lib/data/datasources/remote/finance_remote_datasource.dart` | reads `cogs` from **both** summary and dashboard | 3 |
| `app/lib/presentation/pages/finance/finance_dashboard_page.dart:200,211` | corrected formulas | 3 |
| `app/test/presentation/finance_profit_test.dart` | **new** — pins both formulas | 3 |
| `app/lib/app.dart` | two-level keying | 4 |

---

## Hard constraints

- **Do NOT reseed or delete the QA data.** Every verification step depends on it.
- **Do NOT run `dart format`** (Dart 3.10 tall style rewrites the repo) and **do NOT regenerate goldens**.
- **Do NOT modify the Prisma schema** or create a migration — `SaleItem.costPrice` already exists.
- **Do NOT hand-edit `app/lib/l10n/app_localizations*.dart`** or the ARB.
- **`npx tsc --noEmit` at 0 errors is the gate**, not lint — the repo lint baseline is ~3572 problems. **Green tests do not imply clean types**; run `tsc` separately.
- **Do NOT run `git pull`/`rebase`/`push`.** Commit only.

---

## Task 1: COGS, and the dashboard's missing fields

**Files:**
- Modify: `api/src/modules/finances/finances.service.ts`
- Create: `api/src/modules/finances/finances.service.spec.ts`

- [ ] **Step 1: Write the failing test**

Create `api/src/modules/finances/finances.service.spec.ts`:

```ts
import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { FinancesService } from './finances.service';
import { PrismaService } from '../../prisma/prisma.service';

// The dashboard reads todayCost and todayExpenses; the API sent neither, so
// both cards rendered 0 for every store, always. With real expenses of 420 the
// card showed 0 — and the same screen showed a profit that already had those
// 420 deducted, so its own numbers did not add up.
function makePrisma(opts: { revenue: number; expenses: number; cogs: number }) {
  return {
    sale: {
      aggregate: jest.fn(async () => ({
        _sum: { total: opts.revenue },
        _count: 3,
        _avg: { total: opts.revenue / 3 },
      })),
      findMany: jest.fn(async () => []),
    },
    expense: {
      aggregate: jest.fn(async () => ({ _sum: { amount: opts.expenses } })),
      groupBy: jest.fn(async () => []),
    },
    product: { count: jest.fn(async () => 10) },
    saleItem: {
      aggregate: jest.fn(async () => ({ _sum: { cost: opts.cogs } })),
    },
    $queryRaw: jest.fn(async () => [{ count: BigInt(0), cogs: opts.cogs }]),
  };
}

async function build(prisma: any) {
  const ref = await Test.createTestingModule({
    providers: [FinancesService, { provide: PrismaService, useValue: prisma }],
  }).compile();
  return ref.get(FinancesService);
}

describe('FinancesService.getOverview', () => {
  it('returns todayCost and todayExpenses, which the dashboard needs', async () => {
    const prisma = makePrisma({ revenue: 575, expenses: 420, cogs: 230 });
    const service = await build(prisma);

    const r: any = await service.getOverview('store-1', { period: 'today' } as any);

    expect(r.todayRevenue).toBe(575);
    expect(r.todayCost).toBe(230);
    expect(r.todayExpenses).toBe(420);
  });

  it('reports profit net of BOTH cost of goods and expenses', async () => {
    // Previously todayProfit was revenue - expenses, ignoring COGS entirely.
    // The dashboard shows revenue above three cards (profit / cost / expenses),
    // so the numbers have to add up: 575 - 230 - 420 = -75.
    const prisma = makePrisma({ revenue: 575, expenses: 420, cogs: 230 });
    const service = await build(prisma);

    const r: any = await service.getOverview('store-1', { period: 'today' } as any);

    expect(r.todayProfit).toBe(-75);
    expect(r.todayRevenue - r.todayCost - r.todayExpenses).toBe(r.todayProfit);
  });
});
```

The Prisma fake's shape must match however you implement the aggregate — if you use `$queryRaw`, make the fake return the row shape you read. **Adjust the fake to the implementation, never the assertions.**

- [ ] **Step 2: Run it and confirm both fail**

```bash
cd api
npm test -- finances.service.spec.ts
```
Expected: both FAIL — `todayCost` undefined, `todayExpenses` undefined, `todayProfit` 155 not −75.

- [ ] **Step 3: Add the COGS helper**

In `api/src/modules/finances/finances.service.ts`, add a private method. Place it next to `getDateRange` so the period helpers sit together:

```ts
  /// Cost of goods sold for a period.
  ///
  /// Reads SaleItem.costPrice — the cost SNAPSHOT taken when the sale was
  /// made — not the product's current costPrice. Re-pricing a product must not
  /// rewrite the margin on sales that already happened.
  ///
  /// `refundedQuantity` is cumulative per line, so subtracting it drops
  /// refunded units out without a second query.
  ///
  /// A NULL costPrice contributes 0. None exist today (verified across every
  /// store), but an import path that skipped the snapshot would silently
  /// understate COGS — and 0 is the only honest default, since the historical
  /// cost cannot be reconstructed.
  private async computeCogs(
    storeId: string,
    startDate: Date,
    endDate: Date,
  ): Promise<number> {
    const rows = await this.prisma.$queryRaw<[{ cogs: string | null }]>`
      SELECT COALESCE(
        SUM((si."quantity" - si."refundedQuantity") * si."costPrice"), 0
      )::text AS cogs
      FROM sale_items si
      JOIN sales s ON s.id = si."saleId"
      WHERE s."storeId" = ${storeId}
        AND s."status" = 'COMPLETED'
        AND s."createdAt" >= ${startDate}
        AND s."createdAt" <= ${endDate}
    `;
    return Number(rows[0]?.cogs ?? 0);
  }
```

- [ ] **Step 4: Use it in `getOverview`**

Add `this.computeCogs(storeId, startDate, endDate)` as another entry in the existing `Promise.all` at `:24`, destructuring it as `todayCost` alongside the other results. Then replace the return block at `:71-76`:

```ts
    const todayRevenue = Number(salesAggregate._sum.total || 0);
    const todayExpenses = Number(expensesAggregate._sum.amount || 0);

    return {
      todayRevenue,
      todayCost,
      todayExpenses,
      todaySalesCount: salesAggregate._count,
      // Net of BOTH cost of goods and expenses. This previously ignored COGS,
      // which made the dashboard self-contradictory: it showed a profit with
      // expenses already deducted next to an expenses card reading 0.
      todayProfit: todayRevenue - todayCost - todayExpenses,
      totalProducts,
      lowStockProducts: Number(lowStockProducts[0]?.count ?? 0),
```

Leave `recentSales` and the closing brace untouched.

- [ ] **Step 5: Run the tests**

```bash
npm test -- finances.service.spec.ts
```
Expected: both pass.

- [ ] **Step 6: Full suite and typecheck**

```bash
npm test
npx tsc --noEmit
```
Expected: green, `tsc` 0 errors. Report counts.

- [ ] **Step 7: Verify against the real seeded store**

```bash
npm run build
```
Restart the API the way it is currently running (note its cwd and stdio first), then:

```bash
T=$(curl -s -X POST http://localhost:4455/api/auth/login -H "Content-Type: application/json" \
  -d '{"phone":"+992920777001","password":"x8R9s5msWiEzBYWL"}' \
  | python3 -c "import json,sys;print(json.load(sys.stdin)['accessToken'])")
curl -s "http://localhost:4455/api/stores/ccb89fc3-95e9-47d0-9437-8c1079cbc4c2/finances/overview?period=today" \
  -H "Authorization: Bearer $T" | python3 -m json.tool
```
Expected: `todayRevenue 575`, `todayCost 230`, `todayExpenses 420`, `todayProfit -75`, `todaySalesCount 3`, `totalProducts 10`. **These exact numbers are the deliverable** — a shape that is right but a figure that is wrong means the aggregate is wrong.

- [ ] **Step 8: Commit**

```bash
git add api/src/modules/finances/finances.service.ts api/src/modules/finances/finances.service.spec.ts
git commit -m "fix(api): return cost of goods and expenses from finances/overview

The app's dashboard reads todayCost and todayExpenses; the API sent
neither, nor their fallbacks, so both cards rendered 0 for every store
regardless of the data. With real expenses of 420 the card showed 0.

todayProfit now nets off cost of goods as well as expenses. It ignored
COGS before, which left the dashboard contradicting itself: a profit that
already had expenses deducted, shown beside an expenses card reading 0.
575 - 230 - 420 = -75 now adds up on screen."
```

---

## Task 2: COGS in BOTH endpoints the finance screen uses

**Files:**
- Modify: `api/src/modules/finances/finances.service.ts` (`getSummary` at `:230-241`, and `getDashboard`)
- Modify: `api/src/modules/finances/finances.service.spec.ts`

**The finance screen reads two different endpoints**, which is easy to miss and produces a half-fix if
you do: `FinanceBloc._onDashboardRequested` (the initial load) calls `getDashboard` → `/finances/dashboard`,
while `_onPeriodChanged` (tapping День/Неделя/Месяц) calls `getSummary` → `/finances/summary`. Adding
`cogs` to only one makes gross profit correct on a period tap and wrong on open — a flicker that reads
like a rendering bug rather than a missing field. **Both must return it.**

- [ ] **Step 1: Write the failing test**

Append to `finances.service.spec.ts`:

```ts
describe('FinancesService.getSummary', () => {
  it('returns cogs so the finance screen can show real gross profit', async () => {
    // The screen's «Валовая прибыль» rendered revenue - expenses because COGS
    // was absent from the whole finance path. Gross profit is revenue - COGS.
    const prisma = makePrisma({ revenue: 575, expenses: 420, cogs: 230 });
    const service = await build(prisma);

    const r: any = await service.getSummary('store-1', { period: 'month' } as any);

    expect(r.cogs).toBe(230);
  });
});

describe('FinancesService.getDashboard', () => {
  it('also returns cogs, since the finance screen loads from here first', async () => {
    // FinanceBloc calls getDashboard on open and getSummary on a period tap.
    // If only one carries cogs, gross profit is wrong on open and right after
    // a tap — which looks like a rendering glitch rather than a missing field.
    const prisma = makePrisma({ revenue: 575, expenses: 420, cogs: 230 });
    const service = await build(prisma);

    const r: any = await service.getDashboard('store-1', { period: 'month' } as any);

    expect(r.cogs).toBe(230);
  });
});
```

The existing fake returns `[]` for the raw day queries; make sure its `$queryRaw` still satisfies both those and `computeCogs`. If one fake cannot serve both, give it a dispatch on the query text rather than loosening the assertion.

- [ ] **Step 2: Run it and confirm it fails**

```bash
npm test -- finances.service.spec.ts
```
Expected: FAIL — `r.cogs` undefined.

- [ ] **Step 3: Implement in both**

In `getSummary`, call the helper and add it to the return at `:230`:

```ts
    const cogs = await this.computeCogs(storeId, startDate, endDate);

    return {
      salesByDay,
      expensesByDay,
      cogs,
      expensesByCategory: expensesByCategory.map((e) => ({
```

In `getDashboard`, add `this.computeCogs(storeId, startDate, endDate)` to its existing `Promise.all`,
destructure it as `cogs`, and add `cogs,` to its return object beside `totalRevenue`/`totalExpenses`.
Leave its own `profit` field alone — nothing the app renders depends on it, and changing it is not needed
for this fix.

Leave the rest of both returns as is.

- [ ] **Step 4: Run the tests, full suite and typecheck**

```bash
npm test -- finances.service.spec.ts
npm test
npx tsc --noEmit
```
Expected: all pass, `tsc` 0 errors.

- [ ] **Step 5: Verify against the real store**

Rebuild, restart, then:

```bash
curl -s "http://localhost:4455/api/stores/ccb89fc3-95e9-47d0-9437-8c1079cbc4c2/finances/summary?period=month" \
  -H "Authorization: Bearer $T" | python3 -c "import json,sys; d=json.load(sys.stdin); print('cogs =', d.get('cogs'))"
```
Expected: `cogs = 230`.

- [ ] **Step 6: Commit**

```bash
git add api/src/modules/finances/finances.service.ts api/src/modules/finances/finances.service.spec.ts
git commit -m "fix(api): return cost of goods from finances/summary

The finance screen computes its own totals from this endpoint's daily
breakdowns, but COGS was absent from the entire finance path, so gross
profit could only ever be revenue minus expenses — which is not gross
profit."
```

---

## Task 3: Correct gross and net profit in the app

**Files:**
- Modify: `app/lib/domain/entities/finance_summary.dart`
- Modify: `app/lib/data/datasources/remote/finance_remote_datasource.dart:50-68`
- Modify: `app/lib/presentation/pages/finance/finance_dashboard_page.dart:200,211`
- Create: `app/test/presentation/finance_profit_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/presentation/finance_profit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/domain/entities/finance_summary.dart';

void main() {
  // Guards two defects found by seeding known data:
  //  - «Чистая прибыль» was `profit - totalExpenses`, where profit was already
  //    income - expenses, so expenses were deducted twice: 575-420-420 = -265.
  //    The screen reported a loss on a store that is not making one.
  //  - «Валовая прибыль» rendered that same `profit`, i.e. revenue - expenses,
  //    under a label that means revenue - cost of goods.
  const s = FinanceSummary(
    totalIncome: 575,
    totalCost: 230,
    totalExpenses: 420,
    profit: -75,
    salesCount: 3,
    avgCheck: 575 / 3,
  );

  test('gross profit is revenue minus cost of goods', () {
    expect(s.grossProfit, 345);
  });

  test('net profit subtracts expenses exactly once', () {
    expect(s.netProfit, -75);
    expect(s.netProfit, s.grossProfit - s.totalExpenses);
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
cd app
flutter test test/presentation/finance_profit_test.dart
```
Expected: FAIL to compile — `totalCost`, `grossProfit` and `netProfit` do not exist.

- [ ] **Step 3: Add the field and the two derived getters**

In `app/lib/domain/entities/finance_summary.dart`, add `totalCost` beside the other fields and two getters that put the definitions in one place rather than in the widget:

```dart
class FinanceSummary extends Equatable {
  final double totalIncome;
  final double totalCost;
  final double totalExpenses;
  final double profit;
  final int salesCount;
  final double avgCheck;
  final List<TopProduct> topProducts;

  const FinanceSummary({
    required this.totalIncome,
    this.totalCost = 0,
    required this.totalExpenses,
    required this.profit,
    required this.salesCount,
    required this.avgCheck,
    this.topProducts = const [],
  });

  /// Revenue less cost of goods sold. NOT less expenses — that is net.
  double get grossProfit => totalIncome - totalCost;

  /// Gross profit less operating expenses. Expenses are subtracted here and
  /// nowhere else; the screen previously subtracted them a second time on top
  /// of a `profit` that already included them.
  double get netProfit => grossProfit - totalExpenses;

  @override
  List<Object?> get props =>
      [totalIncome, totalCost, totalExpenses, profit, salesCount];
}
```

`totalCost` defaults to 0 so the other construction site in this file's datasource (which builds from `/finances/dashboard`, an endpoint this plan does not change) keeps compiling.

- [ ] **Step 4: Read `cogs` in the datasource**

In `app/lib/data/datasources/remote/finance_remote_datasource.dart`, inside `getSummary`, after the `totalExpenses` loop:

```dart
      final totalCost = (json['cogs'] as num?)?.toDouble() ?? 0;

      return FinanceSummary(
        totalIncome: totalIncome,
        totalCost: totalCost,
        totalExpenses: totalExpenses,
        profit: totalIncome - totalCost - totalExpenses,
        salesCount: salesCount,
        avgCheck: salesCount > 0 ? totalIncome / salesCount : 0,
      );
```

`profit` now means net profit, consistent with the API's `todayProfit`.

Then do the same in `_mapSummary` (around `:74-81`), which builds from `/finances/dashboard` — the
endpoint the screen loads from **first**:

```dart
      totalIncome: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
      totalCost: (json['cogs'] as num?)?.toDouble() ?? 0,
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0,
```

Leave its `profit:` line reading the API's `profit` field as it is. **If you skip this, gross profit is
wrong when the screen opens and correct after a period tap.**

- [ ] **Step 5: Use the getters on the screen**

In `app/lib/presentation/pages/finance/finance_dashboard_page.dart`, line `200`:

```dart
                                        value: _formatPrice(s.grossProfit),
```

and line `211`:

```dart
                                        value: _formatPrice(s.netProfit),
```

Check the chart below (around `:276`) — it plots `s.profit`. Leave it on `s.profit`, which is now net profit, and confirm the bar's label still reads correctly.

- [ ] **Step 6: Run the test, analyze, full suite**

```bash
flutter test test/presentation/finance_profit_test.dart
flutter analyze
flutter test 2>&1 | grep -oE '[a-zA-Z_]+_test\.dart: [^\[]*\[E\]' | sed 's/ *\[E\]//' | sort -u
```
Expected: the new test passes; `No issues found!`; the failing set is exactly the documented **18** macOS goldens (`balance_page`, `create_delivery_page`, `credits_page`, `currencies_page`, `delivery_detail_page`, `delivery_list_page`, `discounts_page`, `my_stores_page`, `reports_page`, light and dark). **Compare the set, never the count.** Flutter logs use `\r`; pipe through `tr '\r' '\n'` first if the extraction looks mangled.

- [ ] **Step 7: Commit**

```bash
git add app/lib/domain/entities/finance_summary.dart \
        app/lib/data/datasources/remote/finance_remote_datasource.dart \
        app/lib/presentation/pages/finance/finance_dashboard_page.dart \
        app/test/presentation/finance_profit_test.dart
git commit -m "fix(app): stop subtracting expenses twice, and use cost for gross profit

«Чистая прибыль» was `profit - totalExpenses` where profit was already
income - expenses, so 575 revenue and 420 expenses rendered as a -265
loss on a store that is not making one.

«Валовая прибыль» rendered the same figure under a label meaning revenue
minus cost of goods. Both definitions now live as getters on
FinanceSummary, so the screen cannot reimplement one of them wrongly."
```

---

## Task 4: Refresh every screen when the store changes

**Files:**
- Modify: `app/lib/app.dart`
- Modify: `app/test/presentation/session_scope_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `app/test/presentation/session_scope_test.dart`, reusing its existing `_CounterCubit`:

```dart
  testWidgets('a store change also disposes the store-scoped blocs', (tester) async {
    // Switching stores refreshed nothing: dashboard, Товары and Финансы all
    // kept the previous store's data, and the API log showed only a
    // banners/active request for the newly selected store.
    final seen = <_CounterCubit>[];

    Widget tree(String session, String store) => MaterialApp(
          home: MultiBlocProvider(
            key: ValueKey('$session|$store'),
            providers: [BlocProvider(create: (_) => _CounterCubit())],
            child: Builder(builder: (context) {
              seen.add(context.read<_CounterCubit>());
              return const SizedBox.shrink();
            }),
          ),
        );

    await tester.pumpWidget(tree('user-1', 'store-A'));
    seen.last.bump();
    await tester.pumpWidget(tree('user-1', 'store-B'));
    await tester.pump();

    expect(identical(seen.first, seen.last), isFalse,
        reason: 'a different store must get fresh blocs');
    expect(seen.last.state, 0, reason: 'the previous store\'s state must not carry over');
  });
```

- [ ] **Step 2: Run the whole file**

```bash
flutter test test/presentation/session_scope_test.dart
```
Expected: **all three pass**, including the new one — it pins Flutter's keying semantics, which the design relies on, rather than driving a red-green cycle. If it fails, stop: the approach is unsound.

- [ ] **Step 3: Add the store-key helper**

In `app/lib/app.dart`, beside `_sessionKeyOf` at `:44`:

```dart
/// Identity of the selected store, used for the inner provider key.
///
/// StoreBloc itself must NOT sit inside the store-keyed subtree — it owns the
/// selection, so its own change would destroy it mid-switch. It also must not
/// sit at the root, or `selectedStore` would survive logout and the next
/// session would fetch against the previous user's store, which is the bug
/// fixed in 2082dc8. Hence the middle level.
String _storeKeyOf(StoreState state) =>
    state is StoreLoaded && state.selectedStore != null
        ? 'store:${state.selectedStore!.id}'
        : 'no-store';
```

Add the `store_state.dart` import if it is not already present.

- [ ] **Step 4: Split the keyed subtree into two levels**

Inside `MaterialApp.router`'s `builder:`, replace the single keyed `MultiBlocProvider` with:

```dart
              return BlocBuilder<AuthBloc, AuthState>(
                buildWhen: (prev, curr) =>
                    _sessionKeyOf(prev) != _sessionKeyOf(curr),
                builder: (context, authState) {
                  final sessionKey = _sessionKeyOf(authState);
                  return MultiBlocProvider(
                    // Level 2: survives a store switch, resets on logout.
                    key: ValueKey('session:$sessionKey'),
                    providers: [
                      BlocProvider(create: (_) => sl<StoreBloc>()),
                    ],
                    child: BlocBuilder<StoreBloc, StoreState>(
                      buildWhen: (prev, curr) =>
                          _storeKeyOf(prev) != _storeKeyOf(curr),
                      builder: (context, storeState) {
                        return MultiBlocProvider(
                          // Level 3: resets on account OR store change.
                          key: ValueKey('$sessionKey|${_storeKeyOf(storeState)}'),
                          providers: [
                            BlocProvider(create: (_) => sl<CartBloc>()),
                            BlocProvider(create: (_) => sl<DashboardBloc>()),
                            BlocProvider(create: (_) => sl<ProductListBloc>()),
                            BlocProvider(create: (_) => sl<ProductFormBloc>()),
                            BlocProvider(create: (_) => sl<CategoryBloc>()),
                            BlocProvider(create: (_) => sl<CheckoutBloc>()),
                            BlocProvider(create: (_) => sl<SalesHistoryBloc>()),
                            BlocProvider(create: (_) => sl<StockIntakeBloc>()),
                            BlocProvider(create: (_) => sl<FinanceBloc>()),
                            BlocProvider(create: (_) => sl<ExpenseBloc>()),
                            BlocProvider(create: (_) => sl<DebtBloc>()),
                            BlocProvider(create: (_) => sl<ZakatBloc>()),
                            BlocProvider(create: (_) => sl<CustomerDetailBloc>()),
                            BlocProvider(create: (_) => sl<CustomerListBloc>()),
                            BlocProvider(create: (_) => sl<SupplierListBloc>()),
                            BlocProvider(create: (_) => sl<StaffBloc>()),
                            BlocProvider(create: (_) => sl<RolesBloc>()),
                            BlocProvider(create: (_) => sl<ShiftBloc>()),
                            BlocProvider(create: (_) => sl<PayrollBloc>()),
                            BlocProvider(create: (_) => sl<StaffFormBloc>()),
                            BlocProvider(create: (_) => sl<PrinterBloc>()),
                            BlocProvider(create: (_) => sl<SubscriptionBloc>()),
                            BlocProvider(create: (_) => sl<LoyaltySettingsBloc>()),
                          ],
                          child: MediaQuery(
                            data: MediaQuery.of(context),
                            child: SafeArea(
                              top: false,
                              bottom: false,
                              child: Column(
                                children: [
                                  const OfflineBanner(),
                                  Expanded(child: child ?? const SizedBox.shrink()),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
```

That is **23** providers at level 3 — `StoreBloc` moved up, the other 23 of the previous 24 unchanged. A different count means one was dropped or duplicated; `flutter analyze` will not catch a missing provider, but the first screen needing it throws at runtime.

- [ ] **Step 5: Analyze and run the scoped tests**

```bash
flutter analyze
flutter test test/presentation/session_scope_test.dart
```
Expected: `No issues found!`, all three pass.

- [ ] **Step 6: Full suite and i18n lint**

```bash
flutter test 2>&1 | tr '\r' '\n' | grep -oE '[a-zA-Z_]+_test\.dart: [^\[]*\[E\]' | sed 's/ *\[E\]//' | sort -u
dart run tool/check_i18n.dart; echo "EXIT=$?"
```
Expected: the 18-golden set unchanged; `scanned 343 files`, `EXIT=0` (unpiped).

- [ ] **Step 7: Commit**

```bash
git add app/lib/app.dart app/test/presentation/session_scope_test.dart
git commit -m "fix(app): refresh the session-scoped blocs when the store changes

Switching stores refreshed nothing — dashboard, Товары and Финансы all
kept the previous store's figures, and the API log showed only a
banners/active request for the new store. Recovery needed a manual period
change or pull-to-refresh on each screen.

StoreBloc now sits at its own level: inside the store-keyed subtree it
would be destroyed by its own selection change, and at the root its
selection would survive logout, which is the bug fixed in 2082dc8."
```

---

## Task 5: Verify on the emulator against the known figures

**Files:** none modified unless a defect is found.

The seeded data makes every number checkable. This is where the work is proven.

- [ ] **Step 1: Build, install and sign in**

```bash
cd app
flutter run -d emulator-5554
```
If no device is listed, use `flutter devices --device-timeout 15` — the default timeout reports "no devices" on a machine that has three. Sign in as BUSINESS (`+992920777001` / `x8R9s5msWiEzBYWL`).

Note `adb shell input tap` takes **real device coordinates** (1080×2400), not the coordinates of a downscaled screenshot.

- [ ] **Step 2: Select the store that has the data**

This account owns two stores. Use the header selector to pick **«QA Магазин Бизнес»** — the other one ("QA Второй магазин") is empty, and checking figures there proves nothing.

- [ ] **Step 3: Главная, with no manual refresh**

Expected, immediately after the store switch:

| Card | Expected |
|---|---|
| revenue | **575 TJS** |
| sales | **3 продаж** |
| average check | **192 TJS** (191.67 rounded) |
| Прибыль | **−75 TJS** |
| Себестоимость | **230 TJS** |
| Расходы | **420 TJS** |
| Остатки на складе | **10 товаров** |

`575 − 230 − 420 = −75` must add up on screen. Before this work the last three read 155 / 0 / 0.

- [ ] **Step 4: Финансы, with no manual refresh**

| Card | Expected |
|---|---|
| Общий доход | **575 TJS** |
| Общие расходы | **420 TJS** |
| Валовая прибыль | **345 TJS** |
| Чистая прибыль | **−75 TJS** |

Before this work: 155 and **−265**.

- [ ] **Step 5: Товары, with no manual refresh**

10 products, stock 48/49/47/50×6/49, footer **68 175** and **27 270**.

- [ ] **Step 6: Prove the refresh is automatic, not incidental**

Switch to "QA Второй магазин" and back. Each screen must show the right store's figures **without** a period change or pull-to-refresh. Confirm against the API log that a `finances/overview` and a `products` request fire for the newly selected store each time — not just `banners/active`, which was the whole symptom.

- [ ] **Step 7: Confirm the logout fix still holds**

Sign out, sign in as PREMIUM (`+992920777002` / `yfgYAi5oHqm38w8x`). Expected: no "Недостаточно прав" anywhere, and the same figures (that store was seeded identically). **This matters because Task 4 moved `StoreBloc` — getting its level wrong brings the logout bug back**, and only this step catches that.

- [ ] **Step 8: Report, then commit only if something needed fixing**

State each table above as pass or fail with the observed numbers. If Steps 1–7 are clean there is nothing to commit.

---

## Notes for the executor

- **The numbers are the deliverable.** "The screen renders" is not the bar — every figure has a known expected value, and a plausible-looking wrong number is the exact failure this work exists to remove.
- **Do not reseed.** The data is already in place and the expectations are derived from it.
- **`todayProfit` changes meaning** from revenue − expenses to revenue − COGS − expenses. That is deliberate and argued in the spec; do not "restore" it.
- **Two-level keying is the fiddly part.** `StoreBloc` at level 2 is load-bearing in both directions: inside level 3 its own selection change would destroy it; at the root, `selectedStore` would survive logout and reintroduce the bug fixed in `2082dc8`. Step 7 is what catches the second case.
- **Out of scope by decision:** `/finances/dashboard`'s own `profit` field — nothing the app renders depends on it, since `_mapSummary` maps it to `FinanceSummary.profit` and the screen now uses the `grossProfit`/`netProfit` getters instead. `reports_page.dart` is also untouched: it declares its own `netProfit` on its own class and never reads `FinanceSummary.profit`, which was verified rather than assumed.
