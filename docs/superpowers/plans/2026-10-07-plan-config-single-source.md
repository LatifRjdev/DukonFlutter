# Plan Config As Single Source — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `SubscriptionPlanConfig` the only place prices, limits and feature flags are stated, so the app stops hardcoding prices it does not charge and stops missing flags the server enforces.

**Architecture:** One server-side mapping turns a plan-config row into a `PlanView` carrying the price, three limits and **all eleven** flags; a single pricing helper applies the merchant's discount and is shared by `getSubscription`, the new `availablePlans`, and `requestChange`. The app grows `SubscriptionFeatures` to match, renders card numbers from `availablePlans`, and gates the three features the server already enforces. A test parses `schema.prisma` so the list cannot silently diverge again.

**Tech Stack:** NestJS + Prisma + Jest (API), Flutter 3.x / Dart 3.10 + flutter_bloc + bloc_test/mocktail (app), ARB localization via `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-10-07-plan-config-single-source-design.md`

**Worktree:** `/Users/latifrjdev/Downloads/01_Проекты/Dukon/.worktrees/plan-config-truth`, branch `fix/plan-config-single-source`, based on `fix/subscription-receipt-and-past-due` at `3ccdb39` — **not on `main`**. The two branches edit the same files; that one is reviewed and ready and must merge first or alongside.

---

## Environment notes

Run `flutter`/`dart` from `app/`, `npm`/`npx` from `api/`. Both inside the worktree above.

**The worktree has no `api/node_modules`.** This branch *does* change API code, so install first: `cd api && npm ci`. Until that finishes, every `npx tsc`/`npm test` will report a missing TypeScript rather than a real error.

Local stack: Postgres container `dukonpro-db` on `:5435` (`docker exec dukonpro-db psql -U dukonpro -d dukonpro`); API on `:4455` with global prefix `api`; emulator `emulator-5554`. **The API serves from compiled `dist/`**, so after an API change: `npm run build`, verify it succeeded, then restart — in that order.

QA logins: `+992920777001` / `x8R9s5msWiEzBYWL` (BUSINESS), `+992920777002` / `yfgYAi5oHqm38w8x` (PREMIUM).

**Rate limit:** 100 requests/60s **including logins**. Log in once, reuse the token.

### Traps that have cost real time here

- **The `Read` tool truncates files with prior observations to line 1.** Read via `awk '{print NR": "$0}' <path>`. Several agents have stalled on this.
- **Never run plain `dart format <path>`.** Dart 3.10 rewrites whole files. Write in the formatter's style, then check with `dart format --output=none --set-exit-if-changed <path>` and fix by hand. The pre-commit hook runs this and will reject the commit.
- **Never bypass git hooks.** A guard rejects the flag outright; do not put its name in any command.
- **Never regenerate goldens.** 18 fail on macOS as a documented baseline.
- **Never hand-edit `app/lib/l10n/app_localizations*.dart`** — generated. Only edit `app_ru.arb`; `app_tg.arb`/`app_uz.arb` are translated separately and new keys are expected in the `l10n_untranslated.json` backlog.
- **Raw SQL uses table names, not Prisma model names**: `stores`, `users`, `subscriptions`, `payments`, `subscription_plan_configs`. Columns are camelCase and must be quoted.
- **BSD sed**: no `\n` in replacements, no `\b`. Use `perl -pi -e` where a newline is needed.
- **zsh**: quote `--include=*.dart`; brace `"${VAR}"` before a colon.
- **`npm run lint` in `api/` is report-only** and the baseline is ~3572 problems. `npx tsc --noEmit` at 0 errors is the gate. **Green Jest does not imply clean types** — ts-jest has let a real TS2769 through. Run both.
- **Line numbers below are from `3ccdb39`** and are a locating aid. Match on the quoted content.

---

## File structure

| File | Responsibility | Change |
|---|---|---|
| `api/src/modules/subscriptions/plan-view.ts` | `PlanView` type, `toPlanView()`, and `discountedPrice()` — the one place a plan row becomes an API shape and the one place the discount is applied | **Create** |
| `api/src/modules/subscriptions/plan-view.spec.ts` | Parses `model SubscriptionPlanConfig` out of `schema.prisma`; fails if any `has*` column is missing from `PlanView` | **Create** |
| `api/test/plan-pricing.e2e-spec.ts` | Real-Postgres proof that the price shown equals the amount `request-change` writes | **Create** |
| `api/src/modules/subscriptions/subscriptions.service.ts` | `getSubscription` returns `availablePlans`; `features`/`limits`/`calculatedPrice` and `requestChange` all derive from `plan-view.ts` | Modify |
| `app/lib/presentation/blocs/subscription/subscription_state.dart` | `SubscriptionFeatures` → 11 fields, `hasFeature(String)` deleted, new `SubscriptionPlanOption` | Modify |
| `app/lib/presentation/blocs/subscription/subscription_bloc.dart` | Parse `availablePlans` | Modify |
| `app/lib/presentation/pages/settings/plan_gate.dart` | Shared gate: "is this feature available, and on which cheapest plan", plus the dialog | **Create** |
| `app/lib/presentation/pages/settings/subscription_page.dart` | Card numbers from state; store-count bullets gone | Modify |
| `app/lib/presentation/pages/settings/settings_page.dart` | Loyalty tile gated; e-commerce tile moved onto the shared gate | Modify |
| `app/lib/presentation/pages/dashboard/more_page.dart` | Закят tile gated | Modify |
| `app/lib/l10n/app_ru.arb` | Number-bearing keys become placeholder keys; store-count keys deleted; gate title parameterised | Modify |

`plan-view.ts` sits in the subscriptions module rather than `common/` because it is the subscriptions API's own response shape. `plan_gate.dart` sits beside `subscription_status.dart` and `payment_status.dart`, the two files the previous branch established as the home for subscription vocabulary.

---

## Task 1: `PlanView` and the schema guard

The defect's root: `getSubscription` lists seven flag keys by hand
([subscriptions.service.ts:198-216](api/src/modules/subscriptions/subscriptions.service.ts#L198-L216))
while the config has eleven. The Dart class's comment even says the list is hand-kept on both sides.

**Files:**
- Create: `api/src/modules/subscriptions/plan-view.ts`
- Create: `api/src/modules/subscriptions/plan-view.spec.ts`

- [ ] **Step 1: Install API dependencies in this worktree**

```bash
cd api && npm ci
```
Expected: completes without error. Until it does, every `npx`/`jest` command misreports.

- [ ] **Step 2: Write the failing test**

Create `api/src/modules/subscriptions/plan-view.spec.ts`:

```ts
import { readFileSync } from 'fs';
import { join } from 'path';
import { PLAN_FEATURE_FLAGS, discountedPrice, toPlanView } from './plan-view';

// Guards the defect this file was extracted for. getSubscription used to list
// seven flag keys by hand while SubscriptionPlanConfig had eleven, and the four
// it missed included three the server enforces with @RequiresFeature — so the
// app could not gate zakat, loyalty or batch profitability, and merchants met a
// 403 instead of an explanation.
describe('PlanView', () => {
  it('should carry every has* column the schema defines', () => {
    // Reads the schema rather than restating it. A hardcoded list is where
    // someone has to REMEMBER; this is where the build tells them. Same
    // technique as payment_status_test.dart and subscription_status_test.dart.
    const schema = readFileSync(
      join(__dirname, '../../../prisma/schema.prisma'),
      'utf8',
    );
    const block = /^model SubscriptionPlanConfig\s*\{([^}]*)\}/m.exec(schema);
    expect(block).not.toBeNull();

    const fromSchema = block![1]
      .split('\n')
      .map((l) => l.replace(/\/\/.*$/, '').trim())
      .filter((l) => l.startsWith('has'))
      .map((l) => l.split(/\s+/)[0]);

    expect(fromSchema.length).toBeGreaterThan(0);
    for (const flag of fromSchema) {
      expect(PLAN_FEATURE_FLAGS).toContain(flag);
    }
  });

  it('should apply a discount to the price', () => {
    expect(discountedPrice(200, 25)).toBe(150);
  });

  it('should round a discount that does not divide evenly', () => {
    // 33% of 200 is 134.00000000000003 in IEEE 754. getSubscription used to
    // round and requestChange did not; Decimal(12,2) hid the difference on
    // write. One helper, one rounding rule.
    expect(discountedPrice(200, 33)).toBe(134);
  });

  it('should treat a null or zero discount as full price', () => {
    expect(discountedPrice(200, 0)).toBe(200);
    expect(discountedPrice(200, null)).toBe(200);
  });

  it('should expose the discounted price and every flag on the view', () => {
    const config = {
      plan: 'BUSINESS',
      price: 400,
      maxProducts: 2000,
      maxStaff: 10,
      maxDiscounts: 5,
      hasReportsAll: true,
      hasExport: false,
      hasTelegram: true,
      hasAllPush: false,
      hasDelivery: true,
      hasInventory: true,
      hasZakat: true,
      hasInvestments: true,
      hasLoyalty: true,
      hasBatchProfitability: true,
      hasEcommerceIntegration: false,
    } as any;

    const view = toPlanView(config, 25);

    expect(view.plan).toBe('BUSINESS');
    expect(view.price).toBe(300);
    expect(view.listPrice).toBe(400);
    expect(view.maxProducts).toBe(2000);
    expect(view.features.hasZakat).toBe(true);
    expect(view.features.hasEcommerceIntegration).toBe(false);
    // Every flag the schema defines, not a subset.
    expect(Object.keys(view.features).sort()).toEqual(
      [...PLAN_FEATURE_FLAGS].sort(),
    );
  });
});
```

- [ ] **Step 3: Run it to verify it fails**

```bash
cd api && npx jest src/modules/subscriptions/plan-view.spec.ts
```
Expected: FAIL — `Cannot find module './plan-view'`. It must fail for a missing module, not an assertion.

- [ ] **Step 4: Create the module**

Create `api/src/modules/subscriptions/plan-view.ts`:

```ts
import { SubscriptionPlanConfig } from '@prisma/client';

/**
 * Every feature flag on SubscriptionPlanConfig, in one place.
 *
 * getSubscription used to type seven of these out by hand into its response
 * while the table had eleven. Three of the four it missed — hasZakat,
 * hasLoyalty, hasBatchProfitability — are enforced server-side with
 * @RequiresFeature on whole controllers, so the app could not gate them and a
 * merchant on a plan without them met a 403 reading "Недостаточно прав".
 *
 * plan-view.spec.ts parses `model SubscriptionPlanConfig` out of schema.prisma
 * and fails if any has* column is absent here, so the list cannot drift again.
 */
export const PLAN_FEATURE_FLAGS = [
  'hasReportsAll',
  'hasExport',
  'hasTelegram',
  'hasAllPush',
  'hasDelivery',
  'hasInventory',
  'hasZakat',
  'hasInvestments',
  'hasLoyalty',
  'hasBatchProfitability',
  'hasEcommerceIntegration',
] as const;

export type PlanFeatureFlag = (typeof PLAN_FEATURE_FLAGS)[number];

export type PlanFeatures = Record<PlanFeatureFlag, boolean>;

export interface PlanView {
  plan: string;
  /** What this merchant pays, discount applied. */
  price: number;
  /** Before the discount, so a card can show what is being saved. */
  listPrice: number;
  maxProducts: number;
  maxStaff: number;
  maxDiscounts: number;
  features: PlanFeatures;
}

/**
 * The merchant's price for a plan. The ONLY place the discount is applied.
 *
 * getSubscription rounded (`Math.round(p * 100) / 100`) and requestChange did
 * not, so 33% off 200 produced 134 from one and 134.00000000000003 from the
 * other. Decimal(12,2) reconciled them on write, which is why nobody noticed.
 * Both call this now.
 */
export function discountedPrice(
  listPrice: number,
  discountPercent: number | null | undefined,
): number {
  const discount = discountPercent ? Number(discountPercent) : 0;
  return Math.round(listPrice * (1 - discount / 100) * 100) / 100;
}

export function toPlanView(
  config: SubscriptionPlanConfig,
  discountPercent: number | null | undefined,
): PlanView {
  const listPrice = Number(config.price);
  const features = Object.fromEntries(
    PLAN_FEATURE_FLAGS.map((flag) => [flag, config[flag]]),
  ) as PlanFeatures;

  return {
    plan: config.plan,
    price: discountedPrice(listPrice, discountPercent),
    listPrice,
    maxProducts: config.maxProducts,
    maxStaff: config.maxStaff,
    maxDiscounts: config.maxDiscounts,
    features,
  };
}
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd api && npx jest src/modules/subscriptions/plan-view.spec.ts
npx tsc --noEmit ; echo "tsc exit=$?"
```
Expected: 5 passing; `tsc exit=0`.

- [ ] **Step 6: Prove the schema guard is not vacuous**

If the regex misses, `fromSchema` is empty and the loop asserts nothing. The spec already asserts `fromSchema.length > 0`, but prove the loop bites too:

```bash
cd api
cp src/modules/subscriptions/plan-view.ts /tmp/pv.keep
perl -pi -e "s/^  'hasLoyalty',\n//" src/modules/subscriptions/plan-view.ts
npx jest src/modules/subscriptions/plan-view.spec.ts 2>&1 | grep -c "hasLoyalty\|✕"
cp /tmp/pv.keep src/modules/subscriptions/plan-view.ts
rm -f /tmp/pv.keep
npx jest src/modules/subscriptions/plan-view.spec.ts
git status --short
```
Expected: a non-zero count on the broken run (the completeness test AND the flag-set assertion should both fail), then back to 5 passing and an empty `git status --short`.

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/.worktrees/plan-config-truth
git add api/src/modules/subscriptions/plan-view.ts \
        api/src/modules/subscriptions/plan-view.spec.ts
git commit --file - <<'MSG'
feat(api): one mapping from plan config to API shape, checked against the schema

getSubscription typed seven feature flags into its response by hand while
SubscriptionPlanConfig has eleven. Three of the four it missed — hasZakat,
hasLoyalty, hasBatchProfitability — are enforced with @RequiresFeature on whole
controllers, so the app could not gate them and merchants met a 403 that reads
as "Недостаточно прав".

PLAN_FEATURE_FLAGS is now the single list and a test parses
`model SubscriptionPlanConfig` out of schema.prisma to fail the build if a
column is missing from it. Third use of that technique here, after
payment_status and subscription_status.

discountedPrice is the one place the discount is applied. getSubscription
rounded and requestChange did not, so 33% off 200 gave 134 from one and
134.00000000000003 from the other; Decimal(12,2) reconciled them on write,
which is why it was invisible.

Nothing consumes this yet; the next commit wires it in.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
```

---

## Task 2: `availablePlans`, and one pricing path

`adminDiscount` applies to whichever plan the merchant picks — `requestChange` charges the *requested* plan's price minus the discount. The public `GET /subscription/plans` is unauthenticated and cannot know the merchant, so the authenticated subscription response carries the per-merchant prices.

**Files:**
- Modify: `api/src/modules/subscriptions/subscriptions.service.ts:166-262`
- Create: `api/test/plan-pricing.e2e-spec.ts`

- [ ] **Step 1: Write the failing e2e test**

Create `api/test/plan-pricing.e2e-spec.ts`:

```ts
import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { PrismaService } from '../src/prisma/prisma.service';
import { SubscriptionsService } from '../src/modules/subscriptions/subscriptions.service';
import { AppModule } from '../src/app.module';

// The number on a plan card and the number written to the Payment row must be
// the same number. They came from two different expressions — one rounded, one
// not — and Decimal(12,2) hid the difference on write.
//
// The discount here is 33, deliberately. At 50 the arithmetic is exact and the
// two expressions agree under ANY implementation, so the test would pass
// against the bug. Same trap as the one-hour margin that made an earlier
// trial-countdown test pass under both implementations.
describe('Plan pricing agreement (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let subs: SubscriptionsService;

  // Initialised to '' rather than undefined: Prisma drops an undefined filter
  // field, so deleteMany({ where: { id: undefined } }) empties the table.
  let storeId = '';
  let userId = '';
  let subscriptionId = '';

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);
    subs = app.get(SubscriptionsService);

    const user = await prisma.user.create({
      data: {
        phone: `+99290${Date.now().toString().slice(-7)}`,
        password: 'x',
        name: 'pricing e2e',
      },
    });
    userId = user.id;

    const store = await prisma.store.create({
      data: { name: 'pricing e2e store', ownerId: userId },
    });
    storeId = store.id;

    const sub = await prisma.subscription.create({
      data: {
        storeId,
        plan: 'START',
        status: 'ACTIVE',
        currentPeriodEnd: new Date(Date.now() + 30 * 86400000),
        adminDiscount: 33,
      },
    });
    subscriptionId = sub.id;
  });

  afterAll(async () => {
    await prisma.payment.deleteMany({ where: { subscriptionId } });
    await prisma.subscription.deleteMany({ where: { storeId } });
    await prisma.store.deleteMany({ where: { id: storeId } });
    await prisma.user.deleteMany({ where: { id: userId } });
    await app.close();
  });

  it('should charge exactly the price it advertises for every plan', async () => {
    const response: any = await subs.getSubscription(storeId);
    expect(response.availablePlans.length).toBeGreaterThan(0);

    for (const planView of response.availablePlans) {
      const payment = await subs.requestChange(storeId, {
        plan: planView.plan,
        paymentMethod: 'CASH',
      } as any);

      expect(Number(payment.amount)).toBe(planView.price);

      await prisma.payment.delete({ where: { id: payment.id } });
    }
  });

  it('should reduce the advertised price by the discount, not ignore it', async () => {
    // Without this, a bug that dropped the discount entirely would still pass
    // the agreement test above — both sides would simply be the list price.
    const response: any = await subs.getSubscription(storeId);
    for (const planView of response.availablePlans) {
      expect(planView.price).toBeLessThan(planView.listPrice);
    }
  });
});
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd api && npx jest --config test/jest-e2e.json plan-pricing
```
Expected: FAIL — `response.availablePlans` is undefined, so `.length` throws. It must fail for the missing field, not an arithmetic mismatch.

**If the suite cannot connect to Postgres**, start the container before continuing — these tests hit the real dev database, as `cogs.e2e-spec.ts` does.

- [ ] **Step 3: Rewrite the service's three pricing sites**

In `api/src/modules/subscriptions/subscriptions.service.ts`, add to the imports at the top of the file:

```ts
import { PLAN_FEATURE_FLAGS, discountedPrice, toPlanView } from './plan-view';
```

Replace lines 166-225 (`getPlans` through the end of `getSubscription`) with:

```ts
  async getPlans() {
    return this.prisma.subscriptionPlanConfig.findMany({
      orderBy: { price: 'asc' },
    });
  }

  async getSubscription(storeId: string) {
    const subscription = await this.prisma.subscription.findUnique({
      where: { storeId },
      include: { store: { select: { name: true } } },
    });

    if (!subscription) {
      throw new NotFoundException('Subscription not found for this store');
    }

    const configs = await this.prisma.subscriptionPlanConfig.findMany({
      orderBy: { price: 'asc' },
    });
    const planConfig =
      configs.find((c) => c.plan === subscription.plan) ?? null;

    const discount = subscription.adminDiscount;

    // Every plan, priced for THIS merchant. The app renders its cards from
    // this: it used to hardcode 49/149/299 in translation strings while the
    // config charged 200/400/600, so tapping a card reading 49 created a
    // payment for 200.
    const availablePlans = configs.map((c) => toPlanView(c, discount));

    const currentView = planConfig ? toPlanView(planConfig, discount) : null;

    // `features` and `limits` keep their names — the app reads them — but are
    // derived rather than typed out. `features` grows from seven keys to
    // eleven; adding keys cannot break a reader, and the four that were
    // missing are the whole defect.
    const features = currentView ? currentView.features : undefined;
    const limits = currentView
      ? {
          maxProducts: currentView.maxProducts,
          maxStaff: currentView.maxStaff,
          maxDiscounts: currentView.maxDiscounts,
        }
      : undefined;

    return {
      ...subscription,
      planConfig,
      features,
      limits,
      availablePlans,
      calculatedPrice: currentView ? currentView.price : 0,
    };
  }
```

Then in `requestChange`, replace the discount arithmetic (lines 244-248, `const discount =` through `const amount =`) with:

```ts
    // Same helper the card's price came from, so the merchant is charged the
    // number they were shown. These were two separate expressions with
    // different rounding.
    const amount = discountedPrice(
      Number(planConfig.price),
      subscription.adminDiscount,
    );
```

Leave `PLAN_FEATURE_FLAGS` imported even if unused here — Step 4 removes it if `tsc` objects.

- [ ] **Step 4: Run everything**

```bash
cd api
npx jest --config test/jest-e2e.json plan-pricing
npx jest src/modules/subscriptions
npx tsc --noEmit ; echo "tsc exit=$?"
```
Expected: the e2e pair passes; the existing subscriptions unit specs still pass; `tsc exit=0`. If `tsc` flags `PLAN_FEATURE_FLAGS` as unused, drop it from the import.

**If an existing spec fails**, read it before changing it: `subscriptions.service.spec.ts` may assert the old seven-key `features` shape. Growing it to eleven is intended — update the assertion to check the keys it cares about rather than an exact object, and say so in the commit. Do **not** shrink the response to satisfy a stale test.

- [ ] **Step 5: Prove the e2e test guards the real thing**

```bash
cd api
cp src/modules/subscriptions/subscriptions.service.ts /tmp/svc.keep
# make requestChange ignore the discount, as it would if the two paths diverged
perl -0pi -e 's/const amount = discountedPrice\(\s*Number\(planConfig\.price\),\s*subscription\.adminDiscount,\s*\);/const amount = Number(planConfig.price);/s' src/modules/subscriptions/subscriptions.service.ts
grep -c "const amount = Number(planConfig.price);" src/modules/subscriptions/subscriptions.service.ts
npx jest --config test/jest-e2e.json plan-pricing 2>&1 | grep -E "✕|✓" 
cp /tmp/svc.keep src/modules/subscriptions/subscriptions.service.ts
rm -f /tmp/svc.keep
git status --short
```
Expected: the agreement test FAILS while the discount test still passes, then a clean `git status --short`. If both still pass, the fixture's discount is not reaching `requestChange` and the test proves nothing.

- [ ] **Step 6: Rebuild and restart the API, then check the live shape**

```bash
cd api && npm run build && test -f dist/main.js && echo "artifact ok"
```
Restart the API, then — logging in **once**:

```bash
cd /private/tmp/claude-501/-Users-latifrjdev-Downloads-01---------Dukon/55ece40c-480e-4a15-add5-e8850af836f3/scratchpad
curl -s -X POST http://localhost:4455/api/auth/login -H 'Content-Type: application/json' \
  -d '{"phone":"+992920777001","password":"x8R9s5msWiEzBYWL"}' \
  | python3 -c "import json,sys;print(json.load(sys.stdin)['accessToken'])" > token.txt
T=$(cat token.txt)
curl -s "http://localhost:4455/api/stores/ccb89fc3-95e9-47d0-9437-8c1079cbc4c2/subscription" \
  -H "Authorization: Bearer $T" \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('availablePlans:', [(p['plan'], p['price'], p['listPrice']) for p in d['availablePlans']])
print('features keys:', len(d['features']))
"
```
Expected: three plans with their real prices, and **11** feature keys.

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/.worktrees/plan-config-truth
git add api/src/modules/subscriptions/subscriptions.service.ts api/test/plan-pricing.e2e-spec.ts
git commit --file - <<'MSG'
feat(api): ship every plan, priced for this merchant, from one pricing helper

getSubscription now returns availablePlans — a PlanView per plan with the price
already reduced by this merchant's adminDiscount — and derives features and
limits from the same mapping instead of typing seven flag keys out by hand.
features grows to eleven.

requestChange uses the same discountedPrice helper, so the amount written to
the Payment row is the number the card showed. It was computed by a separate
expression with different rounding.

The e2e test requests every plan and compares the stored amount against the
advertised price, with a 33% discount: at 50 the arithmetic is exact and the
two expressions agree under any implementation, so the test would pass against
the bug. A second assertion pins that the discount is applied at all —
otherwise dropping it entirely would leave both sides equal and still green.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
```

---

## Task 3: The app receives all eleven flags

**Files:**
- Modify: `app/lib/presentation/blocs/subscription/subscription_state.dart:40-115`
- Modify: `app/lib/presentation/blocs/subscription/subscription_bloc.dart`
- Modify: `app/test/presentation/blocs/subscription/subscription_bloc_test.dart`

- [ ] **Step 1: Write the failing tests**

In `app/test/presentation/blocs/subscription/subscription_bloc_test.dart`, add inside the `SubscriptionLoadRequested` group, after the `-1 = unlimited` test:

```dart
      blocTest<SubscriptionBloc, SubscriptionState>(
        'should read the four flags the response gained, not just the original seven',
        setUp: () => mockGet(<String, dynamic>{
          'plan': 'BUSINESS',
          'status': 'ACTIVE',
          'features': {
            'hasReportsAll': true,
            'hasExport': false,
            'hasTelegram': true,
            'hasAllPush': false,
            'hasDelivery': true,
            'hasInventory': true,
            'hasZakat': true,
            'hasInvestments': true,
            'hasLoyalty': true,
            'hasBatchProfitability': true,
            'hasEcommerceIntegration': false,
          },
        }),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          // The four that used to be dropped on the floor. Three of them are
          // enforced server-side, so the app could not gate what the server
          // would refuse.
          isA<SubscriptionLoaded>()
              .having((s) => s.features.hasZakat, 'hasZakat', true)
              .having((s) => s.features.hasLoyalty, 'hasLoyalty', true)
              .having(
                (s) => s.features.hasBatchProfitability,
                'hasBatchProfitability',
                true,
              )
              .having((s) => s.features.hasInvestments, 'hasInvestments', true),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should deny a flag the response omits rather than assuming it',
        setUp: () => mockGet(<String, dynamic>{
          'plan': 'START',
          'status': 'ACTIVE',
          'features': {'hasReportsAll': true},
        }),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>()
              .having((s) => s.features.hasZakat, 'hasZakat', false)
              .having((s) => s.features.hasLoyalty, 'hasLoyalty', false),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should read every plan and its price from availablePlans',
        setUp: () => mockGet(<String, dynamic>{
          'plan': 'START',
          'status': 'ACTIVE',
          'availablePlans': [
            {
              'plan': 'START',
              'price': 134.0,
              'listPrice': 200.0,
              'maxProducts': 500,
              'maxStaff': 2,
              'maxDiscounts': 0,
              'features': {'hasZakat': false, 'hasLoyalty': false},
            },
            {
              'plan': 'BUSINESS',
              'price': 268.0,
              'listPrice': 400.0,
              'maxProducts': 2000,
              'maxStaff': 10,
              'maxDiscounts': 5,
              'features': {'hasZakat': true, 'hasLoyalty': true},
            },
          ],
        }),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>()
              .having((s) => s.availablePlans.length, 'plans', 2)
              .having((s) => s.availablePlans.first.plan, 'first.plan', 'START')
              // The discounted price, not the list price: this is the number
              // that will be charged, and the whole point of the change.
              .having((s) => s.availablePlans.first.price, 'first.price', 134.0)
              .having(
                (s) => s.availablePlans.first.listPrice,
                'first.listPrice',
                200.0,
              )
              .having(
                (s) => s.availablePlans[1].maxProducts,
                'business.maxProducts',
                2000,
              ),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should leave availablePlans empty when the response omits it',
        setUp: () => mockGet(<String, dynamic>{'plan': 'START'}),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          // Empty, not invented. The card list renders an error state rather
          // than a price nobody promised.
          isA<SubscriptionLoaded>()
              .having((s) => s.availablePlans, 'availablePlans', isEmpty),
        ],
      );
```

- [ ] **Step 2: Run them to verify they fail**

```bash
cd app && flutter test test/presentation/blocs/subscription/subscription_bloc_test.dart
```
Expected: compile failure — `hasZakat` and `availablePlans` are not defined on the state. A compile error is the correct failure here; there is nothing to assert against yet.

- [ ] **Step 3: Grow the model**

In `app/lib/presentation/blocs/subscription/subscription_state.dart`, replace lines 40-115 (the whole `SubscriptionFeatures` class and its leading comment) with:

```dart
// Mirrors `PLAN_FEATURE_FLAGS` in
// api/src/modules/subscriptions/plan-view.ts, which is itself checked against
// `model SubscriptionPlanConfig` in schema.prisma by plan-view.spec.ts. This
// list used to be hand-kept on both sides — the old comment here said so — and
// four flags were added to one side only. Three of those four are enforced with
// @RequiresFeature on whole controllers, so the app could not gate zakat,
// loyalty or batch profitability and merchants met a 403 instead.
class SubscriptionFeatures extends Equatable {
  final bool hasReportsAll;
  final bool hasExport;
  final bool hasTelegram;
  final bool hasAllPush;
  final bool hasDelivery;
  final bool hasInventory;
  final bool hasZakat;
  final bool hasInvestments;
  final bool hasLoyalty;
  final bool hasBatchProfitability;
  final bool hasEcommerceIntegration;

  const SubscriptionFeatures({
    required this.hasReportsAll,
    required this.hasExport,
    required this.hasTelegram,
    required this.hasAllPush,
    required this.hasDelivery,
    required this.hasInventory,
    required this.hasZakat,
    required this.hasInvestments,
    required this.hasLoyalty,
    required this.hasBatchProfitability,
    required this.hasEcommerceIntegration,
  });

  factory SubscriptionFeatures.fromJson(Map<String, dynamic> json) =>
      SubscriptionFeatures(
        hasReportsAll: json['hasReportsAll'] as bool? ?? false,
        hasExport: json['hasExport'] as bool? ?? false,
        hasTelegram: json['hasTelegram'] as bool? ?? false,
        hasAllPush: json['hasAllPush'] as bool? ?? false,
        hasDelivery: json['hasDelivery'] as bool? ?? false,
        hasInventory: json['hasInventory'] as bool? ?? false,
        hasZakat: json['hasZakat'] as bool? ?? false,
        hasInvestments: json['hasInvestments'] as bool? ?? false,
        hasLoyalty: json['hasLoyalty'] as bool? ?? false,
        hasBatchProfitability:
            json['hasBatchProfitability'] as bool? ?? false,
        hasEcommerceIntegration:
            json['hasEcommerceIntegration'] as bool? ?? false,
      );

  // `?? false` throughout, and defaults are all false: an absent flag denies.
  // The deleted `hasFeature(String)` did the opposite — `default: return true`
  // — against a server helper documented as fail-closed precisely so a
  // misconfigured plan cannot silently unlock a paid feature.
  factory SubscriptionFeatures.defaults() => const SubscriptionFeatures(
    hasReportsAll: false,
    hasExport: false,
    hasTelegram: false,
    hasAllPush: false,
    hasDelivery: false,
    hasInventory: false,
    hasZakat: false,
    hasInvestments: false,
    hasLoyalty: false,
    hasBatchProfitability: false,
    hasEcommerceIntegration: false,
  );

  @override
  List<Object?> get props => [
    hasReportsAll,
    hasExport,
    hasTelegram,
    hasAllPush,
    hasDelivery,
    hasInventory,
    hasZakat,
    hasInvestments,
    hasLoyalty,
    hasBatchProfitability,
    hasEcommerceIntegration,
  ];
}

/// One plan as offered to THIS merchant: [price] already has their
/// `adminDiscount` applied, server-side, by the same helper `request-change`
/// uses to compute what they will be charged.
class SubscriptionPlanOption extends Equatable {
  final String plan;
  final double price;
  final double listPrice;
  final int maxProducts;
  final int maxStaff;
  final int maxDiscounts;
  final SubscriptionFeatures features;

  const SubscriptionPlanOption({
    required this.plan,
    required this.price,
    required this.listPrice,
    required this.maxProducts,
    required this.maxStaff,
    required this.maxDiscounts,
    required this.features,
  });

  bool get isDiscounted => price < listPrice;

  factory SubscriptionPlanOption.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlanOption(
        plan: json['plan'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        listPrice: (json['listPrice'] as num?)?.toDouble() ?? 0,
        maxProducts: (json['maxProducts'] as num?)?.toInt() ?? 0,
        maxStaff: (json['maxStaff'] as num?)?.toInt() ?? 0,
        maxDiscounts: (json['maxDiscounts'] as num?)?.toInt() ?? 0,
        features: SubscriptionFeatures.fromJson(
          (json['features'] as Map<String, dynamic>?) ?? const {},
        ),
      );

  @override
  List<Object?> get props => [
    plan,
    price,
    listPrice,
    maxProducts,
    maxStaff,
    maxDiscounts,
    features,
  ];
}
```

Note what is gone: `hasFeature(String)`. It had **zero callers** — both real gates read typed fields — and its `default: return true` would have answered `true` for exactly the flags the server denies.

- [ ] **Step 4: Add the field to `SubscriptionLoaded`**

Still in `subscription_state.dart`, in `SubscriptionLoaded`: add the field beside `payments`, a `required this.availablePlans` entry in the constructor (or `this.availablePlans = const []` if you prefer it optional — **required** is better here, it forces every construction site to say what it means), and `availablePlans` in `props`.

Every construction site must be updated. Find them:

```bash
cd app && grep -rn "SubscriptionLoaded(" lib test | grep -v "is SubscriptionLoaded\|isA<SubscriptionLoaded>"
```

- [ ] **Step 5: Parse it in the bloc**

In `app/lib/presentation/blocs/subscription/subscription_bloc.dart`, inside `_mapLoaded`, add:

```dart
      availablePlans:
          (data['availablePlans'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(SubscriptionPlanOption.fromJson)
              .toList(),
```

`whereType` rather than a cast: a malformed entry is skipped instead of taking the whole screen down, which is how the payments list already behaves.

- [ ] **Step 6: Run the tests**

```bash
cd app
flutter test test/presentation/blocs/subscription/subscription_bloc_test.dart
flutter analyze
dart format --output=none --set-exit-if-changed \
  lib/presentation/blocs/subscription/subscription_state.dart \
  lib/presentation/blocs/subscription/subscription_bloc.dart \
  test/presentation/blocs/subscription/subscription_bloc_test.dart
```
Expected: all pass; `No issues found!`; formatter clean.

- [ ] **Step 7: Confirm the deletion was safe**

```bash
cd app && grep -rn "hasFeature" lib test || echo "no references remain"
```
Expected: no references. If any appear, they are new callers written since this plan — convert them to the typed field rather than restoring the method.

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/.worktrees/plan-config-truth
git add app/lib/presentation/blocs/subscription/subscription_state.dart \
        app/lib/presentation/blocs/subscription/subscription_bloc.dart \
        app/test/presentation/blocs/subscription/subscription_bloc_test.dart
git commit --file - <<'MSG'
fix(app): receive all eleven plan flags, and every plan's real price

SubscriptionFeatures carried seven of the config's eleven flags, and the
comment above it admitted the list was kept in sync by hand. Three of the four
missing ones — hasZakat, hasLoyalty, hasBatchProfitability — are enforced with
@RequiresFeature on whole controllers, so the app showed menu items it could
not open and the merchant met a 403 reading "Недостаточно прав".

hasFeature(String) is deleted rather than repaired. It had zero callers — both
real gates read typed fields — and its `default: return true` answered yes for
precisely the flags the server denies, against a server helper documented as
fail-closed. Every flag is now a typed field, so an unknown one is a compile
error instead.

availablePlans carries each plan priced for this merchant, discount already
applied server-side. It is empty rather than invented when the response omits
it: the card list will show an error instead of a price nobody promised.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
```

---

## Task 4: Cards show the numbers that will be charged

The cards are built entirely from ARB strings
([subscription_page.dart:39-80](app/lib/presentation/pages/settings/subscription_page.dart#L39-L80)).
Three of those keys even carry the number in the key *name* — `subscriptionFeatureProducts500` — so they cannot be reused across plans.

**Files:**
- Modify: `app/lib/l10n/app_ru.arb`
- Modify: `app/lib/presentation/pages/settings/subscription_page.dart:18-80`
- Modify: `app/test/presentation/pages/settings/subscription_page_golden_test.dart` and `settings_page_golden_test.dart` (constructor arg)
- Create: `app/test/presentation/pages/settings/subscription_page_pricing_test.dart`

- [ ] **Step 1: Rework the ARB keys**

In `app/lib/l10n/app_ru.arb`:

**Delete** these six keys and their `@` descriptions if present — three advertise a limit the server dropped in 2026-05 and does not enforce, three hardcode prices:

```
subscriptionFeatureStores1
subscriptionFeatureStores3
subscriptionFeatureStores5
subscriptionPriceStart
subscriptionPriceBusiness
subscriptionPricePremium
```

**Replace** the three number-bearing feature keys with placeholder keys, inside the same contiguous `subscription*` block:

```json
  "subscriptionPriceLine": "{amount} TJS/мес",
  "@subscriptionPriceLine": { "description": "Plan card price. The amount is pre-formatted at the call site and comes from availablePlans, with this merchant's adminDiscount already applied server-side — it is the number request-change will charge. Replaced subscriptionPriceStart/Business/Premium, which hardcoded 49/149/299 while the config charged 200/400/600.", "placeholders": { "amount": { "type": "String" } } },
  "subscriptionFeatureProductsLine": "{count} товаров",
  "@subscriptionFeatureProductsLine": { "description": "Plan card bullet — product limit, from the plan config. Replaced subscriptionFeatureProducts500, whose key name pinned it to one plan.", "placeholders": { "count": { "type": "String" } } },
  "subscriptionFeatureStaffLine": "{count} сотрудников",
  "@subscriptionFeatureStaffLine": { "description": "Plan card bullet — staff limit, from the plan config. Count-agnostic wording: the project uses String placeholders with no ICU plural, so one form has to be correct for 2 and 10 alike.", "placeholders": { "count": { "type": "String" } } },
  "subscriptionFeatureDiscountsLine": "{count} скидок",
  "@subscriptionFeatureDiscountsLine": { "description": "Plan card bullet — discount limit, from the plan config. Count-agnostic for the same reason as subscriptionFeatureStaffLine.", "placeholders": { "count": { "type": "String" } } },
  "subscriptionFeatureUnlimited": "Без ограничений",
  "@subscriptionFeatureUnlimited": { "description": "Plan card bullet replacing a numeric limit when the config stores -1, the PREMIUM convention for unlimited." },
```

Keep `subscriptionFeatureProducts500`, `subscriptionFeatureEmployees2` and `subscriptionFeatureDiscounts5` **deleted** once nothing references them.

Validate:
```bash
cd app && python3 -m json.tool lib/l10n/app_ru.arb > /dev/null && echo "valid JSON"
flutter gen-l10n
```

- [ ] **Step 2: Write the failing test**

Create `app/test/presentation/pages/settings/subscription_page_pricing_test.dart`. **Copy the harness from `subscription_page_status_test.dart`** — the mocked bloc, `pumpWithStatus`'s surface size, its two-frame pump, and crucially its `await tester.pumpWidget(const SizedBox.shrink())` teardown between pumps, whose comment explains why a MockBloc otherwise keeps rendering the previous state. Adapt it to take plans instead of a status:

```dart
// The card's numbers must come from the state, not from constants. They WERE
// constants: the cards read 49/149/299 TJS from translation strings while
// subscription_plan_configs charged 200/400/600, so tapping a card reading
// "49 TJS/мес" created a payment for 200.
//
// Every number in the fixture matches NONE of the old hardcoded values, so a
// surviving constant fails rather than coincidentally agreeing. 500/2/5 would
// have passed against the bug.

SubscriptionLoaded _loadedWithPlans(List<SubscriptionPlanOption> plans) =>
    SubscriptionLoaded(
      plan: 'START',
      status: 'ACTIVE',
      limits: const SubscriptionLimits(
        maxProducts: 777,
        maxStaff: 3,
        maxDiscounts: 9,
      ),
      features: SubscriptionFeatures.defaults(),
      payments: const [],
      availablePlans: plans,
    );

const _start = SubscriptionPlanOption(
  plan: 'START',
  price: 134,
  listPrice: 200,
  maxProducts: 777,
  maxStaff: 3,
  maxDiscounts: 9,
  features: SubscriptionFeatures(
    hasReportsAll: false,
    hasExport: false,
    hasTelegram: false,
    hasAllPush: false,
    hasDelivery: false,
    hasInventory: false,
    hasZakat: false,
    hasInvestments: false,
    hasLoyalty: false,
    hasBatchProfitability: false,
    hasEcommerceIntegration: false,
  ),
);

void main() {
  // ... harness copied from subscription_page_status_test.dart ...

  testWidgets('should price the card from the server, not from a constant', (
    tester,
  ) async {
    await pumpWithPlans(tester, const [_start]);

    expect(find.text('134 TJS/мес'), findsOneWidget);
    // The constant it replaced. Four times lower than what was charged.
    expect(find.text('49 TJS/мес'), findsNothing);
  });

  testWidgets('should take every limit on the card from the server', (
    tester,
  ) async {
    await pumpWithPlans(tester, const [_start]);

    expect(find.text('777 товаров'), findsOneWidget);
    expect(find.text('3 сотрудников'), findsOneWidget);
    expect(find.text('9 скидок'), findsOneWidget);
    // The old constants, none of which the fixture uses.
    expect(find.text('500 товаров'), findsNothing);
    expect(find.text('2 сотрудника'), findsNothing);
    expect(find.text('5 скидок'), findsNothing);
  });

  testWidgets('should not advertise a store limit the server dropped in May', (
    tester,
  ) async {
    await pumpWithPlans(tester, const [_start]);

    // maxStores was removed from SubscriptionPlanConfig in 2026-05 and is
    // enforced nowhere; the previous branch deleted the client's dead field
    // and the advertisement of it survived in the marketing copy.
    expect(find.textContaining('магазин'), findsNothing);
  });

  testWidgets('should render -1 as unlimited rather than as minus one', (
    tester,
  ) async {
    await pumpWithPlans(tester, const [
      SubscriptionPlanOption(
        plan: 'PREMIUM',
        price: 402,
        listPrice: 600,
        maxProducts: -1,
        maxStaff: -1,
        maxDiscounts: -1,
        features: _start.features,
      ),
    ]);

    expect(find.text('Без ограничений'), findsWidgets);
    expect(find.textContaining('-1'), findsNothing);
  });

  testWidgets('should show no price at all when the plans did not load', (
    tester,
  ) async {
    await pumpWithPlans(tester, const []);

    // Showing an unverified price is the defect being fixed, so an empty list
    // must produce no number — not a hardcoded fallback.
    expect(find.textContaining('TJS/мес'), findsNothing);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

```bash
cd app && flutter test test/presentation/pages/settings/subscription_page_pricing_test.dart
```
Expected: FAIL — the page renders `49 TJS/мес` and `500 товаров` from constants.

- [ ] **Step 4: Rewrite the card builder**

In `subscription_page.dart`, replace `_PlanInfo` and `_buildPlans` (lines 18-80) so that a card is built from a `SubscriptionPlanOption` plus ARB wording:

- price → `l10n.subscriptionPriceLine(option.price.toStringAsFixed(0))`
- products → `option.maxProducts == -1 ? l10n.subscriptionFeatureUnlimited : l10n.subscriptionFeatureProductsLine('${option.maxProducts}')`, same shape for staff and discounts
- the remaining bullets (`subscriptionFeatureSalesReport`, `subscriptionFeatureCurrencies`, `settingsTileTelegramBot`, `deliveryListTitle`, `inventoryTitle`, `subscriptionFeatureAllReports`, `subscriptionFeatureExportPdfExcel`, `subscriptionFeaturePrioritySupport`) stay as authored copy, selected per plan as they are today
- plan labels `'Старт'`/`'Бизнес'`/`'Премиум'` stay literal — they are brand names and are on `tool/i18n-allowlist.txt`
- **no store-count bullet**

When `state.availablePlans` is empty, render the section's error state with a retry that dispatches `SubscriptionLoadRequested` — not a hardcoded card.

- [ ] **Step 5: Run everything**

```bash
cd app
flutter test test/presentation/pages/settings/subscription_page_pricing_test.dart
flutter test test/presentation/pages/settings/
flutter analyze
dart run tool/check_i18n.dart ; echo "i18n exit=$?"
```
Expected: pricing test passes; the status test from the previous branch still passes; analyze clean; i18n exit 0. The two golden tests will fail — they are in the documented 18 only if they already were; if `subscription_page_golden_test` newly fails, the card layout changed and **the golden must not be regenerated**: report it and leave it, since the card content genuinely changed and a human should look.

- [ ] **Step 6: Commit** — message must state that the cards previously advertised prices four times lower than charged, and that the fixture numbers deliberately match none of the old constants.

---

## Task 5: Gate what the server already enforces

`@RequiresFeature` protects zakat, loyalty and batch profitability. The app shows all three unconditionally.

**Files:**
- Create: `app/lib/presentation/pages/settings/plan_gate.dart`
- Modify: `app/lib/presentation/pages/settings/settings_page.dart:206-228,330-390`
- Modify: `app/lib/presentation/pages/dashboard/more_page.dart:62`
- Modify: `app/lib/l10n/app_ru.arb`
- Create: `app/test/presentation/pages/settings/plan_gate_test.dart`

- [ ] **Step 1: The dialog must stop saying PREMIUM**

`settingsPremiumGateTitle` is `"Доступно на тарифе PREMIUM"`, and the tile badge is the literal `'PREMIUM'`. Measured against the seeded config:

| flag | cheapest plan that has it |
|---|---|
| `hasZakat`, `hasLoyalty`, `hasBatchProfitability`, `hasInvestments` | **BUSINESS** |
| `hasEcommerceIntegration` | PREMIUM |

So reusing the dialog as-is would tell a START merchant they need PREMIUM for zakat when BUSINESS suffices — an upsell that over-sells, and a false statement on screen. Because the app now knows which plans carry which flags, it can name the cheapest one that does.

In `app_ru.arb`, replace `subscriptionPremiumGateTitle`'s hardcoded plan:

```json
  "settingsPlanGateTitle": "Доступно на тарифе {plan}",
  "@settingsPlanGateTitle": { "description": "Dialog title when a merchant opens a feature their plan does not include. The plan name is the CHEAPEST plan whose config carries the flag, taken from availablePlans — not a constant. Replaced settingsPremiumGateTitle, which said PREMIUM for every feature, including zakat and loyalty, which BUSINESS already includes.", "placeholders": { "plan": { "type": "String" } } },
```

Keep `settingsPremiumGateBody`/`Later`/`Upgrade` as they are; retarget `Title` only. Delete `settingsPremiumGateTitle` once nothing references it.

- [ ] **Step 2: Write the failing test**

Create `app/test/presentation/pages/settings/plan_gate_test.dart` covering the pure part — given a list of `SubscriptionPlanOption` and a flag selector, which is the cheapest plan that has it:

- with START(false)/BUSINESS(true)/PREMIUM(true) and the zakat selector → `'BUSINESS'`
- with only PREMIUM(true) → `'PREMIUM'`
- with none true → `null`, and the caller must not show a gate promising a plan that does not exist
- ordering must come from `price`, not list order — pass the list reversed and expect the same answer

- [ ] **Step 3: Run it to verify it fails**

```bash
cd app && flutter test test/presentation/pages/settings/plan_gate_test.dart
```
Expected: compile failure — no such file.

- [ ] **Step 4: Write `plan_gate.dart`**

Create `app/lib/presentation/pages/settings/plan_gate.dart`:

```dart
import '../../blocs/subscription/subscription_state.dart';

/// Which flag a gated entry point needs.
typedef PlanFeatureSelector = bool Function(SubscriptionFeatures features);

/// The cheapest plan whose config carries [needs], or null if no plan does.
///
/// The dialog used to say "Доступно на тарифе PREMIUM" for everything. Zakat,
/// loyalty and batch profitability are on BUSINESS, so a START merchant was
/// told to buy PREMIUM for something the next tier up already includes. The app
/// can tell the truth now only because availablePlans carries each plan's
/// flags.
///
/// Ordered by price rather than by list order: the server sorts, but a caller
/// that filters or reverses the list must not change the answer.
String? cheapestPlanWith(
  List<SubscriptionPlanOption> plans,
  PlanFeatureSelector needs,
) {
  final eligible = plans.where((p) => needs(p.features)).toList()
    ..sort((a, b) => a.listPrice.compareTo(b.listPrice));
  return eligible.isEmpty ? null : eligible.first.plan;
}

/// What a gated tile should do right now.
enum PlanGateVerdict {
  /// Subscription state has not arrived. Do NOT render a lock yet — the tile
  /// would flash one on every cold start. Disable the tap instead.
  undetermined,

  /// The plan includes it: behave normally.
  allowed,

  /// Confirmed excluded: badge it and open the dialog on tap.
  blocked,
}

class PlanGate {
  final PlanGateVerdict verdict;

  /// The plan to name in the badge and the dialog. Null when [verdict] is not
  /// [PlanGateVerdict.blocked], or when no plan offers the feature at all —
  /// in which case there is nothing honest to upsell and the caller should
  /// hide the entry point rather than promise a tier that does not exist.
  final String? requiredPlan;

  const PlanGate._(this.verdict, this.requiredPlan);

  /// Mirrors the branch already used for the e-commerce tile, which correctly
  /// separates "still loading" from "confirmed ineligible".
  factory PlanGate.of(SubscriptionState state, PlanFeatureSelector needs) {
    if (state is! SubscriptionLoaded) {
      return const PlanGate._(PlanGateVerdict.undetermined, null);
    }
    if (needs(state.features)) {
      return const PlanGate._(PlanGateVerdict.allowed, null);
    }
    return PlanGate._(
      PlanGateVerdict.blocked,
      cheapestPlanWith(state.availablePlans, needs),
    );
  }

  bool get isAllowed => verdict == PlanGateVerdict.allowed;
  bool get isUndetermined => verdict == PlanGateVerdict.undetermined;

  /// Blocked AND there is a real plan to point at. A blocked gate with no
  /// nameable plan must not render "Доступно на тарифе null".
  bool get isUpsellable =>
      verdict == PlanGateVerdict.blocked && requiredPlan != null;
}
```

Plan labels shown to the merchant stay the Russian brand names used on the cards. Map `'START'`/`'BUSINESS'`/`'PREMIUM'` to `'Старт'`/`'Бизнес'`/`'Премиум'` with the page's existing `_planLabel`-style switch rather than printing the raw enum — the previous branch removed exactly that defect from the status badge and it must not reappear here.

- [ ] **Step 4: Apply it to three entry points**

- `settings_page.dart:338` — loyalty tile, gate on `hasLoyalty`
- `settings_page.dart:367-386` — e-commerce tile, move onto the shared helper, gate on `hasEcommerceIntegration` (behaviour unchanged, now with the right plan name)
- `more_page.dart:62` — Закят tile, gate on `hasZakat`
- batch profitability: find its entry point in the product detail page and gate on `hasBatchProfitability`

- [ ] **Step 5: Run the gates** — `flutter test test/presentation/pages/`, `flutter analyze`, `dart run tool/check_i18n.dart`.

- [ ] **Step 6: Commit** — the message must record that zakat and loyalty are BUSINESS features, not PREMIUM, and that the old dialog would have over-sold.

---

## Task 6: Device verification and full gates

A passing unit test is not evidence that the merchant sees the right price. The previous branch's whole lesson is that tests written from the implementation cannot catch a disagreement with the server.

- [ ] **Step 1: Give the QA merchant a discount**

The agreement only shows up when a discount exists — at zero, a client that ignored the discount entirely would still match.

```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "UPDATE subscriptions SET \"adminDiscount\"=33 WHERE \"storeId\"='ccb89fc3-95e9-47d0-9437-8c1079cbc4c2';"
```
**Note the previous value first** (it is currently NULL) and restore it at the end.

- [ ] **Step 2: Build, install, and read the cards**

```bash
cd app && flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
```
Open Настройки → Подписка. Confirm each card's price is the **discounted** one — with 33% off, 134 / 268 / 402 — and that no card mentions a number of stores.

**Tapping through the menus is fiddly**: the list resets between commands, so issue the scroll and the tap in ONE bash command and screenshot after, never between.

- [ ] **Step 3: Prove the number on screen is the number charged**

Pick a plan, pay by card, attach a receipt, then:

```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "SELECT p.amount, p.note FROM payments p JOIN subscriptions s ON s.id=p.\"subscriptionId\"
    WHERE s.\"storeId\"='ccb89fc3-95e9-47d0-9437-8c1079cbc4c2' ORDER BY p.\"createdAt\" DESC LIMIT 1;"
```
Expected: `amount` equals the price the card showed. This is the whole point of the branch.

- [ ] **Step 4: Prove the gates**

The BUSINESS QA store has zakat and loyalty. Downgrade it to START, reload, and confirm both tiles now open the dialog naming **БИЗНЕС** (not PREMIUM), and that the e-commerce tile still names PREMIUM:

```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "UPDATE subscriptions SET plan='START' WHERE \"storeId\"='ccb89fc3-95e9-47d0-9437-8c1079cbc4c2';"
```

- [ ] **Step 5: Restore the database exactly**

```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "UPDATE subscriptions SET plan='BUSINESS', \"adminDiscount\"=NULL WHERE \"storeId\"='ccb89fc3-95e9-47d0-9437-8c1079cbc4c2';"
```
Delete any payments created during the walkthrough and their receipt files under `api/uploads/receipts/`. Re-query and confirm the store matches how it started: `BUSINESS` / `ACTIVE` / one APPROVED CASH payment of 400.00. This is the shared dev database.

- [ ] **Step 6: Full gate set**

```bash
cd app
flutter analyze
dart run tool/check_i18n.dart ; echo "i18n exit=$?"
flutter test 2>&1 | tr '\r' '\n' | grep -oE "^[0-9:]+ \+[0-9]+ -[0-9]+: [^[]*\[E\]" \
  | sed 's/^[0-9:]* +[0-9]* -[0-9]*: //;s/ \[E\]$//;s|.*/app/test/|test/|' | sort -u
cd ../api && npm test && npx tsc --noEmit ; echo "tsc exit=$?"
```

Compare the Flutter failing set **as a set of names**, not as a count. The documented baseline is 18 golden tests. **19-vs-18 is exactly the near-miss a count check waves through** — that is how a missing `AppMessage` row slipped past three reviewers on the previous branch. Any non-golden failure is a must-fix.

- [ ] **Step 7: Commit anything the gates changed** (`l10n_untranslated.json` will have grown) and then proceed to superpowers:finishing-a-development-branch.
