# Payment integrity: one pending request, and the plan in a column

**Date:** 2026-10-08
**Branch:** `fix/payment-integrity`, based on `fix/plan-config-single-source` (which is based on `fix/subscription-receipt-and-past-due`). All three edit `subscriptions.service.ts`; the two below are reviewed and this one stacks on them.
**Scope:** two defects in how a subscription payment becomes a plan change. API only — no app changes.

---

## 1. Two pending requests can both be approved, and each extends the period

`requestChange`
([subscriptions.service.ts:239](api/src/modules/subscriptions/subscriptions.service.ts#L239))
creates a `PENDING` payment without looking for an existing one. `adminApprovePayment`
([:357](api/src/modules/subscriptions/subscriptions.service.ts#L357))
refuses to re-approve *the same* payment and refuses a previously-rejected one, but has no cross-payment guard at all. Each approval extends `currentPeriodEnd` by 30 days from whatever it then is
([:406](api/src/modules/subscriptions/subscriptions.service.ts#L406)).

So a merchant who taps submit twice — or who resubmits because the first attempt looked like it failed — creates two rows, and an admin working through the queue approves both. The subscription gains 60 days for one payment's worth of money.

This is not hypothetical: the branch two steps down this stack fixed a receipt flow that *reported* failure after creating the request, which is precisely the input that produces a double-submit.

### Fix

**At creation:** `requestChange` rejects while a `PENDING` payment already exists for that subscription, naming it. Not "supersede the old one" — `PaymentStatus` has no cancelled state, and reusing `REJECTED` would write "an admin refused this" into the audit trail, which is false. The merchant already sees a pending banner on the subscription screen, so the honest answer is to say the request is already in.

The case this loses — a merchant who picked the wrong plan and wants to change it before review — is rarer than the double-submit, and an admin rejecting the first request unblocks it today.

**At approval:** approving a payment auto-rejects every other `PENDING` payment on the same subscription, with a `rejectionReason` saying which payment superseded it. The guard above should make duplicates unreachable, but rows created before this branch already exist, and a guard that only works for new data is not a guard.

## 2. The requested plan travels as free text and is recovered by regex

`requestChange` writes `note: \`Plan change request to ${dto.plan}\`` ([:271](api/src/modules/subscriptions/subscriptions.service.ts#L271)) and `adminApprovePayment` reads it back with `/Plan change request to (\w+)/` ([:394](api/src/modules/subscriptions/subscriptions.service.ts#L394)). If the match fails, `newPlan` silently stays the merchant's current plan — the money is taken and the plan does not change.

Three ways it fails, one of which is live today:

- **A manual payment.** `adminCreateManualPayment` writes `note: dto.notes` ([:496](api/src/modules/subscriptions/subscriptions.service.ts#L496)) — whatever the admin typed. The row sitting in the dev database reads `Оплата за тариф Бизнес`, which the regex cannot match. Whether a manual payment *should* change the plan is a separate question; today it silently cannot, and nothing says so.
- **An edited note.** The column is human-readable and nothing stops an admin correcting it.
- **A wording change.** The string is English in a Russian-language product; the first person to translate it breaks plan changes with no test failing.

The schema comment at `Payment.note` already calls this the "original request note", so the field is doing double duty as prose and as data.

### Fix

`Payment` gains a nullable `requestedPlan` column of the `SubscriptionPlan` enum. `requestChange` sets it; `adminApprovePayment` reads it and the regex goes away. The note stays, as prose.

A data migration backfills `requestedPlan` from existing notes where the English pattern matches. **Rows it cannot parse are left null, and a null means "do not change the plan"** — which is exactly what happens to them today, only now it is explicit rather than an invisible regex miss. Blocking approval on a null would be more correct in the abstract but risks stalling real pending payments in production for a case the system has always silently allowed.

## Deliberately NOT changed

The 30-day extension is hardcoded in `adminApprovePayment` while `adminCreateManualPayment` takes `periodDays` from the admin. That looked like a third defect and is not: plans are sold monthly, and the manual path exists so an admin can grant a non-standard period. The difference is intentional. The constant is named rather than left as a bare `30`.

## Testing

- **Duplicate creation**: a second `requestChange` while one is pending throws, and no second row is written. Asserted on the row count, not just the exception.
- **Supersede on approve**: with two pending rows (inserted directly, since the guard above now prevents creating them through the API), approving one rejects the other and the period advances by **30 days, once**. The period assertion is the one that matters — the status change alone would not catch a double extension.
- **The plan comes from the column**: approving a payment whose `requestedPlan` is `PREMIUM` but whose `note` says `BUSINESS` must produce `PREMIUM`. A disagreeing fixture is the only way to prove the regex is gone rather than merely unused.
- **A null `requestedPlan` leaves the plan alone** and still extends the period.
- **The backfill**: run against a row whose note is the English pattern and one whose note is `Оплата за тариф Бизнес`; the first gets a plan, the second stays null.

All against the real Postgres, in the style of `api/test/plan-pricing.e2e-spec.ts` on the branch below.
