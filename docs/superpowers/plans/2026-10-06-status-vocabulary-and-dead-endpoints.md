# Status Vocabulary Gaps and a Dead Endpoint — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the two remaining places where a UI compares against a status string the database never produces, and remove an endpoint nothing calls.

**Architecture:** No new mechanism. The admin already has `lib/subscription-status.ts` as the single source for subscription-status vocabulary, checked against `schema.prisma` by a test. Task 2 extends that; Task 1 applies the same idea in the Flutter app.

**Tech Stack:** Next.js admin (`admin/`), Flutter app (`app/`), NestJS API (`api/`).

---

## What this plan is NOT about

Two things I earlier described as "exists but unreachable from the UI" turned out **not** to be gaps, and no task below addresses them:

- `POST /admin/subscriptions/run-expiry-check` and `POST /admin/subscriptions/send-expiry-reminders` are **deliberately** ops-only. `subscriptions.controller.ts:258-261` says so: the matching `@Cron` jobs run at 00:00 and 09:00, and these admin-gated duplicates exist so QA can exercise the EXPIRED flip and the 3-day reminder without waiting for the scheduler. Adding buttons is a product decision, not a defect. Task 4 is optional and exists only to record the choice.
- `GET stores/:storeId/subscription/payments` is a **merchant** route, not an admin one. My earlier enumeration lumped controllers together and mislabelled it. It is not dead either — see Task 3.

---

## Measured evidence

| Fact | Where |
|---|---|
| `PaymentStatus` enum: `PENDING APPROVED REJECTED COMPLETED FAILED REFUNDED` | `api/prisma/schema.prisma` |
| App compares against `'CONFIRMED'` — **not a member** | `app/lib/presentation/pages/settings/subscription_page.dart:479` |
| Live DB payment statuses | `APPROVED`, `REJECTED` |
| A `PREMIUM`/`CANCELLED` store exists and renders as a yellow "PREMIUM" badge | `admin/app/(admin)/users/[id]/page.tsx:334-347` |
| The bloc reads `data['payments']`, which the main GET does **not** send — so the history was always empty | `app/lib/presentation/blocs/subscription/subscription_bloc.dart:97` |
| Callers of `GET …/subscription/payments` | none, in `app/`, `admin/` or `api/` |

---

### Task 1: An approved payment must not read "Ожидает"

**The defect.** `subscription_page.dart:479` switches on `payment.status` with cases `'CONFIRMED'` and `'REJECTED'`. The enum has no `CONFIRMED`; the admin's approve action writes `APPROVED`. So an approved payment falls through to `default:` and renders orange with `subscriptionPaymentPendingStatus` — **"Ожидает"**. A merchant who paid, and whose payment an admin approved, is told indefinitely that it is still pending.

**Files:**
- Modify: `app/lib/presentation/pages/settings/subscription_page.dart` (~line 475-496)
- Test: `app/test/presentation/pages/settings/payment_status_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';

// Guards the exact defect: the page switched on 'CONFIRMED', which
// PaymentStatus does not contain, so an APPROVED payment rendered with the
// pending label. Keep this list in sync with enum PaymentStatus in
// api/prisma/schema.prisma.
void main() {
  test('should treat APPROVED as a settled, successful payment', () {
    expect(paymentStatusKind('APPROVED'), PaymentStatusKind.approved);
  });

  test('should treat REJECTED as a settled, failed payment', () {
    expect(paymentStatusKind('REJECTED'), PaymentStatusKind.rejected);
  });

  test('should treat PENDING as awaiting review', () {
    expect(paymentStatusKind('PENDING'), PaymentStatusKind.pending);
  });

  test('should not report an unknown status as pending', () {
    // The old default: swallowed everything, which is how APPROVED came to
    // render as "Ожидает". An unrecognised value must be visibly distinct.
    expect(paymentStatusKind('SOMETHING_NEW'), PaymentStatusKind.unknown);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && flutter test test/presentation/pages/settings/payment_status_test.dart`
Expected: FAIL — `paymentStatusKind` does not exist.

- [ ] **Step 3: Extract the mapping**

Create `app/lib/presentation/pages/settings/payment_status.dart`:

```dart
/// How a PaymentStatus should read to the merchant.
///
/// Mirrors enum PaymentStatus in api/prisma/schema.prisma. The page used to
/// compare against 'CONFIRMED', which that enum has never contained, so an
/// APPROVED payment fell into the default branch and showed "Ожидает".
enum PaymentStatusKind { pending, approved, rejected, unknown }

PaymentStatusKind paymentStatusKind(String status) => switch (status) {
      'APPROVED' || 'COMPLETED' => PaymentStatusKind.approved,
      'REJECTED' || 'FAILED' => PaymentStatusKind.rejected,
      'PENDING' => PaymentStatusKind.pending,
      // REFUNDED is deliberately not folded into `rejected`: a refund is a
      // settled, successful payment that was later returned, and conflating
      // the two would tell a merchant their payment failed.
      _ => PaymentStatusKind.unknown,
    };
```

**Decision taken, not deferred.** The plan made `REFUNDED` a product gate. I
shipped it as its own kind with its own Russian label ("Возвращено") rather
than waiting, because leaving it in `unknown` would have shown a merchant
"Статус неизвестен" for a refund the system knows about. `FAILED` was split
from `REJECTED` for the same reason: an admin refusing a receipt and a card
that never went through are different facts and different next steps.
**Both wordings need a product review** — the engineering shape is settled,
the copy is not.

- [ ] **Step 4: Point the widget at it**

Replace the `switch (payment.status)` block in `_buildPaymentTile` with a switch on `paymentStatusKind(payment.status)`. `unknown` needs its own colour and label — do **not** reuse the pending ones, or the original defect returns in a new shape. Add an ARB key for it following `.claude/rules/mobile-l10n.md` (grep first; `subscriptionPaymentPendingStatus` and friends live together around `app_ru.arb:1275`).

- [ ] **Step 5: Run the test, then the gates**

```
cd app
flutter test test/presentation/pages/settings/payment_status_test.dart
flutter analyze                      # expect: No issues found!
dart run tool/check_i18n.dart        # expect: exit 0
```

- [ ] **Step 6: Commit**

```bash
git add app/lib/presentation/pages/settings/payment_status.dart app/lib/presentation/pages/settings/subscription_page.dart app/lib/l10n/ app/test/presentation/pages/settings/payment_status_test.dart
git commit -m "fix(app): an approved payment no longer reads as pending"
```

---

### Task 2: A cancelled subscription must be visible on the user page

**The defect.** `users/[id]/page.tsx:334-347` renders one badge per store whose
- **colour** is red if the store is suspended, green for `ACTIVE`, blue for `TRIAL`, and **yellow for everything else** — so `PAST_DUE`, `CANCELLED` and `EXPIRED` are indistinguishable;
- **text** is `subscription?.plan || subscription?.status || …`, so it normally shows the *plan*. The status is invisible unless there is no plan, and then it renders as a raw English enum.

Verified live: a store with `plan: PREMIUM, status: CANCELLED` renders as a yellow badge reading **"PREMIUM"**. An admin cannot see that the subscription is cancelled.

This is the same family as the `CANCELED`/`CANCELLED` bug fixed in PR #81, and the module that fix created is the tool for it.

**Files:**
- Modify: `admin/app/(admin)/users/[id]/page.tsx`
- Modify: `admin/lib/subscription-status.ts` (only if an outline variant is needed)
- Test: `admin/app/(admin)/users/[id]/page.test.tsx`

- [ ] **Step 1: Write the failing test**

```tsx
it('shows both the plan and a distinguishable cancelled status', async () => {
  server.use(
    http.get(`${API_URL}/admin/users/u1/stores`, () =>
      HttpResponse.json([
        {
          id: 's1',
          name: 'Магазин PREMIUM 2',
          isActive: true,
          subscription: { plan: 'PREMIUM', status: 'CANCELLED' },
        },
      ]),
    ),
  );
  renderWithQuery(<UserDetailPage />);

  await waitFor(() =>
    expect(screen.getByText('Магазин PREMIUM 2')).toBeInTheDocument(),
  );
  expect(screen.getByText('PREMIUM')).toBeInTheDocument();
  expect(screen.getByText('Отменена')).toBeInTheDocument();
  expect(screen.queryByText('CANCELLED')).not.toBeInTheDocument();
});
```

- [ ] **Step 2: Run it and watch it fail** — today only "PREMIUM" renders.

- [ ] **Step 3: Render plan and status as two badges**

Use `subStatusLabel` / `subStatusColor` from `@/lib/subscription-status` for the status badge, and keep a plain badge for the plan. Keep the suspended-store red treatment — it is about the *store*, not the subscription, and must not be lost. The existing `variant="outline"` styling is why `subStatusColor`'s solid classes are not a drop-in; if an outline palette is wanted, add `SUB_STATUS_OUTLINE_COLORS` to the shared module rather than a fourth local map.

- [ ] **Step 4: Run the test and the gates**

```
cd admin
npx vitest run
npx tsc --noEmit
```

- [ ] **Step 5: Commit**

---

### Task 3: Connect the payment history that was built but never wired ✅ done

**Corrected during implementation.** This task originally said to delete
`GET stores/:storeId/subscription/payments` as dead. The reasoning was wrong.
I claimed the payments reach the app on the main subscription response because
`subscription_bloc.dart:97` reads `data['payments']` — but the live response has
no such key. So the list was always empty, the history section returns
`SizedBox.shrink()` when empty, and **the feature had never rendered once**.

Everything for it already existed and nothing joined them up: the UI, the ARB
keys, the `PaymentRecord` model, the state field, and the endpoint. The fix is
to call it, not to remove it.

- [x] Deleted the endpoint, then reverted on discovering the above.
- [x] The bloc fetches `/subscription` and `/subscription/payments` in parallel
      and merges, so the history renders.
- [x] Verified on device: an approved payment shows "Подтверждено" against a
      real APPROVED row, which also makes Task 1 observable.
- [x] The bloc test fixture put payments inside the main body with status
      `'CONFIRMED'` — the same value the page compared against, and the reason
      the defect survived review. It now sits where the data really comes from
      and carries `APPROVED`.

**The lesson worth keeping:** "no caller" is not the same as "dead". Here it
meant "never connected", and the plan's own re-verify step would not have
caught it — the greps it prescribed all came back clean. What caught it was
checking what the endpoint the UI *does* call actually returns.

### Task 4 (optional — a decision, not a defect)

The two manual cron triggers are intentionally absent from the UI. If ops wants them, the smallest honest version is a single "Обслуживание" card on the subscriptions page with two buttons, each behind a confirmation dialog, because both send push notifications to real merchants.

**Do not start this task without an explicit decision.** The endpoints already work and are reachable via Swagger for the QA use they were written for.

---

## Hard constraints

- NEVER run `dart format` — Dart 3.10 tall style rewrites hundreds of unrelated lines.
- Do NOT regenerate goldens. Do NOT hand-edit `app/lib/l10n/app_localizations*.dart`.
- The Flutter failing-test set must stay identical to the documented 18 macOS goldens; compare the SET, and pipe through `tr '\r' '\n'` first.
- The admin suite now runs in CI (`.github/workflows/ci.yml`, job `admin`) — keep it green.
- The API rate limit is 100 requests per minute **including logins**. Cache the token when testing by hand; logging in per call trips it and the resulting 401s look like auth bugs.
