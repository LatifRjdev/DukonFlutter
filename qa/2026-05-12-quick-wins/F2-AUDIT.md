# F.2 Audit — Mixed-Coverage @RequiresFeature/@RequiresPlan — 2026-05-14

## Method

Greped every controller in `api/src/modules/*/`. For each
controller that has at least one `@RequiresFeature` or
`@RequiresPlan` (method OR class level), checked whether every
HTTP-method-decorated handler is guarded. Methods without a
feature gate AND without class-level coverage are candidates
for either an oversight or an intentional gap.

This audit follows the F.2.4 refactor (commit `043e0f1`) which
moved 4× `@RequiresFeature('hasReportsAll')` to class level on
`reports.controller.ts`.

The `SubscriptionGuard` (`api/src/common/guards/subscription.guard.ts`)
reads metadata via `reflector.getAllAndOverride([handler, class])`,
so class-level `@RequiresFeature` covers every method that does
not declare its own. The guard also early-returns when no
`storeId` route param is present (line 30–32), which is relevant
for routes that are intentionally not store-scoped.

## Candidate scan summary

5 controllers in `api/src/modules/*/` use `@RequiresFeature` (no
controller currently uses `@RequiresPlan`).

| Controller | Total HTTP methods | Per-method guarded | Class-level guard | Status |
|------------|-------------------:|-------------------:|:-----------------:|--------|
| `inventory-counts/inventory-counts.controller.ts` | 4 | 0 | yes (`hasInventory`) | clean |
| `deliveries/deliveries.controller.ts` | 4 | 0 | yes (`hasDelivery`) | clean |
| `reports/reports.controller.ts` | 5 | 1 (`@Get('export')` adds `hasExport` on top of class-level `hasReportsAll`) | yes (`hasReportsAll`) | clean |
| `notifications/notifications.controller.ts` | 4 | 1 (`@Put('settings')` → `hasAllPush`) | no | mixed |
| `telegram/telegram.controller.ts` | 2 | 1 (`@Post('send-receipt')` → `hasTelegram`) | no | mixed |

## Mixed-coverage findings

### `modules/notifications/notifications.controller.ts`

- **Class-level:** none. Class-level guards are `@UseGuards(JwtAuthGuard)` only; `StoreAccessGuard` and `SubscriptionGuard` are added per-method.
- **Methods covered by `@RequiresFeature`:**
  - `PUT stores/:storeId/notifications/settings` → `hasAllPush`
- **Methods NOT covered:**
  - `POST users/me/fcm-token` — INTENTIONAL public-feature: route is not store-scoped (no `storeId` param), so a class-level `@RequiresFeature('hasAllPush')` would never fire anyway because `SubscriptionGuard` early-returns when `storeId` is missing. Plus, FCM tokens may be needed for system-wide notifications (subscription warnings) that are sent to every user regardless of plan. Guarded only by `JwtAuthGuard`.
  - `GET stores/:storeId/notifications` — INTENTIONAL: notification *history* is read-only and `notifications.service.ts:sendPush()` always persists to DB regardless of plan. A START-tier user can still receive system events (e.g. subscription expiring) and must be able to read them. Guarded by `JwtAuthGuard + StoreAccessGuard`.
  - `PUT stores/:storeId/notifications/:id/read` — INTENTIONAL: marking your own notification as read pairs with the read endpoint above. Guarded by `JwtAuthGuard + StoreAccessGuard`.

### `modules/telegram/telegram.controller.ts`

- **Class-level:** none. The two routes have very different audiences (Telegram servers vs authenticated staff), so class-level guards are unsuitable.
- **Methods covered by `@RequiresFeature`:**
  - `POST stores/:storeId/telegram/send-receipt` → `hasTelegram`
- **Methods NOT covered:**
  - `POST telegram/webhook` — INTENTIONAL public webhook, called by Telegram's servers (not by app clients). Not store-scoped, so `SubscriptionGuard` would early-return regardless. The handler validates the `X-Telegram-Bot-Api-Secret-Token` header in-body using `TELEGRAM_WEBHOOK_SECRET`. No `@Public` decorator is present because the controller does not have a class-level `@UseGuards(JwtAuthGuard)`; per-method `@UseGuards` keeps this route open by default.

## Per-finding intent + recommendation

### `notifications.controller.ts` — POST `users/me/fcm-token`

Route is user-scoped, not store-scoped. SubscriptionGuard with
`hasAllPush` would no-op anyway. Even if it did fire, gating
this would prevent START-tier users from receiving important
system notifications (subscription expiring, payment failures).
Correctly unguarded. **No change recommended.**

### `notifications.controller.ts` — GET `stores/:storeId/notifications` and PUT `.../notifications/:id/read`

Reading and acknowledging notification history is a baseline
account-management capability. The push-delivery feature
(`hasAllPush`) gates only the *settings* endpoint and the
sales-service `maybeNotifyBigSale` send path. **No change
recommended.**

### `telegram.controller.ts` — POST `telegram/webhook`

Webhook handler called by Telegram, not by app clients.
Authentication is a shared secret in the
`X-Telegram-Bot-Api-Secret-Token` header (verified in the
handler body). Adding `@RequiresFeature('hasTelegram')` here
would be both useless (no `storeId` to look up subscription
against) and incorrect (Telegram has no subscription record).
**No change recommended.**

## Recommendations

- **0 OVERSIGHT findings.** Every unguarded method in a
  mixed-coverage controller has a defensible reason:
  - Webhook endpoints called by external services (Telegram),
  - User-scoped routes that are not store-scoped (FCM token),
  - Read endpoints for notification history that should remain
    available regardless of plan.
- No follow-up spec is required. The F.2.4 refactor closed the
  one historical gap (`/reports/sales` was missing the gate)
  and class-level `@RequiresFeature` now works correctly via
  the F.2 reflector fix in `SubscriptionGuard`.
- The two clean class-level controllers
  (`deliveries.controller.ts`, `inventory-counts.controller.ts`)
  rely on the same F.2 reflector pattern; both have inline
  comments documenting the dependency for future maintainers.
