# Admin: Store Creation and Tariff Assignment — Design

**Date:** 2026-10-01
**Status:** Approved
**Base:** `main` at `62adb72`

## Goal

Let an admin create a store for an **existing** user, and assign or change a store's subscription plan.
Both are currently impossible from the admin panel.

## What already exists — and why this is smaller than it looks

Exploration turned up more existing capability than the request assumed, which removes two thirds of the
obvious work:

- **`POST /admin/users` already creates a user with a first store** in one transaction
  (`createUserManually` → `storesService.create`), and returns a generated password once. The admin
  users page already has that form. **Not rebuilt here.**
- **`storesService.create(ownerId, dto, tx?)` already does everything a new store needs**: creates the
  store, creates a `Subscription` with `plan: PREMIUM, status: TRIAL` and a 7-day trial window, and
  creates a `Staff` row with role `OWNER`. The new endpoint composes this rather than duplicating it.
- **`AuditInterceptor` already logs every `POST`/`PUT`/`PATCH`/`DELETE` on `/admin/` routes**, deriving
  entity type and action from the route and snapshotting before/after. Both new endpoints inherit audit
  logging by being declared on the existing `admin/stores` controller — nothing to write.
- The admin stores page already has `Dialog`, `Select`, `DataTable`, `ConfirmDialog` and toast wired up,
  with `suspend`/`unsuspend`/`transfer` as working precedents for an action that mutates a store.

So the gap is exactly three things: one endpoint to create a store for an existing owner, one endpoint
to change a subscription, and the UI for both.

## Domain facts that shape the design

- **A subscription belongs to a store, not to a user** — `Subscription.storeId` is `@unique`, and
  `Store.ownerId` points at the owner. "Give a user the Business tariff" therefore means "set the plan
  on that user's store". A user with three stores has three independent subscriptions.
- Plans are `START` / `BUSINESS` / `PREMIUM`; statuses are `TRIAL` / `ACTIVE` / `PAST_DUE` /
  `CANCELLED` / `EXPIRED`.
- Limits and feature flags live in `SubscriptionPlanConfig` (`maxProducts`, `maxStaff`, `maxDiscounts`,
  `hasZakat`, `hasEcommerceIntegration`, …) and are enforced server-side by
  `common/guards/plan-limit.helper.ts` and `common/guards/feature-flag.helper.ts`. Changing a plan has
  real behavioural consequences, which is what makes it worth testing on two accounts.
- **Every new store starts on `PREMIUM` + `TRIAL`.** A freshly created store is therefore not a
  Business account — reaching one requires the plan-change endpoint. This is why creating the two test
  accounts exercises both new capabilities rather than just one.

## Part 1 — `POST /admin/stores`

Creates a store for an existing user.

```
POST /admin/stores
{ ownerId, name, category, currency?, address?, phone? }
```

- `ownerId` must resolve to an existing user — `404 Not found` otherwise, matching `transferStore`'s
  existing behaviour for an unknown new owner.
- The remaining fields mirror `CreateStoreDto` exactly (`name` ≤ 100 chars and `@IsSafeText`,
  `category` one of the six `StoreCategory` values, `currency` one of `TJS`/`USD`/`RUB` defaulting to
  `TJS`). The DTO is defined fresh rather than extending `CreateStoreDto`, because the admin variant
  carries `ownerId` while the self-service one derives the owner from the JWT — but field rules are
  copied verbatim so the two cannot drift in validation strictness.
- The handler delegates to `storesService.create`, so the store gets its `PREMIUM`/`TRIAL` subscription
  and `OWNER` staff row through exactly the same path self-service registration uses. No second
  creation path to keep in sync.
- Throttled at the same rate as the other mutating admin store routes (60/min).

**Deliberately not done:** creating a user inline. `POST /admin/users` already covers that, including
the store. Adding a second way to create a user would mean two places to keep consistent.

## Part 2 — `PUT /admin/stores/:id/subscription`

Assigns or changes a store's plan.

```
PUT /admin/stores/:id/subscription
{ plan, status, currentPeriodEnd }
```

- `plan` and `status` are the respective enums; `currentPeriodEnd` is an ISO date.
- **All three are set together, not just `plan`.** Setting the plan alone is the obvious minimal design
  and it is wrong here: a store whose subscription is `EXPIRED` or whose `currentPeriodEnd` is in the
  past would have its plan changed and still behave as though it had no entitlement, because the
  server-side guards consult status and period. An admin who grants Business and sees nothing change
  would reasonably call that a bug. Requiring all three makes the grant actually take effect.
- If the store has **no** subscription row, the endpoint creates one rather than failing. Every store
  created through `storesService.create` has one, but a store created by an older path or a partially
  failed migration might not, and an admin tool that cannot repair that state is less useful than one
  that can. `currentPeriodStart` is set to now on create and left untouched on update.
- `trialEndsAt` is left alone. It records when the original trial ended and is not something an admin
  grant should rewrite.
- `adminDiscount` and `Payment` records are **out of scope** — they carry financial-reporting semantics
  that need their own decision about what an admin grant means for revenue figures.
- Returns the updated subscription so the UI can reflect it without a refetch.
- Throttled at 60/min, audit-logged automatically.

## Part 3 — Admin UI

Both actions live on the existing stores page, which already owns the suspend and transfer dialogs.

**Create store.** A "Создать магазин" button in the page header opens a dialog with: owner search by
phone (reusing the pattern the transfer dialog already uses to pick a user), store name, category
select, and optional currency/address/phone. On success it toasts and invalidates the stores query.

**Change tariff.** A "Тариф" action in each row's dropdown — beside the existing suspend and transfer
actions — opens a dialog preloaded with the store's current subscription (already available from
`GET /admin/stores/:id/subscription`), offering plan select, status select, and a period-end date. The
dialog states the current plan so the admin can see what they are changing from.

Both dialogs surface server validation errors inline rather than only as a toast, since `ownerId` not
found and a malformed date are both recoverable mistakes the admin should see next to the field.

## Testing

- **Backend unit/e2e** following the existing admin test patterns: store created for a valid owner gets
  a subscription and an `OWNER` staff row; unknown `ownerId` → 404; plan change updates all three fields;
  plan change on a store with no subscription creates one; non-admin caller → 403; audit entries written
  for both routes.
- **Admin UI** with the existing Vitest + MSW setup used by `stores/page.test.tsx`: both dialogs submit
  the right payload, show server errors inline, and invalidate the right query.
- **End-to-end by use**: the two test accounts for the app-testing task are created *through this
  feature* rather than seeded, so a failure in either endpoint surfaces immediately as a real workflow
  failure rather than a passing test.

## Verification

| Check | Expectation |
|---|---|
| `npm run lint` + `npx tsc --noEmit` in `api/` and `admin/` | clean |
| `npm test` in `api/` | existing suites pass, new ones added |
| `npm test` in `admin/` | existing suites pass, new ones added |
| Flutter | untouched — no `app/` changes in this work |
| Audit log | both new routes appear in `/admin/audit-log` after use |

## Risks

- **A plan change that does not take effect.** Mitigated by requiring status and period together, and
  by verifying on a real account that a `BUSINESS` grant actually closes `PREMIUM`-only features.
- **Two store-creation paths drifting.** Mitigated by delegating to `storesService.create` rather than
  writing a second one.
- **Admin granting themselves entitlements.** Already bounded by `AdminGuard` plus the automatic audit
  trail; no new exposure beyond what suspend/transfer already carry.
