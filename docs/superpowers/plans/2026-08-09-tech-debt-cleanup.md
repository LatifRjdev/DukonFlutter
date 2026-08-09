# Tech Debt Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close out five small, independent tech-debt items surfaced by code review during the `feature/deferred-items-cleanup` branch (already merged to `main`): a self-heal clobbering risk on `hasBatchProfitability`, a maintainability wart and a validation gap in the e-commerce webhook handler, an imprecise HTTP status code on a transient error path, and a missing search-clear affordance on the product-mapping screen.

**Architecture:** Each task is a narrow, single-concern fix in an already-well-tested file. No new features, no schema changes beyond what's already there, no cross-task dependencies — any task can be implemented and merged independently of the others.

**Tech Stack:** NestJS backend (`api/`), Prisma/PostgreSQL, class-validator DTOs; Flutter mobile app (`app/`) with `flutter_bloc`.

---

## Spec coverage

| Backlog item (from review) | Task |
|---|---|
| `hasBatchProfitability` self-heal can silently revert an admin's manual override on START | Task 1 |
| Duplicated `mappingByExternalId.get(...)!.productId` → `productById.get(...)!` → `item.price ?? Number(product.sellPrice)` pattern repeated ~7 times in `createOrder()` | Task 2 |
| `EcommerceOrderItemDto.price` has no `maxDecimalPlaces` constraint, so `Sale.total` can diverge from `SUM(SaleItem.total)` by a cent or two on >2dp input | Task 3 |
| The stock-race retry path throws a 422 (semantically "don't retry") when it should signal "safe to retry" | Task 4 |
| Product-mapping search field has no clear affordance and doesn't match the shared `AppSearchBar` styling used elsewhere in the app | Task 5 |

Explicitly out of scope (decided when this plan was written, not oversights):
- Hardcoded Russian UI strings not going through `AppLocalizations` — this is pre-existing, app-wide debt (46/82 pages already use it, 36 don't), not something introduced by the branch that surfaced these items. A proper fix means auditing and updating `.arb`/`.strings` files for `ru`/`tg`/`uz` across many files — a different kind of task from the narrow fixes here, better suited to its own dedicated plan.
- `hasZakat`/`hasInvestments` do **not** need a self-heal fix — investigated during planning: both already have proper one-time backfill migrations (`20260516000000_g2_zakat_tier_flag`, `20260516160000_investments_hardening`) that correctly set their values per-plan at the time the columns were added. There is no live data-correctness gap for these two, unlike `hasEcommerceIntegration` (which had no such migration) or `hasBatchProfitability` (which has the clobbering self-heal but not a data-correctness gap).

---

### Task 1: Stop `hasBatchProfitability`'s self-heal from clobbering an admin override on START

**Files:**
- Modify: `api/src/modules/subscriptions/subscriptions.service.ts`
- Test: `api/src/modules/subscriptions/subscriptions.service.spec.ts`

**Context:** `seedPlanConfigs()` runs on every server boot (`onModuleInit`). Its `upsert` call's `update:` clause currently does:
```typescript
update: {
  hasBatchProfitability: config.hasBatchProfitability,
  hasEcommerceIntegration: config.hasEcommerceIntegration,
},
```
`config.hasBatchProfitability` is `false` for START and `true` for BUSINESS/PREMIUM (set explicitly on all three plan literals). Since this write is unconditional, if an admin uses the plan-config editor (`admin/app/(admin)/subscriptions/plans/page.tsx`, wired via `admin.service.ts`'s `updatePlan()`) to manually turn `hasBatchProfitability` **on** for the START plan, the very next server restart silently reverts it back to `false` — no log, no audit entry, no error.

This is the exact same bug class that was already found and fixed for `hasEcommerceIntegration` earlier on `feature/deferred-items-cleanup` (see the comments already in this file, and commits `19ddd1f`/`6b1178f` in git history). The fix is the same pattern: only ever write `true` via self-heal, never write `false` — so the self-heal can correct a plan that's missing the "should be true" value, but can never force a plan back toward `false` and clobber an admin's deliberate override.

Read the current file first (`api/src/modules/subscriptions/subscriptions.service.ts`, the `plans` array inside `seedPlanConfigs()`, currently around lines 43-125) to confirm the structure below still matches — if it doesn't, stop and report rather than guessing.

- [ ] **Step 1: Write the failing test**

Add to `api/src/modules/subscriptions/subscriptions.service.spec.ts`, inside the existing `describe('SubscriptionsService — seedPlanConfigs', ...)` block (search for that describe block — it already contains the analogous `hasEcommerceIntegration` tests added for the earlier fix; match its exact style, including how it captures `upsertCalls` and builds the `byPlan` lookup):

```typescript
  it('should not include hasBatchProfitability in the update payload for START, so an admin override on START self-heals safely', async () => {
    await service.onModuleInit();

    const upsertCalls = (prisma.subscriptionPlanConfig.upsert as jest.Mock).mock
      .calls.map((args: any[]) => args[0]);
    const byPlan = Object.fromEntries(
      upsertCalls.map((c) => [c.where.plan, c]),
    );

    expect(byPlan.START.update.hasBatchProfitability).toBeUndefined();
    // BUSINESS/PREMIUM keep the existing forced-true self-heal — unchanged behavior.
    expect(byPlan.BUSINESS.update.hasBatchProfitability).toBe(true);
    expect(byPlan.PREMIUM.update.hasBatchProfitability).toBe(true);
  });
```

(If the existing test file's `upsertCalls`/`byPlan` construction differs slightly from this snippet — e.g. a different variable name already exists earlier in the same `it` block from a previous test — reuse the file's real pattern rather than introducing a second one. Read the two adjacent `hasEcommerceIntegration` tests immediately before writing this one.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && npx jest subscriptions.service.spec.ts -t "should not include hasBatchProfitability"`
Expected: FAIL — `byPlan.START.update.hasBatchProfitability` is currently `false`, not `undefined`.

- [ ] **Step 3: Remove the explicit `false` from the START plan literal**

In the same file, in the `plans` array, the `START` object currently has a line `hasBatchProfitability: false,` (alongside the `hasEcommerceIntegration`-omission comment already there from the earlier fix). Delete that line, and add a comment mirroring the existing `hasEcommerceIntegration` comment style directly above the START object:

```typescript
      {
        // hasBatchProfitability deliberately omitted (not `false`) — same
        // reasoning as hasEcommerceIntegration above: forcing it explicitly
        // would make the self-heal below clobber an admin's manual
        // override of this flag on START via the plan-config editor.
        // hasEcommerceIntegration deliberately omitted (not `false`) — see
        // the update: clause below.
        plan: 'START' as const,
        price: 200,
        maxProducts: 500,
        maxStaff: 2,
        maxDiscounts: 0,
        hasReportsAll: false,
        hasExport: false,
        hasTelegram: false,
        hasAllPush: false,
        hasDelivery: false,
        hasInventory: false,
        hasZakat: false,
        hasInvestments: false,
      },
```

(BUSINESS and PREMIUM's `hasBatchProfitability: true,` lines stay exactly as they are — this fix is scoped to START only, matching how the `hasEcommerceIntegration` fix only omitted the field on the plans where it defaults to `false`.)

- [ ] **Step 4: Update the `update:` clause's comment to reflect both omitted fields**

The `update:` clause's existing comment block (the multi-paragraph one already explaining the `hasEcommerceIntegration` omission) should be extended to also mention `hasBatchProfitability` now follows the same rule for START. Reword it so it reads as one coherent explanation covering both fields rather than two disconnected comments — for example:

```typescript
        // update: {} previously meant existing rows in a running DB never
        // picked up newly-added flags; patch the field explicitly so
        // existing rows self-heal on next server boot.
        //
        // hasEcommerceIntegration is only set on the PREMIUM literal above
        // (omitted, not `false`, on START/BUSINESS), and hasBatchProfitability
        // is only set as `false` on BUSINESS/PREMIUM (omitted on START) — so
        // both resolve to `undefined` for the plans where forcing a write
        // isn't needed to fix a missing "should be true" default. Prisma
        // treats `undefined` as "field not provided" and skips the write,
        // so this self-heal can correct a plan missing its true value but
        // can never clobber an admin's manual override toward `false` on
        // START via the plan-config editor.
        //
        // hasZakat/hasInvestments/hasLoyalty are NOT listed here at all —
        // unlike hasEcommerceIntegration, both already have their own
        // one-time backfill migrations from when their columns were added
        // (20260516000000_g2_zakat_tier_flag, 20260516160000_investments_hardening,
        // 20260706000001_loyalty_plan_flags), so there's no live data gap
        // for them to self-heal. This update: block is an ad-hoc list of
        // fields that specifically needed this treatment, not a general
        // policy — don't add a new flag here without checking whether it
        // actually has the same gap first.
        update: {
          hasBatchProfitability: config.hasBatchProfitability,
          hasEcommerceIntegration: config.hasEcommerceIntegration,
        },
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd api && npx jest subscriptions.service.spec.ts -t "should not include hasBatchProfitability"`
Expected: PASS

- [ ] **Step 6: Run the full spec file and fix the now-broken pre-existing assertion**

Run: `cd api && npx jest subscriptions.service.spec.ts`
Expected: at least two pre-existing failures at this point — both confirmed during planning, in the same `describe('SubscriptionsService — seedPlanConfigs', ...)` block:

1. `'should seed hasBatchProfitability=false for START and true for BUSINESS/PREMIUM'` currently asserts `expect(byPlan.START.create.hasBatchProfitability).toBe(false);`. Removing `hasBatchProfitability: false` from the START literal (Step 3) means `config.hasBatchProfitability` is `undefined` for START on **both** the `create:` and `update:` payloads (they're built from the same plan literal) — change this assertion to `expect(byPlan.START.create.hasBatchProfitability).toBeUndefined();`. The BUSINESS/PREMIUM assertions in the same test (`.toBe(true)`) are unaffected.

2. `'should patch hasBatchProfitability on the update path too, so an existing row self-heals on next boot'` currently has `expect(byPlan.START.update).toEqual({ hasBatchProfitability: false, hasEcommerceIntegration: undefined });` — change `hasBatchProfitability: false` to `hasBatchProfitability: undefined` in that object. The BUSINESS assertion (`hasBatchProfitability: true`) and PREMIUM assertion (`hasBatchProfitability: true`) in the same test are unaffected — only START's forced value changes.

Both of these mirror exactly how `6b1178f` already handled the analogous `hasEcommerceIntegration` case on this branch's history — match that same style (the tests immediately following these two, `'should seed hasEcommerceIntegration=true for PREMIUM only...'` and `'should patch hasEcommerceIntegration=true on the update path...'`, are the direct precedent to copy from).

Re-run: `cd api && npx jest subscriptions.service.spec.ts`
Expected: all tests pass now, including your new test from Step 1 and the fixed pre-existing one.

Run: `cd api && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add api/src/modules/subscriptions/subscriptions.service.ts api/src/modules/subscriptions/subscriptions.service.spec.ts
git commit -m "fix(subscriptions): stop hasBatchProfitability self-heal from clobbering an admin override on START"
```

---

### Task 2: Extract the duplicated line-item price/product resolution in the e-commerce webhook handler

**Files:**
- Modify: `api/src/modules/ecommerce/ecommerce-orders.service.ts`
- Test: `api/src/modules/ecommerce/ecommerce-orders.service.spec.ts` (no new tests required — this is a pure refactor; the existing 19 tests in this file are the safety net and must all still pass unchanged)

**Context:** Inside `createOrder()`, the pattern `mappingByExternalId.get(item.externalProductId)!.productId` → `productById.get(productId)!` → (sometimes) `item.price ?? Number(product.sellPrice)` is re-derived independently at several points: the stock-sufficiency validation loop, the `computedTotal` reduce, the `saleItemsData` map inside the transaction, the `stockMovement.createMany` data map, and the final `pushStockUpdate` loop. Read the current file in full first (`api/src/modules/ecommerce/ecommerce-orders.service.ts`) to find every occurrence — there should be around 5-7 — before making changes, since exact line numbers will have shifted from what's described here.

This is purely a maintainability fix: if the lookup or price-resolution logic ever needs to change, right now it must change in every one of those places, and a partial edit would silently make `computedTotal`'s validation and the persisted `Sale`/`SaleItem` records disagree — undermining the whole point of the `totalAmount` cross-check.

- [ ] **Step 1: Confirm the current test suite passes as a baseline**

Run: `cd api && npx jest ecommerce-orders.service.spec.ts`
Expected: PASS, 19/19 (confirmed as the current count when this plan was written — note the number so you can confirm it's unchanged after the refactor).

- [ ] **Step 2: Introduce a `resolved` array (product lookup only, no price yet) right after `productById` is built**

Confirmed during planning: `productById.get(productId)` can legitimately return `undefined` (product deleted after being externally mapped), and the existing stock-sufficiency loop's `!product ||` check is what handles that gracefully today (notifies the store, throws a friendly `UnprocessableEntityException`). **No existing test actually exercises this specific "product missing entirely" sub-case** (the one test named for this rejection path, `'rejects the whole order (422) and notifies the owner when stock is insufficient'`, only tests low-quantity, not a fully-absent product) — but the code path exists on purpose and must not regress into an unhandled crash just because nothing currently pins it. Do NOT use a non-null assertion (`!`) when resolving `product` here, and do NOT compute `unitPrice` in this step — that has to wait until after the stock-sufficiency check below has confirmed every product actually exists.

Immediately after the existing line that builds `productById`, and immediately before the stock-sufficiency validation loop that currently reads `for (const item of items) { const productId = mappingByExternalId.get(item.externalProductId)!.productId; ... }`, insert:

```typescript
    // Single source of truth for each item's mapped productId + product
    // record, reused below instead of re-deriving mappingByExternalId →
    // productById independently at each call site. Deliberately does NOT
    // resolve unitPrice yet, and deliberately does not `!`-assert product
    // is defined — a product can legitimately be missing here (deleted
    // after being externally mapped), and that has to fail gracefully via
    // the stock-sufficiency check right below, not crash here.
    const resolved = items.map((item) => {
      const productId = mappingByExternalId.get(
        item.externalProductId,
      )!.productId;
      const product = productById.get(productId);
      return { item, productId, product };
    });
```

- [ ] **Step 3: Replace the stock-sufficiency loop to iterate `resolved` instead of `items`**

The loop currently looks like:
```typescript
    for (const item of items) {
      const productId = mappingByExternalId.get(
        item.externalProductId,
      )!.productId;
      const product = productById.get(productId);
      if (!product || product.quantity < item.quantity) {
        ...
      }
    }
```
Change it to iterate `resolved` and use the already-computed `productId`/`product`:
```typescript
    for (const { item, productId, product } of resolved) {
      if (!product || product.quantity < item.quantity) {
        ...
      }
    }
```
(The body of the `if` block — the notification call and the thrown `UnprocessableEntityException` — stays exactly as it is; only the loop header and the removal of the now-redundant `const productId =`/`const product =` lines change. This loop still throws before any code past it runs if a product is missing or insufficient, exactly as today.)

- [ ] **Step 4: Build a second array, `priced`, that adds `unitPrice` — only reachable once every product is confirmed present**

Immediately after the stock-sufficiency loop from Step 3 (which has now guaranteed, by not having thrown, that every `resolved[i].product` is defined), add:

```typescript
    // Only reachable once the loop above has confirmed every item's
    // product exists and has sufficient stock — safe to assert non-null
    // here, unlike in `resolved` above.
    const priced = resolved.map(({ item, productId, product }) => ({
      item,
      productId,
      product: product!,
      unitPrice: item.price ?? Number(product!.sellPrice),
    }));
```

All subsequent steps in this task read from `priced`, not `resolved` — `resolved` is only consumed by the Step 3 stock-sufficiency loop.

- [ ] **Step 5: Replace the `computedTotal` reduce to use `priced`**

Currently:
```typescript
    const computedTotal = items.reduce((sum, item) => {
      const productId = mappingByExternalId.get(
        item.externalProductId,
      )!.productId;
      const product = productById.get(productId)!;
      const unitPrice = item.price ?? Number(product.sellPrice);
      return sum + unitPrice * item.quantity;
    }, 0);
```
Change to:
```typescript
    const computedTotal = priced.reduce(
      (sum, { item, unitPrice }) => sum + unitPrice * item.quantity,
      0,
    );
```

- [ ] **Step 6: Replace the `saleItemsData` map (inside the `$transaction` callback) to use `priced`**

Currently:
```typescript
        const saleItemsData = items.map((item) => {
          const productId = mappingByExternalId.get(
            item.externalProductId,
          )!.productId;
          const product = productById.get(productId)!;
          const unitPrice = item.price ?? Number(product.sellPrice);
          return {
            productId,
            productName: product.name,
            quantity: item.quantity,
            unitPrice,
            costPrice: product.costPrice ?? undefined,
            total: unitPrice * item.quantity,
          };
        });
```
Change to:
```typescript
        const saleItemsData = priced.map(({ item, productId, product, unitPrice }) => ({
          productId,
          productName: product.name,
          quantity: item.quantity,
          unitPrice,
          costPrice: product.costPrice ?? undefined,
          total: unitPrice * item.quantity,
        }));
```

- [ ] **Step 7: Replace the `stockMovement.createMany` data map and the final `pushStockUpdate` loop**

Both of these currently re-derive `productId` via `mappingByExternalId.get(item.externalProductId)!.productId` from a `for (const item of items)` or `items.map(...)`. Neither needs `unitPrice`, so either `resolved` or `priced` would work as the source — use `priced` for consistency (it's already guaranteed non-null and is what the rest of the method reads from past this point). Replace each with the equivalent `priced.map(({ item, productId }) => ...)` / `for (const { productId } of priced)` form, preserving the rest of each block's logic exactly (the stock-race-guard `updateMany` loop is more involved — it also reads `item.quantity` and throws `StockConflictError` — make sure you only change how `productId` is obtained, not any of the surrounding control flow).

- [ ] **Step 8: Search for any remaining occurrences**

Run: `grep -n "mappingByExternalId.get" api/src/modules/ecommerce/ecommerce-orders.service.ts`
Expect exactly 2 remaining occurrences: the `productIds` bootstrap line (used to build the `product.findMany` query that `productById` — and therefore `resolved` — depends on; it structurally cannot read from `resolved`, since `resolved` doesn't exist yet at that point), and the one inside `resolved`'s own construction (Step 2). Every other call site should now read from `resolved` (stock-sufficiency loop only) or `priced` (everywhere else). (Corrected after implementation: an earlier version of this step said "the only remaining occurrence," which undercounted the legitimate bootstrap line by one — confirmed via spec review.)

- [ ] **Step 9: Run the full test suite**

Run: `cd api && npx jest ecommerce-orders.service.spec.ts`
Expected: PASS, same test count as the Step 1 baseline, zero behavior change.

Run: `cd api && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 10: Commit**

```bash
git add api/src/modules/ecommerce/ecommerce-orders.service.ts
git commit -m "refactor(ecommerce): extract repeated item->product->unitPrice resolution out of duplicated call sites"
```

---

### Task 3: Add `maxDecimalPlaces` validation to the webhook's item price field

**Files:**
- Modify: `api/src/modules/ecommerce/dto/ecommerce-webhook.dto.ts`
- Test: `api/src/modules/ecommerce/dto/ecommerce-webhook.dto.spec.ts` (check this file exists — it's referenced in this project's test output; if it doesn't exist under this exact name, find wherever this DTO's validation is currently tested and add to that file instead)

**Context:** `EcommerceOrderItemDto.price` is currently:
```typescript
  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  price?: number;
```
`Sale.total` and `SaleItem.total` are both `Decimal(12,2)` in the Prisma schema, but nothing stops an external site from sending a `price` with 3+ decimal places (e.g. `19.999`). Since `Sale.total` is now computed as one sum (`computedTotal`, from Task 2's `resolved` array) while each `SaleItem.total` is rounded independently per line by Postgres's `Decimal(12,2)` column, prices with more than 2 decimal places can make the two sides diverge by a cent or two. Constraining `price` to at most 2 decimal places at the validation boundary closes this at the source.

- [ ] **Step 1: Read the current DTO and its existing test file**

Read `api/src/modules/ecommerce/dto/ecommerce-webhook.dto.ts` in full to confirm the `price` field still matches what's shown above (decorators may have shifted). Read `api/src/modules/ecommerce/dto/ecommerce-webhook.dto.spec.ts` in full — this file already exists and validates the *whole* `EcommerceWebhookDto` (with `items` nested inside), via a `validPayload(overrides)` helper and a `validateDto(plain)` helper that does `plainToInstance(EcommerceWebhookDto, plain)` + `validate(dto)`. Match this file's real convention — do not instantiate `EcommerceOrderItemDto` standalone, since nested-DTO nullability/transform quirks (already a documented regression this file guards against, per the comment above its `ValidateNested` test) mean validating the item in isolation may not exercise the same code path as validating it through the parent.

- [ ] **Step 2: Write the failing test**

Add two tests using the file's own `validPayload`/`validateDto` helpers, asserting a `price` with 3 decimal places fails validation (nested under `items`) and a `price` with exactly 2 decimal places passes:

```typescript
  it('should reject an item price with more than 2 decimal places', async () => {
    const errors = await validateDto(
      validPayload({
        items: [{ externalProductId: 'sku-1', quantity: 2, price: 19.999 }],
      }),
    );
    expect(errors).not.toHaveLength(0);
  });

  it('should accept an item price with exactly 2 decimal places', async () => {
    const errors = await validateDto(
      validPayload({
        items: [{ externalProductId: 'sku-1', quantity: 2, price: 19.99 }],
      }),
    );
    expect(errors).toHaveLength(0);
  });
```

(If asserting a more specific nested-error shape than "not empty" turns out to be easy given how `ValidateNested` surfaces child errors in this codebase's class-validator setup — check the existing `ValidateNested`-related test in this same file for the pattern it already uses to inspect nested errors — prefer the more specific assertion. `errors).not.toHaveLength(0)` is the acceptable minimum if nested error inspection turns out to be awkward.)

- [ ] **Step 3: Run test to verify it fails**

Run: `cd api && npx jest ecommerce-webhook.dto.spec.ts -t "more than 2 decimal places"` (adjust the file name/path to whatever you found in Step 1)
Expected: FAIL — the current `@IsNumber()` with no options accepts any number of decimal places.

- [ ] **Step 4: Add the constraint**

Change:
```typescript
  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  price?: number;
```
to:
```typescript
  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  price?: number;
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd api && npx jest ecommerce-webhook.dto.spec.ts` (the whole file)
Expected: PASS, including both new tests and everything pre-existing.

- [ ] **Step 6: Run the broader e-commerce test suite and typecheck**

Run: `cd api && npx jest ecommerce`
Expected: PASS — in particular, re-run `ecommerce-orders.service.spec.ts` and confirm none of its existing fixtures (`makeOrderCreatedDto()` and its per-test overrides) use a `price` with more than 2 decimal places, which would now fail DTO validation before even reaching the service logic those tests exercise. If any fixture does use a >2dp price, fix the fixture's value rather than loosening the new constraint.

Run: `cd api && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add api/src/modules/ecommerce/dto/ecommerce-webhook.dto.ts api/src/modules/ecommerce/dto/ecommerce-webhook.dto.spec.ts
git commit -m "fix(ecommerce): reject webhook item prices with more than 2 decimal places"
```

---

### Task 4: Use a 409 instead of a 422 for the transient stock-race retry path

**Files:**
- Modify: `api/src/modules/ecommerce/ecommerce-orders.service.ts`
- Test: `api/src/modules/ecommerce/ecommerce-orders.service.spec.ts`

**Context:** `createOrder()` has three distinct rejection paths that all currently throw `UnprocessableEntityException` (HTTP 422):
1. No product mapping for a line item — permanent until someone fixes the mapping. 422 is correct.
2. Insufficient stock (checked before the transaction) — permanent until stock is restocked. 422 is correct.
3. The atomic `updateMany` stock guard inside the `$transaction` loses a race with a concurrent in-store sale (`StockConflictError`, caught after the transaction rolls back) — this is a **transient** condition. The error message even already says "retry the webhook" / "Повторите попытку". 422 ("Unprocessable Entity") semantically means "the request is well-formed but there's a domain-rule reason it can never succeed as-is" — the opposite of "safe to retry unchanged." `409 Conflict` is the correct status for "this failed due to a temporary state conflict, retry is expected to work."

Only the `StockConflictError` catch path needs to change — the other two rejection paths (missing mapping, insufficient stock, and the `totalAmount` mismatch check) all stay on 422, since those really are permanent-until-fixed rejections.

- [ ] **Step 1: Read the current catch block**

Read `api/src/modules/ecommerce/ecommerce-orders.service.ts`'s `catch (err)` block inside `createOrder()` (search for `StockConflictError`) to confirm it still matches:
```typescript
    } catch (err) {
      if (err instanceof StockConflictError) {
        void this.notifications.sendToStoreUsers(
          storeId,
          'Заказ с сайта отклонён',
          `Заказ ${dto.externalOrderId} отклонён — остаток товара изменился во время обработки заказа (конкурентная продажа в магазине). Повторите попытку.`,
          'ECOMMERCE_ORDER_REJECTED',
        );
        throw new UnprocessableEntityException(
          `Stock for product ${err.productId} changed concurrently — retry the webhook`,
        );
      }
      throw err;
    }
```

- [ ] **Step 2: Write the failing test**

Find the existing test `'rejects the whole order (422) and notifies the owner when the atomic stock guard detects a concurrent race'` in `api/src/modules/ecommerce/ecommerce-orders.service.spec.ts`. Update its title (it will no longer be a 422) and strengthen its assertion to check the actual thrown exception type/status rather than just `.rejects.toThrow()`. Match this file's existing import style (check whether `ConflictException` needs importing into the spec file, or whether the test instead checks `.getStatus()` on the caught error):

```typescript
  it('rejects the whole order (409, retryable) and notifies the owner when the atomic stock guard detects a concurrent race', async () => {
    (prisma.__tx.product.updateMany as jest.Mock).mockResolvedValue({
      count: 0,
    });

    await expect(
      service.handleWebhook('store-1', 'valid-key', makeOrderCreatedDto()),
    ).rejects.toMatchObject({ status: 409 });
    expect(prisma.__tx.sale.create).toHaveBeenCalled(); // sale.create ran, then the transaction rolled back
    expect(notifications.sendToStoreUsers).toHaveBeenCalledWith(
      'store-1',
      expect.any(String),
      expect.stringContaining('site-order-1'),
      'ECOMMERCE_ORDER_REJECTED',
    );
  });
```

(NestJS HTTP exceptions expose their status via `.getStatus()`, and `.rejects.toMatchObject({ status: 409 })` works against the exception's own `status` property that `HttpException` sets internally — if this doesn't match how NestJS exceptions serialize in this test environment, use `.rejects.toHaveProperty('status', 409)` or catch the error explicitly and call `.getStatus()` on it instead. Check what pattern, if any, other tests in this codebase already use for asserting a specific HTTP status from a thrown NestJS exception — search `grep -rn "getStatus()\|toMatchObject({ status" api/src/` — and match that convention rather than guessing.)

- [ ] **Step 3: Run test to verify it fails**

Run: `cd api && npx jest ecommerce-orders.service.spec.ts -t "atomic stock guard"`
Expected: FAIL — currently throws with status 422, not 409.

- [ ] **Step 4: Change the exception type**

Add `ConflictException` to the existing `@nestjs/common` import at the top of `ecommerce-orders.service.ts` (it currently imports `ForbiddenException, NotFoundException, UnauthorizedException, UnprocessableEntityException` from `@nestjs/common` — add `ConflictException` to that same import statement rather than a new one).

Change the throw inside the `StockConflictError` catch block from:
```typescript
        throw new UnprocessableEntityException(
          `Stock for product ${err.productId} changed concurrently — retry the webhook`,
        );
```
to:
```typescript
        throw new ConflictException(
          `Stock for product ${err.productId} changed concurrently — retry the webhook`,
        );
```

Also update the comment block directly above the `throw new StockConflictError(productId);` line further up in the same method (inside the `$transaction` callback) if it references "422" specifically — search for any comment mentioning 422 near that throw site and update it to reference 409 instead, so the two comments (at the throw site and at the catch site) stay consistent with each other.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd api && npx jest ecommerce-orders.service.spec.ts -t "atomic stock guard"`
Expected: PASS

- [ ] **Step 6: Run the full file and typecheck**

Run: `cd api && npx jest ecommerce-orders.service.spec.ts`
Expected: all tests pass, including the ones from Task 2's refactor if that task landed first (this task has no ordering dependency on Task 2, but if both are implemented in the same worktree sequentially, make sure this change is applied on top of whatever state the file is in).

Run: `cd api && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add api/src/modules/ecommerce/ecommerce-orders.service.ts api/src/modules/ecommerce/ecommerce-orders.service.spec.ts
git commit -m "fix(ecommerce): use 409 instead of 422 for the retryable stock-race conflict"
```

---

### Task 5: Add a clear button to `AppSearchBar` and use it on the product-mapping screen

**Files:**
- Modify: `app/lib/presentation/widgets/common/app_search_bar.dart`
- Modify: `app/lib/presentation/pages/settings/ecommerce_product_mapping_page.dart`
- Test: `app/test/presentation/widgets/common/app_search_bar_test.dart` (create — this shared widget currently has no dedicated test file; check first in case one already exists under a different name)
- Test: `app/test/presentation/pages/settings/ecommerce_product_mapping_page_test.dart` (extend existing)

**Context:** `AppSearchBar` (`app/lib/presentation/widgets/common/app_search_bar.dart`) is the shared search-field component used elsewhere in the app (currently one consumer: `app/lib/presentation/pages/stock/stock_intake_page.dart`). It has no clear/reset affordance — a code review of the product-mapping screen's search feature (added in an earlier task on `feature/deferred-items-cleanup`) flagged both (a) that screen not reusing this shared component at all, styling it inconsistently with the rest of the app, and (b) no clear button anywhere. This task fixes both: extends `AppSearchBar` itself with a clear button (benefiting every current and future consumer, not just this one screen), then switches the product-mapping screen to use it.

`AppSearchBar` is currently a `StatelessWidget` that optionally accepts an external `controller`; if none is given, the underlying `TextField` manages its own internal controller invisibly. To show/hide a clear button reactively based on whether the field has text, the widget needs to observe controller changes — this means converting it to a `StatefulWidget` that owns a controller when the caller doesn't supply one (disposing it only if it created it), and listens for text changes to trigger a rebuild. This mirrors the exact pattern already established in this codebase for `_CopyableField` in `ecommerce_settings_page.dart` (converted from Stateless to Stateful for an analogous reason, from an earlier task on this same branch) — read that widget first for the house style on this kind of conversion (owns-vs-borrows-controller, listener add/remove in `initState`/`dispose`).

The clear button and the existing `onScanTap` button both use the `TextField`'s single `suffixIcon` slot, so this task keeps them mutually exclusive: **when `onScanTap` is provided, it takes priority and the clear button never shows** (this preserves `stock_intake_page.dart`'s current appearance, since barcode scanning is more important there than search-clearing). When `onScanTap` is not provided (the product-mapping screen's case), the clear button appears whenever the field has text, and disappears when empty.

- [ ] **Step 1: Read the current `AppSearchBar` and the `_CopyableField` reference pattern**

Read `app/lib/presentation/widgets/common/app_search_bar.dart` in full, and `app/lib/presentation/pages/settings/ecommerce_settings_page.dart`'s `_CopyableField`/`_CopyableFieldState` classes in full, before writing any code.

- [ ] **Step 2: Write the failing widget test for `AppSearchBar`**

Create `app/test/presentation/widgets/common/app_search_bar_test.dart` (check it doesn't already exist under this or a similar name first — if a test file for this widget exists anywhere, extend that one instead). Use this codebase's standard `testWidgets`/`pumpWidget` conventions (check a sibling widget test file, e.g. anything under `app/test/presentation/widgets/`, for the exact `MaterialApp`-wrapping helper this project uses, if one exists — reuse it rather than inventing a new one):

```dart
  testWidgets('shows a clear button once text is entered and it clears the field on tap', (tester) async {
    final controller = TextEditingController();
    String? lastOnChanged;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchBar(
            controller: controller,
            onChanged: (v) => lastOnChanged = v,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.close), findsNothing);

    await tester.enterText(find.byType(TextField), 'молоко');
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(lastOnChanged, '');
  });

  testWidgets('never shows a clear button when onScanTap is provided', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchBar(
            controller: controller,
            onScanTap: () {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'молоко');
    await tester.pump();

    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
  });
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/presentation/widgets/common/app_search_bar_test.dart`
Expected: FAIL — no clear button exists yet.

- [ ] **Step 4: Convert `AppSearchBar` to a `StatefulWidget` with a clear button**

Replace the full contents of `app/lib/presentation/widgets/common/app_search_bar.dart` with:

```dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_shadows.dart';

class AppSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onScanTap;

  const AppSearchBar({
    super.key,
    this.controller,
    this.hint = 'Поиск...',
    this.onChanged,
    this.onScanTap,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final showClear = widget.onScanTap == null && _controller.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        boxShadow: isDark ? null : AppShadows.sm,
        border: isDark ? Border.all(color: theme.colorScheme.outline) : null,
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          suffixIcon: widget.onScanTap != null
              ? IconButton(
                  icon: Icon(Icons.qr_code_scanner, color: theme.colorScheme.primary),
                  onPressed: widget.onScanTap,
                )
              : (showClear
                  ? IconButton(
                      icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      onPressed: _clear,
                    )
                  : null),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/presentation/widgets/common/app_search_bar_test.dart`
Expected: PASS

- [ ] **Step 6: Confirm the existing consumer (`stock_intake_page.dart`) still works**

Run: `cd app && flutter analyze lib/presentation/pages/stock/stock_intake_page.dart lib/presentation/widgets/common/app_search_bar.dart`
Expected: no issues.

Find and run whatever existing test(s) cover `stock_intake_page.dart` (search `find app/test -iname "*stock_intake*"`) — expected: still PASS unchanged, since that screen doesn't pass `onScanTap` and gains only a new (additive, non-breaking) clear button.

- [ ] **Step 7: Read the current product-mapping page's search implementation**

Read `app/lib/presentation/pages/settings/ecommerce_product_mapping_page.dart` in full (it's a small file). Find the current bare `TextField` used for search (added by an earlier task on this branch — it has `key: const Key('mapping-search-field')`, a `hintText`, a search prefix icon, and reads from `_searchController`).

- [ ] **Step 8: Replace the bare `TextField` with `AppSearchBar`**

Replace the `Padding`-wrapped `TextField` block with a `Padding`-wrapped `AppSearchBar`, preserving the existing `Key('mapping-search-field')` (move it onto the `AppSearchBar` itself, not a child), the existing hint text, and the existing `controller: _searchController` wiring — `onChanged` should still trigger the same `setState(() {})` rebuild the current implementation uses (re-derive the query from `_searchController.text.trim().toLowerCase()` in `build()`, unchanged from the current implementation — this task only changes which widget renders the field, not the filtering logic itself):

```dart
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppSearchBar(
                    key: const Key('mapping-search-field'),
                    controller: _searchController,
                    hint: 'Поиск по названию товара',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
```

(Remove the old `TextField`'s `decoration: const InputDecoration(...)` block entirely — `AppSearchBar` supplies its own styling. Do not change anything else in this file — the filtered-list computation, the empty-state messages, the row `ListView.separated`, and every other `Key`/test hook stay exactly as they are.)

- [ ] **Step 9: Update the existing widget test file for any now-invalid assumptions**

Read `app/test/presentation/pages/settings/ecommerce_product_mapping_page_test.dart` in full. The existing tests find the search field via `find.byKey(const Key('mapping-search-field'))` and type into it via `tester.enterText(...)` — since `AppSearchBar` wraps its `TextField` internally, confirm `find.byKey(...)` still resolves correctly (it should — the `Key` is now on `AppSearchBar`, and Flutter's `enterText`/`find.text` finders that target the nested `TextField`/`EditableText` should still work through the `find.descendant` resolution most `tester.enterText(find.byKey(...))` calls rely on; if any existing test finds the field via `find.byKey(...).evaluate().single` and expects the widget type to be `TextField` specifically rather than `AppSearchBar`, that assumption will break and needs updating). Run the file (Step 10) and fix any such assumption if it surfaces.

Add one new test proving the clear button now works on this real screen (not just the isolated `AppSearchBar` unit test from Step 2 — this closes the loop end-to-end):

```dart
  testWidgets('clear button on the search field restores the full unfiltered list', (tester) async {
    // ...set up the same fixture the existing "typing in the search field
    // filters the product list by name" test uses...
    await tester.enterText(find.byKey(const Key('mapping-search-field')), 'товар 1');
    await tester.pump();
    expect(find.text('Товар 2'), findsNothing);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('Товар 1'), findsOneWidget);
    expect(find.text('Товар 2'), findsOneWidget);
  });
```
(Match the exact fixture/mock setup the file's other search-related tests already use — there should be an existing "clearing the search restores the full list" test from the original search feature that tested this via `enterText(..., '')`; if so, this new test is a genuine addition testing the *button*-driven path specifically, not a duplicate — keep both.)

- [ ] **Step 10: Run the full test file**

Run: `cd app && flutter test test/presentation/pages/settings/ecommerce_product_mapping_page_test.dart`
Expected: all tests pass, including the new one.

- [ ] **Step 11: Run analyze on all touched files**

Run: `cd app && flutter analyze lib/presentation/widgets/common/app_search_bar.dart lib/presentation/pages/settings/ecommerce_product_mapping_page.dart lib/presentation/pages/stock/stock_intake_page.dart`
Expected: No issues found.

- [ ] **Step 12: Commit**

```bash
git add app/lib/presentation/widgets/common/app_search_bar.dart app/lib/presentation/pages/settings/ecommerce_product_mapping_page.dart app/test/presentation/widgets/common/app_search_bar_test.dart app/test/presentation/pages/settings/ecommerce_product_mapping_page_test.dart
git commit -m "feat(mobile): add a clear button to AppSearchBar, reuse it on the product-mapping search screen"
```

---

## Final check (after all 5 tasks land)

- [ ] `cd api && npx jest` — full backend suite passes
- [ ] `cd api && npx tsc --noEmit` — no errors
- [ ] `cd admin && npx tsc --noEmit` — no errors (none of these tasks touch `admin/`, this is a sanity check only)
- [ ] `cd app && flutter analyze` — no new issues
- [ ] `cd app && flutter test` — passes (pre-existing, environment-specific golden-test flakiness unrelated to any of these 5 tasks — confirmed via baseline comparison against `main` during the prior branch's review — is expected and not a regression to chase; if any *new* failures appear in files these 5 tasks actually touch, investigate those specifically)
- [ ] `git log --oneline` — confirm all 5 tasks' commits are present
