# The plan config is the source of truth, and the app should read it

**Date:** 2026-10-07
**Branch:** `fix/plan-config-single-source`, based on `fix/subscription-receipt-and-past-due` (not `main` — the two branches edit the same files, and that branch is reviewed and ready)
**Scope:** one root cause with four symptoms. Payment integrity (duplicate approvals, the plan-in-a-note) is deliberately **out** of scope and gets its own spec.

---

## The root cause

`SubscriptionPlanConfig` holds, per plan: a price, three limits, and **eleven** feature flags. An admin can edit every one of them through the admin panel.

The Flutter app receives a hand-assembled subset of that row and hardcodes the rest. `getSubscription`
([subscriptions.service.ts:198-216](api/src/modules/subscriptions/subscriptions.service.ts#L198-L216))
builds a seven-key `features` object and a three-key `limits` object by listing the keys out by hand, and the comment on the matching Dart class says so plainly:

> Keep in sync with `SubscriptionsService.getSubscription()`'s `features` object — the backend hand-maintains this same 7-key list, so a new flag added to one side needs the other updated too.

Four flags were added to one side and not the other.

## The four symptoms

### 1. Three enforced gates the app cannot see

`hasZakat`, `hasLoyalty` and `hasBatchProfitability` are enforced server-side:

| flag | enforcement |
|---|---|
| `hasZakat` | `@RequiresFeature('hasZakat')` on the whole [zakat.controller.ts:26](api/src/modules/zakat/zakat.controller.ts#L26) |
| `hasLoyalty` | `@RequiresFeature('hasLoyalty')` on the whole [loyalty.controller.ts:14](api/src/modules/loyalty/loyalty.controller.ts#L14) |
| `hasBatchProfitability` | [products.controller.ts:148](api/src/modules/products/products.controller.ts#L148) |

None of the three reaches the app. A merchant on a plan without `hasZakat` sees the Закят menu item, opens it, and the server answers 403 — which the app surfaces as "Недостаточно прав". That symptom has been chased before as if it were an auth bug.

`hasInvestments` is the fourth missing flag and is not currently enforced anywhere, so it is latent rather than live.

### 2. The app's unknown-flag fallback runs opposite to the server's

The two sides disagree about what to do with a flag they do not recognise, and the app takes the unsafe side:

```dart
// subscription_state.dart — hasFeature(String key)
default:
  return true;
```

against the server's documented rule in
[feature-flag.helper.ts:4-9](api/src/common/guards/feature-flag.helper.ts#L4-L9):

> Fail-closed (false) if there's no subscription, no plan config row … a missing/misconfigured plan should not silently unlock a paid feature.

So `hasFeature('hasZakat')` returns `true` today, for every plan. The one case where the two sides disagree is exactly the case that exists.

**Not to be "fixed" alongside it:** `assertWithinPlanLimit`
([plan-limit.helper.ts:30-38](api/src/common/guards/plan-limit.helper.ts#L30-L38))
is fail-**open** on purpose — a missing config row means an admin has not configured that tier yet, and limits should not block. Two opposite conventions on the server, both deliberate. This spec changes the client's handling of *flags* only.

### 3. Prices on screen are not the prices charged

The plan cards are built entirely from ARB strings
([subscription_page.dart:39-80](app/lib/presentation/pages/settings/subscription_page.dart#L39-L80)):

| plan | card says | `subscription_plan_configs` charges |
|---|---|---|
| START | 49 TJS/мес | 200.00 |
| BUSINESS | 149 TJS/мес | 400.00 |
| PREMIUM | 299 TJS/мес | 600.00 |

Observed on the emulator: tapping "Выбрать" under a card reading **49 TJS/мес** created a payment for **200.00**. The dev database may not carry production prices, but the numbers cannot be right by construction — one side is a constant in a translation file and the other is an admin-editable column.

### 4. The cards advertise a limit that no longer exists

`subscriptionFeatureStores1/3/5` promise "1 магазин" / "3 магазина" / "5 магазинов". `maxStores` was dropped from `SubscriptionPlanConfig` in 2026-05 because each store carries its own subscription, and it is enforced nowhere. The immediately preceding branch removed the client's dead `limits.maxStores` field; the *advertisement* of it survived in the marketing copy.

---

## Design

### A single mapping, used everywhere

The server stops hand-assembling `features` and `limits`. One function maps a `SubscriptionPlanConfig` row to a `PlanView` carrying the price, all three limits and **all eleven** flags. `getSubscription` returns that for the current plan, and the existing public `GET /subscription/plans` returns it for every plan.

`features` **grows from seven keys to eleven** and `limits` keeps its three, both derived from `PlanView` rather than typed out. Growing `features` is the point — no existing reader breaks, because adding keys cannot break a reader, and the four that were missing are the whole defect. The admin panel does not read either object (checked: only test mocks reference the route), so the blast radius is the app, where `SubscriptionFeatures` grows to match.

### The merchant's price is computed server-side, once

`adminDiscount` applies to whichever plan the merchant picks — `requestChange` charges `price × (1 − discount/100)` for the *requested* plan. The public `/plans` route is unauthenticated and cannot know the merchant, so it returns list prices.

Therefore `GET /stores/:id/subscription` gains **`availablePlans`**: a `PlanView` per plan with the price already reduced by this merchant's discount, computed by the same helper `requestChange` uses. The card shows exactly the number that will be charged.

Having the app multiply by the discount itself would be a new instance of the defect this spec exists to remove: a server formula restated in the client, free to drift.

### A guard against the list drifting again

A test parses `model SubscriptionPlanConfig` out of `api/prisma/schema.prisma` and fails if any `has*` column is absent from `PlanView`. This is the third use of that technique in this codebase — `payment_status_test.dart` and `subscription_status_test.dart` both parse the same file, and on the previous branch a reviewer independently broke the mapping with a *different* enum value to prove the guard was not vacuous.

Without it this change is cosmetic. The four flags went missing precisely because a hand-kept list had nothing checking it.

### `hasFeature(String)` is deleted rather than repaired

It has **zero callers**: both real gates read `features.hasExport` / `features.hasEcommerceIntegration` directly. So it is a dead accessor whose `default: return true` is a trap primed for whoever calls it first — and the flags it would answer `true` about are precisely the ones the server denies.

Deleting beats converting here. The codebase's standing lesson is that "no caller" does not mean "dead" — but that lesson came from an *endpoint* that was the unconnected half of a feature whose UI, model and route all existed. This is a convenience accessor duplicating a field read, with no waiting half. Nothing is lost by removing it, and the typed field reads that survive are already exhaustive by construction.

What replaces the safety it never provided: `SubscriptionFeatures` gains the four missing fields, so every gate is a plain typed field read, and a flag that does not exist is a compile error rather than a `true`.

### Plan cards: authored words, server numbers

The bullet wording stays in `app_ru.arb` — the cards are sales copy, not a database view, and some bullets ("Отчёт продаж", "Валюты") have no column behind them at all. Every **number** comes from `availablePlans`: price, products, staff, discounts. The store-count bullets are deleted along with their three ARB keys.

If `availablePlans` is absent or empty, the plan list renders an error-with-retry rather than any number. Showing an unverified price is the defect being fixed, so a hardcoded fallback would reintroduce it in a quieter form.

### Zakat, Loyalty and batch profitability get gated

Each entry point uses the dialog that already exists for the e-commerce tile — "Доступно на тарифе…", with a button through to the subscription screen. The dialog, its four ARB keys and the pattern are already in the codebase
([settings_page.dart:372](app/lib/presentation/pages/settings/settings_page.dart#L372)).

Gating is what turns a 403 into an explanation. It is not a substitute for the server's check, which stays as it is.

---

## Testing

- **Schema completeness**, as above — the load-bearing test. Verified by removing one flag from `PlanView` and confirming it fails naming that flag.
- **Price agreement**: for a given plan and a given `adminDiscount`, the number in `availablePlans` equals the `amount` that `request-change` writes to the `Payment` row. An API e2e test against the real Postgres, in the style of `api/test/cogs.e2e-spec.ts`.

  This is not a formality. The two expressions already differ today: `getSubscription` rounds (`Math.round(calculatedPrice * 100) / 100`, [:223](api/src/modules/subscriptions/subscriptions.service.ts#L223)) and `requestChange` does not ([:248](api/src/modules/subscriptions/subscriptions.service.ts#L248)). A 33% discount on the PREMIUM price of 600 gives `401.99999999999994` from one and `402` from the other — not 200, whose `200 * (1 - 33/100)` is exactly 134 and therefore proves nothing; `Decimal(12,2)` happens to reconcile them on write, so the discrepancy is invisible until it is not. Both must come from one helper, and the test must use a discount whose arithmetic is not exact — 33, not 50.
- **Fail-closed**: a gate denies when subscription data is missing. There is no catch-all left to test, which is the point: with `hasFeature(String)` gone, every flag is a typed field and an unknown one does not compile.
- **Card rendering**: the price and the three limits on each card come from the state, not from constants — verified by rendering with values that differ from the old ARB numbers, so a leftover constant fails rather than coincidentally matching.
- **Device**: a merchant with a **non-zero** `adminDiscount`. Without one the two pricing formulas agree by accident and the test proves nothing — this is the same trap as the one-hour margin that made an earlier trial-countdown test pass under both implementations.

## Out of scope, already recorded

Duplicate pending payments can each be approved, each extending the period by 30 days: `requestChange` does not check for an existing PENDING row and `adminApprovePayment` has no cross-payment guard. Related: the requested plan travels inside the free-text `note` and is recovered at approval time with `/Plan change request to (\w+)/`, and the 30-day extension ignores what was actually bought. That is a data-model problem and gets its own spec.
