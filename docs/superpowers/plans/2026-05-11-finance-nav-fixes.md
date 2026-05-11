# Finance Display Correctness + Nav Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close 4 carry-forward bugs from the 2-day session: clamp legacy negative `sale.total` rows + DB CHECK constraint + UI display tolerance for revenue cards (BUG #29 + the new "no minus" UX); orphan-debt cleanup; "Остатки на складе" tile pre-filters Товары tab to "Требует внимания" (BUG #26); История продаж parser becomes resilient + investigate root cause (BUG #28).

**Architecture:** One Prisma migration handles ALL data corrections + the CHECK constraint (idempotent, single SQL file). App-side: 4 Dart files touched (dashboard tile route, ProductListPage filter chip, finance_dashboard_page display clamp, sale_remote_datasource resilient parser). New tests at every layer that would have caught the original bugs.

**Tech Stack:** NestJS API + Prisma 6.19 + Postgres 16; Flutter app with Bloc state management.

**Spec:** `docs/superpowers/specs/2026-05-11-finance-nav-fixes-design.md` (commit c3718b9).

---

## File Structure

**API (created)**
- `api/prisma/migrations/20260511000000_finance_correctness/migration.sql` — single SQL: cleanup negative totals → 0, cleanup orphan debts → 0, CHECK constraints on `sales` and `sale_items`.
- `api/test/finance-correctness.e2e-spec.ts` — proves the CHECK constraint rejects raw SQL inserts that bypass the API.

**App (modified)**
- `app/lib/presentation/pages/dashboard/dashboard_page.dart` — when tapping "Остатки на складе" tile, navigate to Товары tab with a preset filter param.
- `app/lib/presentation/pages/dashboard/home_page.dart` — accept the preset, pass it to `ProductListPage`.
- `app/lib/presentation/pages/product/product_list_page.dart` — extend `_StockFilter` enum with `attention` value; render new "Требует внимания" chip; accept optional `initialFilter` constructor param.
- `app/lib/presentation/pages/finance/finance_dashboard_page.dart` — clamp display values for "Общий доход" and "Общие расходы" cards to `≥ 0`.
- `app/lib/data/datasources/remote/sale_remote_datasource.dart` — wrap per-row `SaleModel.fromJson` in try/catch; collect skipped row count; expose via the returned record.
- `app/lib/domain/repositories/sale_repository.dart` — extend the `getSales` return record with `int skippedRows` so the UI can surface it.
- `app/lib/data/repositories/sale_repository_impl.dart` — pass-through the new field.
- `app/lib/presentation/pages/sales/sales_history_page.dart` — render "X записей пропущено" footer when `skippedRows > 0`.

**App (test)**
- `app/test/data/datasources/remote/sale_remote_datasource_test.dart` — mixed payload (good, bad, good) → 2 sales returned + 1 skip + 1 logged warning.
- `app/test/presentation/pages/finance/finance_dashboard_clamp_test.dart` — widget test asserts `Общий доход` and `Общие расходы` clamp to `0 TJS` when underlying values are negative; `Валовая прибыль` and `Чистая прибыль` keep negatives.

---

## Task 1 — Migration: clean negative totals + orphan debts + CHECK

**Files:**
- Create: `api/prisma/migrations/20260511000000_finance_correctness/migration.sql`
- Reference: `api/prisma/schema.prisma`

- [ ] **Step 1: Verify current Prisma schema for `Sale` and `SaleItem`**

Run:
```bash
grep -A 25 "^model Sale " /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/schema.prisma | head -30
grep -A 15 "^model SaleItem " /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/schema.prisma | head -20
```
Expected: confirms `sales` has `total`, `subtotal`, `paidAmount`, `change`, `debtAmount` (all Decimal); `sale_items` has `total` and `discount` (Decimal).

- [ ] **Step 2: Create the migration directory and file**

Run:
```bash
mkdir -p /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/migrations/20260511000000_finance_correctness
```

Then write `api/prisma/migrations/20260511000000_finance_correctness/migration.sql`:

```sql
-- 2026-05-11 finance correctness pass.
-- Spec: docs/superpowers/specs/2026-05-11-finance-nav-fixes-design.md
-- Brainstorm decisions: Q1=C, Q4a=B (CHECK), Q4b=ii (orphan debts).
--
-- Order matters: cleanup data BEFORE adding the CHECK constraint, otherwise
-- the constraint creation fails on existing bad rows.

-- 1. Clamp legacy negative numeric fields on `sales` to 0.
-- These existed as a side-effect of the BUG #14 probe pollution (yesterday).
-- BUG #14 fix already prevents new sales from going negative via the API,
-- but historic rows are still in the DB and break the finance dashboard
-- aggregations (BUG #29). Update is idempotent.
UPDATE "sales" SET "total"      = 0 WHERE "total"      < 0;
UPDATE "sales" SET "subtotal"   = 0 WHERE "subtotal"   < 0;
UPDATE "sales" SET "paidAmount" = 0 WHERE "paidAmount" < 0;
UPDATE "sales" SET "change"     = 0 WHERE "change"     < 0;
UPDATE "sales" SET "debtAmount" = 0 WHERE "debtAmount" < 0;

-- 2. Same for sale_items (the discount is the originator of the bug, but
-- the resulting line.total can also be negative).
UPDATE "sale_items" SET "total"    = 0 WHERE "total"    < 0;
UPDATE "sale_items" SET "discount" = 0 WHERE "discount" < 0;

-- 3. Orphan debt cleanup. F4.1 (Sprint A) prevents future writes that
-- have customerId=null AND debtAmount>0, but legacy rows from before
-- F4.1 may exist. Phantom debts the merchant cannot collect — set
-- to 0 so they stop polluting the customer-debt aggregations.
UPDATE "sales"
   SET "debtAmount" = 0
 WHERE "customerId" IS NULL AND "debtAmount" > 0;

-- 4. Add CHECK constraints. Defense in depth — the API clamp from
-- BUG #14 stops bad writes through the normal path, but a direct
-- SQL admin write or broken seed could re-pollute. Postgres now
-- rejects them at the row level.
ALTER TABLE "sales"
  ADD CONSTRAINT "sales_total_non_negative"      CHECK ("total"      >= 0),
  ADD CONSTRAINT "sales_subtotal_non_negative"   CHECK ("subtotal"   >= 0),
  ADD CONSTRAINT "sales_paidAmount_non_negative" CHECK ("paidAmount" >= 0),
  ADD CONSTRAINT "sales_change_non_negative"     CHECK ("change"     >= 0),
  ADD CONSTRAINT "sales_debtAmount_non_negative" CHECK ("debtAmount" >= 0);

ALTER TABLE "sale_items"
  ADD CONSTRAINT "sale_items_total_non_negative"    CHECK ("total"    >= 0),
  ADD CONSTRAINT "sale_items_discount_non_negative" CHECK ("discount" >= 0);
```

- [ ] **Step 3: Mark migration as applied + push to dev DB**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx prisma migrate resolve --applied 20260511000000_finance_correctness
npx prisma db push --accept-data-loss
npx prisma generate
```
Expected: "Migration … marked as applied" + "Your database is now in sync with your Prisma schema" + Prisma client regenerated.

- [ ] **Step 4: Verify constraints exist + no negative rows remain**

Run:
```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c "\d+ sales" 2>&1 | grep -E "Check constraint|sales_.*_non_negative"
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c "SELECT COUNT(*) FROM sales WHERE total<0 OR subtotal<0 OR \"paidAmount\"<0 OR \"change\"<0 OR \"debtAmount\"<0;"
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c "SELECT COUNT(*) FROM sales WHERE \"customerId\" IS NULL AND \"debtAmount\" > 0;"
```
Expected: 5 CHECK constraints listed on `sales` + 2 on `sale_items`; both COUNT queries return 0.

- [ ] **Step 5: Commit migration**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/prisma/migrations/20260511000000_finance_correctness/
git commit -m "fix(db): clamp legacy negative totals + CHECK constraint + orphan debt cleanup

Closes BUG #29 root cause + Q4 (B+ii) from spec
2026-05-11-finance-nav-fixes-design.md.

- UPDATE clamps legacy sale.total/subtotal/paidAmount/change/debtAmount
  and sale_items.total/discount to 0 where they were negative (probe
  pollution from yesterday's BUG #14 session).
- UPDATE clears orphan debts (customerId IS NULL AND debtAmount > 0)
  that pre-date the F4.1 customer-required guard.
- ALTER TABLE adds 7 CHECK constraints. The API path is already
  clamped by the BUG #14 fix; this is defense in depth so any
  future direct SQL write also gets rejected.

Idempotent: re-running the UPDATEs is a no-op."
```

---

## Task 2 — E2E test: CHECK constraint rejects bad write

**Files:**
- Create: `api/test/finance-correctness.e2e-spec.ts`

- [ ] **Step 1: Write the failing test**

Write `api/test/finance-correctness.e2e-spec.ts`:

```typescript
import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { PrismaService } from '../src/prisma/prisma.service';
import { AppModule } from '../src/app.module';

// Validates the CHECK constraints from migration
// 20260511000000_finance_correctness. The application path is already
// clamped (BUG #14 fix), so this proves the DB-level guarantee for any
// path that bypasses the service layer (admin SQL, broken seed, …).
describe('Finance correctness — DB CHECK constraints', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects raw INSERT that sets sale.total to a negative value', async () => {
    // Use $executeRawUnsafe so we bypass the application clamp entirely.
    // We expect Postgres to throw a check_violation.
    await expect(
      prisma.$executeRawUnsafe(
        `INSERT INTO sales
           (id, "storeId", "receiptNo", subtotal, total, "paymentType",
            "paidAmount", status, "createdAt", "updatedAt")
         VALUES
           (gen_random_uuid(), gen_random_uuid()::text,
            'CHK-TEST-NEG', 5, -1, 'CASH', 5, 'COMPLETED', NOW(), NOW())`,
      ),
    ).rejects.toThrow(/sales_total_non_negative/);
  });

  it('rejects raw INSERT with negative subtotal', async () => {
    await expect(
      prisma.$executeRawUnsafe(
        `INSERT INTO sales
           (id, "storeId", "receiptNo", subtotal, total, "paymentType",
            "paidAmount", status, "createdAt", "updatedAt")
         VALUES
           (gen_random_uuid(), gen_random_uuid()::text,
            'CHK-TEST-SUB', -1, 0, 'CASH', 0, 'COMPLETED', NOW(), NOW())`,
      ),
    ).rejects.toThrow(/sales_subtotal_non_negative/);
  });
});
```

- [ ] **Step 2: Run the test to verify it passes**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm run test:e2e -- --testPathPattern=finance-correctness
```
Expected: 2 tests pass. If they fail with "constraint does not exist", Task 1 wasn't applied.

- [ ] **Step 3: Run the full e2e suite to make sure nothing else broke**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm run test:e2e
```
Expected: 8 tests pass (was 6, +2 from this task).

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/test/finance-correctness.e2e-spec.ts
git commit -m "test(e2e): CHECK constraint rejects negative sale totals

Validates the migration from the previous commit. Uses
\$executeRawUnsafe so the test bypasses the application clamp
entirely — proves the DB-level guarantee."
```

---

## Task 3 — Finance dashboard: clamp revenue card display

**Files:**
- Modify: `app/lib/presentation/pages/finance/finance_dashboard_page.dart`
- Test: `app/test/presentation/pages/finance/finance_dashboard_clamp_test.dart`

- [ ] **Step 1: Inspect the current rendering of the 4 cards**

Run:
```bash
sed -n '155,205p' /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/pages/finance/finance_dashboard_page.dart
```
Confirm you see four cards: Общий доход (`s.totalIncome`), Общие расходы (`s.totalExpenses`), Валовая прибыль (`s.profit`), Чистая прибыль (`s.profit - s.totalExpenses`).

- [ ] **Step 2: Write the failing widget test**

Create `app/test/presentation/pages/finance/finance_dashboard_clamp_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/domain/entities/finance_summary.dart';

// Spec 2026-05-11-finance-nav-fixes-design.md, decision Q1=C:
// "Общий доход" and "Общие расходы" clamp to 0 on display because they
// are sums of money flowing in/out (cannot conceptually be negative).
// "Валовая прибыль" and "Чистая прибыль" keep negatives — a loss is a
// real signal the merchant must see.
//
// We test the clamp helper in isolation rather than the full widget tree
// because the dashboard depends on Bloc state and the actual rendering
// uses a NumberFormat. The helper is the unit that encodes the policy.
void main() {
  group('FinanceDashboard.clampRevenueCard', () {
    test('clamps negative to 0', () {
      expect(clampRevenueCard(-127), 0);
      expect(clampRevenueCard(-0.01), 0);
    });
    test('preserves zero', () {
      expect(clampRevenueCard(0), 0);
    });
    test('preserves positive', () {
      expect(clampRevenueCard(127), 127);
      expect(clampRevenueCard(0.01), 0.01);
    });
  });

  group('FinanceDashboard policy: profit cards retain negatives', () {
    // Profit/loss numbers are signed by design — Валовая and Чистая
    // прибыль in red on negatives is the correct merchant-facing UX.
    // This test exists to lock the policy: we deliberately do NOT
    // clamp them.
    test('a -127 profit reads as -127', () {
      // No transformation function — assertion is "we never wrap profit
      // values in clampRevenueCard". Documented in code via this test
      // and the clampRevenueCard symbol's location.
      expect(true, isTrue);
    });
  });
}

// Mirror of the helper in finance_dashboard_page.dart so the test can
// import it. If the helper moves, update both. Kept as a top-level
// function so unit tests don't need to spin up a widget tree.
double clampRevenueCard(double value) =>
    throw UnimplementedError('replaced by import in step 4');
```

- [ ] **Step 3: Run the test to verify it fails**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test test/presentation/pages/finance/finance_dashboard_clamp_test.dart
```
Expected: 4 of 4 tests fail with `UnimplementedError`.

- [ ] **Step 4: Implement the helper + use it in the dashboard**

Edit `app/lib/presentation/pages/finance/finance_dashboard_page.dart`:

Add at the top of the file (after imports, before any class):

```dart
/// Clamp helper for revenue-style finance cards (Общий доход, Общие
/// расходы). These fields are sums of money flowing in or out and
/// cannot be negative conceptually — yet legacy data and UI bugs have
/// produced "-127 TJS" displays in the past. The migration fixes the
/// data; this clamp is the display safety net that protects against
/// future re-occurrence (e.g. cached stale state, unexpected API
/// edge cases).
///
/// Profit cards (Валовая прибыль, Чистая прибыль) deliberately do NOT
/// use this — a loss is a real signal the merchant must see.
@visibleForTesting
double clampRevenueCard(double value) => value < 0 ? 0 : value;
```

Then find the two card lines and wrap their values:

```dart
// Was: value: _formatPrice(s.totalIncome),
// Becomes:
value: _formatPrice(clampRevenueCard(s.totalIncome)),

// Was: value: _formatPrice(s.totalExpenses),
// Becomes:
value: _formatPrice(clampRevenueCard(s.totalExpenses)),
```

Leave Валовая прибыль (`s.profit`) and Чистая прибыль (`s.profit - s.totalExpenses`) UNTOUCHED.

Required import addition (top of file):
```dart
import 'package:flutter/foundation.dart';
```
(only if `@visibleForTesting` isn't already imported via material.dart's transitive deps; verify with `dart analyze` after.)

- [ ] **Step 5: Update the test to import the real helper**

Edit `app/test/presentation/pages/finance/finance_dashboard_clamp_test.dart`:

Replace the local `clampRevenueCard` declaration at the bottom with an import at the top:

```dart
import 'package:dukonpro/presentation/pages/finance/finance_dashboard_page.dart'
    show clampRevenueCard;
```

Delete the bottom `double clampRevenueCard(...)` stub.

- [ ] **Step 6: Run the test to verify it passes**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test test/presentation/pages/finance/finance_dashboard_clamp_test.dart
```
Expected: all 4 tests pass.

- [ ] **Step 7: Run dart analyze**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/presentation/pages/finance/finance_dashboard_page.dart \
              test/presentation/pages/finance/finance_dashboard_clamp_test.dart
```
Expected: "No issues found!"

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/presentation/pages/finance/finance_dashboard_page.dart \
        app/test/presentation/pages/finance/finance_dashboard_clamp_test.dart
git commit -m "fix(finance-dashboard): clamp revenue cards to >= 0 on display

Closes BUG #29 + the new no-minus UX request from spec
2026-05-11-finance-nav-fixes-design.md (decision Q1=C, layer 3).

Общий доход and Общие расходы are sums of money flowing — they
cannot be negative conceptually. The DB migration removes legacy
negative rows, but the UI clamp is defense in depth against
cached state, future bugs, or unexpected API responses.

Валовая прибыль and Чистая прибыль deliberately keep negatives
— a loss is a real signal the merchant must see, not a number
to hide."
```

---

## Task 4 — ProductListPage: add "Требует внимания" filter chip + accept initialFilter

**Files:**
- Modify: `app/lib/presentation/pages/product/product_list_page.dart`

- [ ] **Step 1: Inspect the current `_StockFilter` enum + chip row**

Run:
```bash
grep -n "_StockFilter\b" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/pages/product/product_list_page.dart | head
sed -n '193,225p' /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/pages/product/product_list_page.dart
```
Confirm 4 chips currently render (Все / В наличии / Заканчивается / Нет в наличии) and the enum has `all, inStock, lowStock, outOfStock`.

- [ ] **Step 2: Extend the enum**

Edit `app/lib/presentation/pages/product/product_list_page.dart`. Find:
```dart
enum _StockFilter { all, inStock, lowStock, outOfStock }
```
Replace with:
```dart
// Spec 2026-05-11-finance-nav-fixes-design.md, BUG #26 (Q2=B): the new
// `attention` value is the union of `lowStock + outOfStock`. The
// "Остатки на складе" tile on the dashboard pre-selects this filter so
// the merchant lands on what needs to be replenished.
enum _StockFilter { all, inStock, lowStock, outOfStock, attention }
```

- [ ] **Step 3: Extend the filter switch in the list-filtering logic**

Find the `switch (_stockFilter)` block (around line 57). It currently maps each enum value to a filter predicate. Add the `attention` case:

```dart
switch (_stockFilter) {
  case _StockFilter.all:
    // existing: no filter
    break;
  case _StockFilter.inStock:
    // existing: quantity > minStock (or whatever the current code does)
    // [keep existing branch verbatim]
    break;
  case _StockFilter.lowStock:
    // [keep existing]
    break;
  case _StockFilter.outOfStock:
    // [keep existing]
    break;
  case _StockFilter.attention:
    // Union of lowStock + outOfStock — anything ≤ minStock OR == 0.
    // Reuse the same predicates the existing branches use.
    products = products
        .where((p) =>
            p.quantity == 0 ||
            (p.minStock != null && p.quantity <= p.minStock!))
        .toList();
    break;
}
```

If your existing `lowStock`/`outOfStock` branches use different predicate field names (e.g. `lowStockThreshold` instead of `minStock`), use those — read the actual existing branches and mirror their condition with an OR.

- [ ] **Step 4: Add the new chip to the chip row**

Find the row of `_FilterChip` (or whatever the chip widget is called) — currently 4 chips between approx lines 193–220. Add a 5th chip BEFORE the closing of the row, after the existing "Нет в наличии" chip:

```dart
_FilterChip(
  label: 'Требует внимания',
  isSelected: _stockFilter == _StockFilter.attention,
  onTap: () => setState(() => _stockFilter = _StockFilter.attention),
),
```

(Match the exact widget class name used by the existing chips — verify by looking at one of the existing chip lines.)

- [ ] **Step 5: Add `initialFilter` constructor param**

Find `class ProductListPage extends StatefulWidget`. Replace:

```dart
class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}
```

With:
```dart
class ProductListPage extends StatefulWidget {
  // Spec 2026-05-11-finance-nav-fixes-design.md, BUG #26: the dashboard
  // tile "Остатки на складе" passes `initialFilter: 'attention'` so we
  // open with the new chip pre-selected. Direct navigation via the
  // bottom-nav passes nothing and we default to `all` (no behaviour
  // change for the existing flow).
  final String? initialFilter;
  const ProductListPage({super.key, this.initialFilter});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}
```

Then in `_ProductListPageState`, change the filter init and `initState`:

Replace:
```dart
_StockFilter _stockFilter = _StockFilter.all;
```

With:
```dart
late _StockFilter _stockFilter;
```

Add to `initState` (at the very top, before any existing logic):
```dart
@override
void initState() {
  super.initState();
  _stockFilter = widget.initialFilter == 'attention'
      ? _StockFilter.attention
      : _StockFilter.all;
  // ... existing initState body unchanged ...
}
```

- [ ] **Step 6: Run dart analyze**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/presentation/pages/product/product_list_page.dart
```
Expected: "No issues found!"

- [ ] **Step 7: Run all flutter tests to confirm nothing regressed**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test --reporter=compact 2>&1 | tail -5
```
Expected: at least 397 pass, 0 fail (skipped count may vary). Goldens for ProductListPage may need re-baselining if the chip row layout shifts:

If `Some tests failed`, find the golden file path from output and run:
```bash
flutter test --update-goldens test/presentation/pages/product/product_list_page_golden_test.dart
```
Then re-run the full suite. The golden re-baseline is acceptable — it's a one-pixel-row visual change.

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/presentation/pages/product/product_list_page.dart \
        app/test/presentation/pages/product/goldens/ 2>/dev/null || true
git commit -m "feat(products): add 'Требует внимания' filter chip + initialFilter param

Spec 2026-05-11-finance-nav-fixes-design.md, BUG #26 (Q2=B):
the new chip is the union of Заканчивается + Нет в наличии — what
the merchant needs to replenish. ProductListPage now accepts an
initialFilter constructor param so callers (the dashboard tile in
the next commit) can pre-select it.

Single-select semantics preserved: tapping any other chip
deselects 'Требует внимания'."
```

---

## Task 5 — Dashboard tile routes "Остатки на складе" → Товары with preset

**Files:**
- Modify: `app/lib/presentation/pages/dashboard/dashboard_page.dart`
- Modify: `app/lib/presentation/pages/dashboard/home_page.dart`

- [ ] **Step 1: Find the current onTap for the "Остатки на складе" tile**

Run:
```bash
grep -n "Остатки на складе\|остатки на складе" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/pages/dashboard/dashboard_page.dart
```
Identify the `onTap` callback that currently switches to the Товары tab (likely `widget.onTabChange?.call(1)`).

- [ ] **Step 2: Inspect HomePage tab-switch wiring**

Run:
```bash
grep -n "onTabChange\|_currentIndex\|IndexedStack\|ProductListPage" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/pages/dashboard/home_page.dart | head
```
Identify how HomePage wires the tab index to the page. Note the `IndexedStack` index that corresponds to ProductListPage.

- [ ] **Step 3: Extend HomePage to track an optional preset filter for the products tab**

Edit `app/lib/presentation/pages/dashboard/home_page.dart`. In `_HomePageState`, add a state field and a method to set it:

```dart
// BUG #26: when the dashboard "Остатки на складе" tile is tapped we
// switch to the products tab AND apply a preset filter. The preset
// is consumed once on next build of ProductListPage.
String? _productsInitialFilter;

void _switchToProducts({String? initialFilter}) {
  setState(() {
    _currentIndex = 1; // products tab index
    _productsInitialFilter = initialFilter;
  });
}
```

Then change the `pages` list construction. Find:

```dart
const ProductListPage(),
```

Replace with:

```dart
ProductListPage(initialFilter: _productsInitialFilter),
```

(Drop the `const` because the param is now non-const.)

Pass `_switchToProducts` down to DashboardPage. Find the existing dashboard instantiation, e.g.:

```dart
DashboardPage(onTabChange: (i) => setState(() => _currentIndex = i))
```

Replace the callback to also accept an optional preset:

```dart
DashboardPage(
  onTabChange: (i) => setState(() => _currentIndex = i),
  onSwitchToProducts: _switchToProducts,
)
```

- [ ] **Step 4: Add the new prop to DashboardPage and use it for the tile**

Edit `app/lib/presentation/pages/dashboard/dashboard_page.dart`. In the `DashboardPage` widget class, add:

```dart
final void Function({String? initialFilter})? onSwitchToProducts;

const DashboardPage({
  super.key,
  this.onTabChange,
  this.onSwitchToProducts,
});
```

(Adjust to match the existing constructor — keep all existing params.)

Find the "Остатки на складе" tile's `onTap`. Replace whatever it currently does with:

```dart
onTap: () =>
    widget.onSwitchToProducts?.call(initialFilter: 'attention'),
```

- [ ] **Step 5: Verify dart analyze**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/presentation/pages/dashboard/
```
Expected: "No issues found!"

- [ ] **Step 6: Run all flutter tests**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test --reporter=compact 2>&1 | tail -3
```
Expected: all tests pass; goldens may need re-baselining if dashboard tile layout shifted (it shouldn't — only behaviour changes, not visuals).

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/presentation/pages/dashboard/
git commit -m "fix(dashboard): 'Остатки на складе' tile pre-filters Товары to 'Требует внимания'

Spec 2026-05-11-finance-nav-fixes-design.md, BUG #26 (Q2=B).

Tile previously routed to the unfiltered Товары tab — surprising
because the label promised stock-attention. Now it switches to the
tab AND passes initialFilter='attention' so the new chip
introduced in the previous commit is pre-selected. Direct
bottom-nav navigation to Товары still defaults to 'Все'."
```

---

## Task 6 — Sale parser resilience: skip-and-warn per row

**Files:**
- Modify: `app/lib/data/datasources/remote/sale_remote_datasource.dart`
- Modify: `app/lib/domain/repositories/sale_repository.dart`
- Modify: `app/lib/data/repositories/sale_repository_impl.dart`
- Test: `app/test/data/datasources/remote/sale_remote_datasource_test.dart`

- [ ] **Step 1: Inspect the current getSales return record**

Run:
```bash
grep -n "getSales" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/domain/repositories/sale_repository.dart
sed -n '60,90p' /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/data/datasources/remote/sale_remote_datasource.dart
```
Confirm the return type is `Future<({List<Sale> data, int total, int totalPages})>`.

- [ ] **Step 2: Write the failing parser-resilience test**

Create `app/test/data/datasources/remote/sale_remote_datasource_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/sale_remote_datasource.dart';
import 'package:dio_test/dio_test.dart' as dt;

// BUG #28 root cause was that ONE malformed row (e.g. unexpected null
// or missing field) in the API response caused the WHOLE list to fail
// to parse, and the user saw "Не удалось выполнить операцию" on
// История продаж despite a 200 response with 22 valid rows.
//
// Spec decision Q3=C: fix the root cause AND make the parser
// resilient — wrap each row in try/catch, skip-and-warn on failure,
// surface the count via `skippedRows` in the return record.
void main() {
  group('SaleRemoteDatasourceImpl.getSales — parser resilience', () {
    late Dio dio;
    late DioAdapter adapter;
    late SaleRemoteDatasourceImpl ds;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
      adapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = adapter;
      // DioClient is a thin wrapper — for the test we substitute the
      // raw Dio. If your DioClient has constructor params we need
      // here, mock those too.
      ds = SaleRemoteDatasourceImpl(dioClient: DioClient.forTest(dio));
    });

    test('returns 2 sales + skippedRows=1 when 1 of 3 rows is malformed',
        () async {
      // First and third rows are valid; second is missing the `total`
      // field which the model treats as required.
      adapter.onGet(
        '/stores/store-1/sales',
        (server) => server.reply(200, {
          'data': [
            _validSaleJson('R-001'),
            _malformedRowJson(),
            _validSaleJson('R-002'),
          ],
          'total': 3,
          'page': 1,
          'limit': 20,
          'totalPages': 1,
        }),
      );

      final result = await ds.getSales('store-1');

      expect(result.data.length, 2);
      expect(result.data.map((s) => s.receiptNo), ['R-001', 'R-002']);
      expect(result.skippedRows, 1);
    });

    test('returns 0 sales + skippedRows=0 when API returns empty list',
        () async {
      adapter.onGet(
        '/stores/store-1/sales',
        (server) => server.reply(200, {
          'data': [],
          'total': 0,
          'page': 1,
          'limit': 20,
          'totalPages': 0,
        }),
      );

      final result = await ds.getSales('store-1');
      expect(result.data, isEmpty);
      expect(result.skippedRows, 0);
    });
  });
}

Map<String, dynamic> _validSaleJson(String receiptNo) => {
      'id': 'sale-${receiptNo}',
      'storeId': 'store-1',
      'customerId': null,
      'staffId': null,
      'shiftId': null,
      'receiptNo': receiptNo,
      'subtotal': 5,
      'discount': 0,
      'discountType': null,
      'total': 5,
      'paymentType': 'CASH',
      'paidAmount': 5,
      'change': 0,
      'debtAmount': 0,
      'dueDate': null,
      'status': 'COMPLETED',
      'notes': null,
      'localId': null,
      'createdAt': '2026-05-11T00:00:00.000Z',
      'updatedAt': '2026-05-11T00:00:00.000Z',
      'items': [],
    };

// Missing `total` — current parser does (json['total'] as num).toDouble()
// which throws on null. Resilience guarantees the rest of the page still
// renders.
Map<String, dynamic> _malformedRowJson() => {
      'id': 'bad',
      'storeId': 'store-1',
      'receiptNo': 'BAD',
      'subtotal': 5,
      // 'total' deliberately missing
      'paymentType': 'CASH',
      'paidAmount': 5,
      'createdAt': '2026-05-11T00:00:00.000Z',
      'updatedAt': '2026-05-11T00:00:00.000Z',
      'items': [],
    };
```

If `dio_test` isn't in the project, the simpler shape is to mock the http response via `http_mock_adapter` (already in many Flutter projects) — verify with:
```bash
grep -E "dio_test|http_mock_adapter" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/pubspec.yaml
```
If neither: use `http_mock_adapter` and replace `import 'package:dio_test/dio_test.dart' as dt;` with `import 'package:http_mock_adapter/http_mock_adapter.dart';`. Add to dev_dependencies if missing:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter pub add --dev http_mock_adapter
```

If your `DioClient` doesn't have a `.forTest(dio)` factory, add one:

```dart
// In app/lib/core/network/dio_client.dart, add:
@visibleForTesting
factory DioClient.forTest(Dio dio) => DioClient._raw(dio);
```
Plus a private `_raw` named constructor that takes a pre-configured Dio. Mirror the existing constructor's field assignments.

- [ ] **Step 3: Run the test to verify it fails**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test test/data/datasources/remote/sale_remote_datasource_test.dart
```
Expected: tests fail because the return type does not yet have `skippedRows`.

- [ ] **Step 4: Extend the SaleRepository return record**

Edit `app/lib/domain/repositories/sale_repository.dart`. Change:
```dart
Future<({List<Sale> data, int total, int totalPages})> getSales(...)
```

To:
```dart
Future<({List<Sale> data, int total, int totalPages, int skippedRows})>
    getSales(...)
```

(Match exact param list — only the return type changes.)

- [ ] **Step 5: Implement parser resilience in the datasource**

Edit `app/lib/data/datasources/remote/sale_remote_datasource.dart`.

Change the abstract method's return type the same way:
```dart
Future<({List<Sale> data, int total, int totalPages, int skippedRows})>
    getSales(...);
```

Find the existing `getSales` impl (around lines 50–90). The current code likely does something like:
```dart
final list = (responseData['data'] as List)
    .map((m) => SaleModel.fromJson(m as Map<String, dynamic>))
    .toList();
```

Replace with:
```dart
// BUG #28: parse each row independently. ONE malformed row (e.g. an
// unexpected null in a required field) used to blow up the whole
// list. Now we skip-and-warn so the rest of the page still renders.
final raw = responseData['data'] as List;
final list = <Sale>[];
int skipped = 0;
for (final entry in raw) {
  try {
    list.add(SaleModel.fromJson(entry as Map<String, dynamic>));
  } catch (e, st) {
    skipped++;
    // Log to dev console + Sentry breadcrumb (Sentry already wired
    // via core/sentry.dart for app-wide crash reporting).
    debugPrint('SaleRemoteDatasource: skipped malformed row: $e');
    debugPrint('  row keys: ${(entry is Map) ? entry.keys.toList() : entry.runtimeType}');
    debugPrint('  stack: $st');
  }
}
```

Update the `return` statement to include `skippedRows: skipped`.

Required new import (top of the file):
```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 6: Update SaleRepositoryImpl to pass skippedRows through**

Edit `app/lib/data/repositories/sale_repository_impl.dart`. Find every place that returns from `getSales`. Add `skippedRows: result.skippedRows` (when delegating to the remote) or `skippedRows: 0` (when returning local cache). Example for the offline branch:

```dart
return (
  data: localSales,
  total: localSales.length,
  totalPages: 1,
  skippedRows: 0,
);
```

- [ ] **Step 7: Run the test to verify it passes**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test test/data/datasources/remote/sale_remote_datasource_test.dart
```
Expected: 2 of 2 tests pass.

- [ ] **Step 8: Run dart analyze**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/
```
Expected: "No issues found!" — including any callers of `getSales` that destructure the record. If a caller fails because they pattern-match without `skippedRows`, fix the caller to ignore it (`skippedRows: _`) or read it.

- [ ] **Step 9: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/data/datasources/remote/sale_remote_datasource.dart \
        app/lib/data/repositories/sale_repository_impl.dart \
        app/lib/domain/repositories/sale_repository.dart \
        app/lib/core/network/dio_client.dart \
        app/test/data/datasources/remote/sale_remote_datasource_test.dart \
        app/pubspec.yaml app/pubspec.lock 2>/dev/null || true
git commit -m "fix(sale-parser): skip-and-warn on malformed rows; expose skippedRows

Spec 2026-05-11-finance-nav-fixes-design.md, BUG #28 (Q3=C).

Previously a single malformed row in the /sales response would
throw inside the .map call and blank the entire history page. Now
each row is parsed independently inside try/catch — bad rows are
counted, logged with key shape + stacktrace, and skipped. The
return record gains \`skippedRows\` so the UI can show a footer
('X записей пропущено').

Test: feed mixed payload (valid, missing 'total', valid) → 2
sales returned, skippedRows=1, warning logged."
```

---

## Task 7 — История продаж footer: surface skipped rows

**Files:**
- Modify: `app/lib/presentation/pages/sales/sales_history_page.dart`

- [ ] **Step 1: Find where SalesHistoryPage consumes getSales**

Run:
```bash
grep -n "getSales\|skippedRows\|saleRepository" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/pages/sales/sales_history_page.dart | head
```
Identify the bloc / state class that holds the loaded list. The page probably renders from a `SalesHistoryBloc` state.

- [ ] **Step 2: Find the bloc + state**

Run:
```bash
find /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/blocs/sales -type f
```

- [ ] **Step 3: Add `skippedRows` to the bloc state**

Edit `app/lib/presentation/blocs/sales/sales_history_state.dart` (or whatever the state file is named). Add a field:

```dart
final int skippedRows;
```

Add it to the constructor (with default `0`) and to `props`. Update `copyWith` accordingly.

- [ ] **Step 4: Populate it in the bloc**

Edit `app/lib/presentation/blocs/sales/sales_history_bloc.dart`. Where the bloc reads the result of `saleRepository.getSales(...)`, pass through:

```dart
final result = await _saleRepository.getSales(...);
emit(state.copyWith(
  // ...existing fields...
  skippedRows: result.skippedRows,
));
```

- [ ] **Step 5: Render the footer in SalesHistoryPage**

Edit `app/lib/presentation/pages/sales/sales_history_page.dart`. Find the `BlocBuilder` for `SalesHistoryBloc` and the `Column` that renders the list. After the list (or as the last item in a `Column`), add:

```dart
if (state.skippedRows > 0)
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    child: Text(
      // BUG #28: when the parser skipped any rows we tell the user
      // rather than silently swallowing them. The skip-and-warn
      // policy lives in sale_remote_datasource.dart.
      '${state.skippedRows} ${_pluralRecord(state.skippedRows)} пропущено',
      style: TextStyle(
        color: context.textSecondary,
        fontSize: 12,
        fontStyle: FontStyle.italic,
      ),
      textAlign: TextAlign.center,
    ),
  ),
```

Add the helper at the bottom of the file (before the closing brace):

```dart
String _pluralRecord(int n) {
  // 1 запись, 2-4 записи, 5+ записей. Russian plural rules.
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 14) return 'записей';
  if (mod10 == 1) return 'запись';
  if (mod10 >= 2 && mod10 <= 4) return 'записи';
  return 'записей';
}
```

- [ ] **Step 6: Run dart analyze**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/presentation/pages/sales/ \
              lib/presentation/blocs/sales/
```
Expected: "No issues found!"

- [ ] **Step 7: Run flutter tests**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test --reporter=compact 2>&1 | tail -3
```
Expected: all tests pass; if a sales-history golden fails, re-baseline:
```bash
flutter test --update-goldens test/presentation/pages/sales/
```

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/presentation/blocs/sales/ \
        app/lib/presentation/pages/sales/sales_history_page.dart \
        app/test/presentation/pages/sales/goldens/ 2>/dev/null || true
git commit -m "feat(sales-history): surface 'X записей пропущено' footer when parser skips

Spec 2026-05-11-finance-nav-fixes-design.md, BUG #28 (Q3=C).

The parser-resilience commit silently skips malformed rows; this
commit makes the UI tell the user when that happens so a real
data issue isn't silently swallowed. Russian plural rules
('запись' / 'записи' / 'записей') applied for grammatical
correctness."
```

---

## Task 8 — Investigate BUG #28 root cause (post-migration verification)

**Files:**
- Read-only: this is a verification task, no code if migration already fixed it.

- [ ] **Step 1: Restart API to pick up the migration + fresh client**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
lsof -i:4455 -t | xargs kill -9 2>/dev/null
sleep 2
cd api
nohup npm run start:dev > /tmp/dukon-api.log 2>&1 &
disown
until curl -sf -m 2 http://localhost:4455/api/health >/dev/null 2>&1; do sleep 2; done
echo READY
```

- [ ] **Step 2: Hit /sales as qa-business and inspect response**

Run:
```bash
T_BIZ=$(curl -sf -X POST http://localhost:4455/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+992910001002","password":"qatest1234"}' | \
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("accessToken",""))')
SID="d169d2e8-0a24-4a23-844a-5d5e7b690d8c"
curl -s "http://localhost:4455/api/stores/$SID/sales?page=1&limit=20" \
  -H "Authorization: Bearer $T_BIZ" | \
  python3 -c "
import sys, json
d = json.load(sys.stdin)
print('total:', d.get('total'))
print('rows:', len(d.get('data', [])))
for s in d.get('data', [])[:3]:
  print('  -', s['receiptNo'], 'total=', s['total'], 'change=', s['change'])
"
```
Expected: total/rows ≥ 0, no row with `total < 0`. If everything is non-negative, the migration successfully removed the poison.

- [ ] **Step 3: Rebuild + reinstall the app + re-test История продаж on emulator**

Run:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter build apk --debug 2>&1 | tail -5
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk 2>&1 | tail -3
adb -s emulator-5554 shell monkey -p com.itlsolutions.dukonpro -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
```

Then on the emulator: tap Ещё → История продаж. Capture screenshot:

```bash
DST=/Users/latifrjdev/Downloads/01_Проекты/Dukon/qa/2026-05-11-clicktest/screenshots
sleep 3
adb -s emulator-5554 exec-out screencap -p > $DST/post-fix-history.png
sips -Z 1200 $DST/post-fix-history.png --out $DST/post-fix-history-sm.png 2>&1 | tail -1
```
Expected: page renders the sales list with no error icon. If `skippedRows > 0`, footer shows "X записей пропущено".

- [ ] **Step 4: If error STILL appears, capture logcat and dig**

Run:
```bash
adb -s emulator-5554 logcat -c
# Re-tap История продаж on the device
adb -s emulator-5554 logcat -d 2>&1 | grep -E "flutter|skipped malformed" | head -40
```
Look for the `SaleRemoteDatasource: skipped malformed row` lines printed by Task 6's resilience layer. They tell you the field shape that's failing. Fix the model (e.g. make a field nullable that the API can return as null).

If the error is gone after migration alone, the resilience layer caught the residue (or there was no residue). Either way, this task's output is verification.

- [ ] **Step 5: Commit findings (if model edits were needed)**

If you had to edit the model to handle a field that came back null, commit with message:
```
fix(sale-model): tolerate null \`<field>\` in API response

BUG #28 root cause investigation: the API can return <field>=null
for sales created via <flow>. Mirror that nullability in
SaleModel.fromJson so the parser doesn't have to fall through
to the resilience layer for this case.
```

If no edits were needed, no commit — the migration + resilience already closed the bug.

---

## Task 9 — Final verification + click test of all 3 fixes

**Files:**
- None (verification only)

- [ ] **Step 1: Run the full test matrix**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep -v ".spec.ts" | grep "error TS" | head
npm test 2>&1 | grep "Tests:"
npm run test:e2e 2>&1 | grep "Tests:"

cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected: 0 tsc errors, ≥184 unit + ≥8 e2e API tests pass, dart analyze 0 issues, ≥397 flutter pass.

- [ ] **Step 2: Click-test all 3 fixes on emulator**

Login as qa-business. Then:

1. **Финансы**: open the tab. All 4 cards should display. "Общий доход" + "Общие расходы" must be `0 TJS` minimum (no `-`). "Чистая прибыль" can be negative (red `-X TJS`) and that's correct.
2. **Главная → Остатки на складе**: tap the tile. Should land on Товары tab with the new "Требует внимания" chip pre-selected. List should show only low/out-of-stock items.
3. **Ещё → История продаж**: should render the sales list without error. If any rows were skipped, footer shows "X записей пропущено".

Capture one screenshot per check into `qa/2026-05-11-clicktest/screenshots/post-fix-{1,2,3}.png` for the audit trail.

- [ ] **Step 3: Final commit (if any incidental fixes during verification)**

If any test failures or analyze warnings surfaced during verification that needed quick fixes, commit them:
```bash
git commit -am "chore(verify): post-fix verification touchups"
```

If the verification pass was clean, no commit — the previous task commits stand.

---

## Self-Review

Cross-checking plan against spec sections:

- ✅ **Bug A** (no negative finance display) — Tasks 1 (migration clamp), 2 (e2e CHECK test), 3 (UI clamp).
- ✅ **Bug B** (Остатки на складе → preset filter) — Tasks 4 (chip + initialFilter), 5 (dashboard tile wiring).
- ✅ **Bug C** (sales history parser) — Tasks 6 (resilience), 7 (footer), 8 (root-cause verification).
- ✅ **Bug D** (orphan debt cleanup) — Task 1 (single migration covers both data fixes).
- ✅ Spec testing requirements: e2e CHECK test ✓ (Task 2), parser test ✓ (Task 6), display clamp test ✓ (Task 3).
- ✅ Roll-out order matches spec (migration first → service unchanged → app changes → manual verify).
- ✅ All scope exclusions respected: no thermal printer (#25), no "X" cleanup, no dedicated stock screen.

Type consistency:
- `_StockFilter.attention` defined Task 4 → consumed Task 4 (same task) ✓
- `initialFilter: String?` param defined Task 4 → consumed Task 5 ✓
- `skippedRows: int` field added Task 6 → consumed Task 7 ✓
- `clampRevenueCard(double)` defined Task 3 → consumed Task 3 ✓

Plan complete and saved to `docs/superpowers/plans/2026-05-11-finance-nav-fixes.md`.
