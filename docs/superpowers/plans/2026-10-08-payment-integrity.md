# Payment Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop a subscription from gaining two periods for one payment, and stop the requested plan from being lost because a regular expression did not match a free-text note.

**Architecture:** `Payment` gains a `requestedPlan` enum column that `requestChange` writes and `adminApprovePayment` reads, replacing the note-parsing regex. A data migration backfills what it can and leaves the rest null, where null means "extend the period, do not change the plan". `requestChange` refuses while a PENDING payment exists; approval auto-rejects any other PENDING on the same subscription.

**Tech Stack:** NestJS + Prisma + Jest, real-Postgres e2e in the style of `api/test/plan-pricing.e2e-spec.ts`.

**Spec:** `docs/superpowers/specs/2026-10-08-payment-integrity-design.md`

**Worktree:** `/Users/latifrjdev/Downloads/01_Проекты/Dukon/.worktrees/payment-integrity`, branch `fix/payment-integrity`, based on `fix/plan-config-single-source` at `4963430` — **not `main`**. Three branches now stack on each other because all three edit `subscriptions.service.ts`; the two below are reviewed.

**API only.** No file under `app/` changes.

---

## Environment notes

Run `npm`/`npx` from `api/`. **`npm ci` has NOT been run in this worktree** — do it first; until it finishes every `npx` misreports a missing TypeScript.

**`api/.env` is gitignored and `git worktree add` does not copy it.** If Prisma cannot find a database URL, copy it from the main checkout: `cp ../../api/.env api/.env`. This cost a previous task real time.

Postgres: container `dukonpro-db` on `:5435`. The e2e tests hit this **real** database — they create and delete their own rows.

### Traps

- **Do NOT use the `Read` tool on existing files** — a hook truncates files with prior observations to line 1 and has killed several agents. Use `awk '{print NR": "$0}' <path>` / `grep -n`.
- **Never bypass git hooks.** A guard rejects the flag outright; do not name it in any command. Pre-commit runs prettier/tsc/eslint on staged API files.
- `npm run lint` is report-only against a ~3572-problem baseline — **do not chase it**. `npx tsc --noEmit` at 0 is the gate. **Green Jest does not imply clean types**: ts-jest has let a real TS2769 and a real TS2345 through on this stack. Run both.
- **Prisma drops `undefined` filter fields**, so `deleteMany({ where: { x: undefined } })` empties the table. Initialise fixture ids to `''`.
- The API serves compiled `dist/` — `npm run build` then restart, in that order, before any live check.
- Line numbers below are from `4963430`; match on quoted content.

---

## File structure

| File | Responsibility | Change |
|---|---|---|
| `api/prisma/schema.prisma` | `Payment.requestedPlan` | Modify |
| `api/prisma/migrations/<ts>_payment_requested_plan/migration.sql` | Add the column, then backfill from the note | **Create** |
| `api/src/modules/subscriptions/subscriptions.service.ts` | Guard duplicates; write and read the column; supersede on approve | Modify |
| `api/test/payment-integrity.e2e-spec.ts` | All five behaviours, against real Postgres | **Create** |
| `api/src/modules/subscriptions/subscriptions.service.spec.ts` | Fakes gain `requestedPlan`; existing approve specs updated | Modify |

---

## Task 1: The column and its backfill

- [ ] **Step 1: Prepare the worktree**

```bash
cd api && npm ci
test -f .env || cp ../../api/.env .env
npx prisma generate
```

- [ ] **Step 2: Add the column to the schema**

In `api/prisma/schema.prisma`, inside `model Payment`, after the `note` field and its comment, add:

```prisma
  // The plan this payment is buying. Until 2026-10 it lived only inside
  // `note` as the English phrase "Plan change request to BUSINESS" and was
  // recovered at approval time by a regular expression — so a manual payment
  // (whose note the admin types), an edited note, or a translated string
  // silently left the plan unchanged while the money was taken. Nullable
  // because rows predating the column, and manual payments, may have no
  // parseable plan: null means extend the period and leave the plan alone.
  requestedPlan   SubscriptionPlan?
```

- [ ] **Step 3: Write the migration by hand, do not let Prisma invent the backfill**

```bash
cd api && npx prisma migrate dev --name payment_requested_plan --create-only
```
This writes the `ALTER TABLE` and stops. Open the generated `migration.sql` and **append** the backfill:

```sql
-- Backfill from the note's English pattern, which is the only format
-- requestChange has ever written. Rows it cannot parse — manual payments,
-- whose note the admin types freely — stay NULL, which the approve path reads
-- as "do not change the plan". That is already what happens to them today; the
-- column only makes it visible.
UPDATE "payments"
SET "requestedPlan" = 'START'
WHERE "note" LIKE 'Plan change request to START%' AND "requestedPlan" IS NULL;

UPDATE "payments"
SET "requestedPlan" = 'BUSINESS'
WHERE "note" LIKE 'Plan change request to BUSINESS%' AND "requestedPlan" IS NULL;

UPDATE "payments"
SET "requestedPlan" = 'PREMIUM'
WHERE "note" LIKE 'Plan change request to PREMIUM%' AND "requestedPlan" IS NULL;
```

Three explicit statements rather than a regex or a `CASE`: the set of plans is three and closed, and an exact `LIKE` per plan cannot mis-assign the way a loose pattern could.

- [ ] **Step 4: Apply and verify the backfill against real data**

```bash
cd api && npx prisma migrate dev
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "SELECT \"requestedPlan\", note FROM payments ORDER BY \"createdAt\" DESC LIMIT 10;"
```
Expected: rows whose note starts with the English phrase have a plan; the row reading `Оплата за тариф Бизнес` has `requestedPlan` NULL. **If every row is null, the backfill did not run** — check it was appended below the `ALTER TABLE`, not above it.

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/.worktrees/payment-integrity
git add api/prisma/schema.prisma api/prisma/migrations
git commit --file - <<'MSG'
feat(api): give Payment a requestedPlan column

The plan a payment buys lived only inside the free-text note, written in
English by requestChange and recovered at approval by a regular expression. A
miss leaves the plan unchanged while the money is taken, and it misses today
for manual payments, whose note the admin types — the row in the dev database
reads "Оплата за тариф Бизнес".

The migration backfills from the note's English pattern with one exact LIKE per
plan, because the set is three and closed and a loose pattern could
mis-assign. Rows it cannot parse stay NULL, which the approve path will read as
"extend the period, leave the plan alone" — already what happens to them, now
visibly.

Nothing reads the column yet.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
```

---

## Task 2: One pending request at a time

**Files:** `api/src/modules/subscriptions/subscriptions.service.ts:239-276`, `api/test/payment-integrity.e2e-spec.ts` (create)

- [ ] **Step 1: Write the failing test**

Create `api/test/payment-integrity.e2e-spec.ts` with the fixture pattern from `api/test/plan-pricing.e2e-spec.ts` — read it first; ids initialised to `''`, teardown deleting only what it created. Then:

```ts
  it('should refuse a second request while one is still pending', async () => {
    await subs.requestChange(storeId, {
      plan: 'BUSINESS',
      paymentMethod: 'CASH',
    } as any);

    await expect(
      subs.requestChange(storeId, {
        plan: 'PREMIUM',
        paymentMethod: 'CASH',
      } as any),
    ).rejects.toThrow();

    // The row count, not just the exception: a guard that throws AFTER
    // creating the row would pass an exception-only assertion while leaving
    // exactly the duplicate it exists to prevent.
    const pending = await prisma.payment.count({
      where: { subscriptionId, status: 'PENDING' },
    });
    expect(pending).toBe(1);
  });

  it('should allow a new request once the pending one is settled', async () => {
    const first = await subs.requestChange(storeId, {
      plan: 'BUSINESS',
      paymentMethod: 'CASH',
    } as any);
    await prisma.payment.update({
      where: { id: first.id },
      data: { status: 'REJECTED' },
    });

    const second = await subs.requestChange(storeId, {
      plan: 'PREMIUM',
      paymentMethod: 'CASH',
    } as any);
    expect(second.id).not.toBe(first.id);
  });

  it('should record the requested plan in the column, not only the note', async () => {
    const payment = await subs.requestChange(storeId, {
      plan: 'PREMIUM',
      paymentMethod: 'CASH',
    } as any);
    expect(payment.requestedPlan).toBe('PREMIUM');
  });
```

Each test must clean up its own payments in an `afterEach`, since the guard makes leftover PENDING rows break the next test.

- [ ] **Step 2: Run them to verify they fail**

```bash
cd api && npx jest --config test/jest-e2e.json payment-integrity
```
Expected: the first fails because no exception is thrown and `pending` is 2; the third fails because `requestedPlan` is undefined. The second passes already — it asserts behaviour that exists.

- [ ] **Step 3: Write the implementation**

In `subscriptions.service.ts`, inside `requestChange`, insert after the `planConfig` validation (after the `throw new BadRequestException('Invalid plan')` block, before the `amount` computation):

```ts
    // One pending request at a time. Nothing used to stop a second, and
    // adminApprovePayment has no cross-payment guard either, so an admin
    // working the queue approved both and the subscription gained two periods
    // for one payment's money. A double submit is the ordinary way this
    // happened: the receipt flow reported failure after creating the request
    // until the branch two steps below this one fixed it.
    const existingPending = await this.prisma.payment.findFirst({
      where: { subscriptionId: subscription.id, status: 'PENDING' },
      orderBy: { createdAt: 'desc' },
    });
    if (existingPending) {
      throw new ConflictException(
        'A payment request is already awaiting review',
      );
    }
```

Add `ConflictException` to the `@nestjs/common` import at the top of the file if it is not there.

Then in the `payment.create` call, add the column beside the note:

```ts
        note: `Plan change request to ${dto.plan}`,
        // The note stays as prose; THIS is the data. Reading the plan back out
        // of the note with a regex is what made a manual payment silently
        // fail to change anything.
        requestedPlan: dto.plan as any,
```

- [ ] **Step 4: Run them again**

```bash
cd api && npx jest --config test/jest-e2e.json payment-integrity
npx jest src/modules/subscriptions
npx tsc --noEmit ; echo "tsc exit=$?"
```
Expected: all three pass; the existing unit specs still pass; `tsc exit=0`.

**If a unit spec fails** because its fake Prisma has no `payment.findFirst`, add it — returning `null` is the right default for a fixture that is not testing the duplicate guard. Say which fakes you touched.

- [ ] **Step 5: Prove the guard is load-bearing**

```bash
cd api
cp src/modules/subscriptions/subscriptions.service.ts /tmp/svc.keep
perl -0pi -e 's/if \(existingPending\) \{\n.*?\n.*?\n.*?\n    \}/if (false) {}/s' src/modules/subscriptions/subscriptions.service.ts
npx jest --config test/jest-e2e.json payment-integrity 2>&1 | grep -E "✕|✓"
cp /tmp/svc.keep src/modules/subscriptions/subscriptions.service.ts ; rm -f /tmp/svc.keep
git status --short
```
Expected: the "refuse a second request" test fails and the other two pass; then a clean tree.

- [ ] **Step 6: Commit** — the message must say the row-count assertion exists because an exception-only test would pass a guard that throws after inserting.

---

## Task 3: Approval reads the column and supersedes the rest

**Files:** `api/src/modules/subscriptions/subscriptions.service.ts:386-430`, the e2e spec

- [ ] **Step 1: Write the failing tests**

Append to `api/test/payment-integrity.e2e-spec.ts`:

```ts
  it('should take the plan from the column even when the note disagrees', async () => {
    // A disagreeing fixture is the only way to prove the regex is gone rather
    // than merely unused: with both saying PREMIUM, either implementation
    // passes.
    const payment = await prisma.payment.create({
      data: {
        subscriptionId,
        amount: 600,
        currency: 'TJS',
        method: 'CASH',
        status: 'PENDING',
        note: 'Plan change request to BUSINESS',
        requestedPlan: 'PREMIUM',
      },
    });

    await subs.adminApprovePayment(subscriptionId, payment.id, 'admin-e2e');

    const sub = await prisma.subscription.findUnique({
      where: { id: subscriptionId },
    });
    expect(sub!.plan).toBe('PREMIUM');
  });

  it('should extend the period without changing the plan when no plan was requested', async () => {
    const before = await prisma.subscription.findUnique({
      where: { id: subscriptionId },
    });
    const payment = await prisma.payment.create({
      data: {
        subscriptionId,
        amount: 400,
        currency: 'TJS',
        method: 'CASH',
        status: 'PENDING',
        note: 'Оплата за тариф Бизнес',
      },
    });

    await subs.adminApprovePayment(subscriptionId, payment.id, 'admin-e2e');

    const after = await prisma.subscription.findUnique({
      where: { id: subscriptionId },
    });
    expect(after!.plan).toBe(before!.plan);
    expect(after!.currentPeriodEnd.getTime()).toBeGreaterThan(
      before!.currentPeriodEnd.getTime(),
    );
  });

  it('should reject the other pending payments and extend the period only once', async () => {
    // Inserted directly: Task 2's guard makes two pending rows unreachable
    // through the API, but rows created before that guard already exist.
    const [a, b] = await Promise.all([
      prisma.payment.create({
        data: {
          subscriptionId,
          amount: 400,
          currency: 'TJS',
          method: 'CASH',
          status: 'PENDING',
          requestedPlan: 'BUSINESS',
        },
      }),
      prisma.payment.create({
        data: {
          subscriptionId,
          amount: 400,
          currency: 'TJS',
          method: 'CASH',
          status: 'PENDING',
          requestedPlan: 'BUSINESS',
        },
      }),
    ]);

    const before = await prisma.subscription.findUnique({
      where: { id: subscriptionId },
    });

    await subs.adminApprovePayment(subscriptionId, a.id, 'admin-e2e');

    const other = await prisma.payment.findUnique({ where: { id: b.id } });
    expect(other!.status).toBe('REJECTED');
    expect(other!.rejectionReason).toContain(a.id);

    const after = await prisma.subscription.findUnique({
      where: { id: subscriptionId },
    });
    const days =
      (after!.currentPeriodEnd.getTime() - before!.currentPeriodEnd.getTime()) /
      86400000;
    // THIRTY, not sixty. The status change alone would not catch a double
    // extension — this assertion is the one that matters.
    expect(Math.round(days)).toBe(30);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Expected: the first fails with `BUSINESS` (the regex still wins); the third fails because the other payment is still `PENDING`. The second may already pass — the regex misses the Russian note today, which is the bug being made explicit rather than a behaviour change.

- [ ] **Step 3: Write the implementation**

Replace lines 392-398 (the `let newPlan` block and its regex) with:

```ts
    // From the column, not from the note. The regex this replaces silently
    // left the plan unchanged whenever it failed to match — which it does for
    // every manual payment, since the admin writes that note freely.
    // A null requestedPlan means extend the period and leave the plan alone.
    const newPlan = payment.requestedPlan ?? subscription.plan;
```

And add the supersede step inside the existing `$transaction` array, after the subscription update:

```ts
        this.prisma.payment.updateMany({
          where: {
            subscriptionId,
            status: 'PENDING',
            id: { not: paymentId },
          },
          data: {
            status: 'REJECTED',
            reviewedAt: now,
            reviewedBy,
            rejectionReason: `Superseded by approved payment ${paymentId}`,
          },
        }),
```

Destructure only the first two results so the added statement does not break the existing `const [updatedPayment, updatedSubscription] =` binding — it already takes the first two of what is now three.

Also rename the bare `30` at line 406 to a named constant beside it:

```ts
    // Plans are sold monthly. adminCreateManualPayment takes periodDays from
    // the admin instead, deliberately — that path exists for non-standard
    // grants, and the difference between the two is intentional, not a bug.
    const planPeriodDays = 30;
    newPeriodEnd.setDate(newPeriodEnd.getDate() + planPeriodDays);
```

- [ ] **Step 4: Run everything**

```bash
cd api
npx jest --config test/jest-e2e.json payment-integrity
npx jest src/modules/subscriptions
npx tsc --noEmit ; echo "tsc exit=$?"
```
Expected: all six e2e pass, unit specs pass, `tsc exit=0`.

**Existing approve specs will need their fakes updated** — `payment.updateMany` must exist on the fake Prisma, and fixtures that relied on the note-regex to change the plan now need `requestedPlan` instead. Updating them is correct; say which and why. Do **not** keep the regex to satisfy a stale fixture.

- [ ] **Step 5: Prove the supersede guard bites**

```bash
cd api
cp src/modules/subscriptions/subscriptions.service.ts /tmp/svc2.keep
perl -0pi -e 's/this\.prisma\.payment\.updateMany\(\{.*?\}\),\n//s' src/modules/subscriptions/subscriptions.service.ts
npx jest --config test/jest-e2e.json payment-integrity 2>&1 | grep -E "✕|✓"
cp /tmp/svc2.keep src/modules/subscriptions/subscriptions.service.ts ; rm -f /tmp/svc2.keep
git status --short
```
Expected: only "should reject the other pending payments" fails; clean tree after.

- [ ] **Step 6: Commit.**

---

## Task 4: Live check and gates

- [ ] **Step 1: Build and restart, then confirm the duplicate guard live**

```bash
cd api && npm run build && test -f dist/main.js && echo "artifact ok"
```
Restart the API. Then, logging in **once** (the throttle is 100 requests/60s including logins):

```bash
cd /private/tmp/claude-501/-Users-latifrjdev-Downloads-01---------Dukon/55ece40c-480e-4a15-add5-e8850af836f3/scratchpad
curl -s -X POST http://localhost:4455/api/auth/login -H 'Content-Type: application/json' \
  -d '{"phone":"+992920777001","password":"x8R9s5msWiEzBYWL"}' \
  | python3 -c "import json,sys;print(json.load(sys.stdin)['accessToken'])" > token.txt
T=$(cat token.txt); S=ccb89fc3-95e9-47d0-9437-8c1079cbc4c2
for i in 1 2; do
  curl -s -o /dev/null -w "attempt $i: HTTP %{http_code}\n" -X POST \
    "http://localhost:4455/api/stores/$S/subscription/request-change" \
    -H "Authorization: Bearer $T" -H 'Content-Type: application/json' \
    -d '{"plan":"PREMIUM","paymentMethod":"CASH"}'
done
```
Expected: `attempt 1: HTTP 201`, `attempt 2: HTTP 409`.

- [ ] **Step 2: Clean up what the live check created**

```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "DELETE FROM payments p USING subscriptions s
    WHERE p.\"subscriptionId\"=s.id AND s.\"storeId\"='ccb89fc3-95e9-47d0-9437-8c1079cbc4c2'
      AND p.status='PENDING';"
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "SELECT sub.plan, sub.status, sub.\"adminDiscount\",
          (SELECT count(*) FROM payments p WHERE p.\"subscriptionId\"=sub.id) AS payments
     FROM subscriptions sub WHERE sub.\"storeId\"='ccb89fc3-95e9-47d0-9437-8c1079cbc4c2';"
```
Expected baseline: `BUSINESS | ACTIVE | (empty) | 1`. This is the shared dev database — it must end as it started.

- [ ] **Step 3: Full gates**

```bash
cd api && npm test && npx tsc --noEmit ; echo "tsc exit=$?"
```
Expected: all green, `tsc exit=0`.

No Flutter run is needed — this branch changes no file under `app/`. Verify that: `git diff --name-only fix/plan-config-single-source...HEAD -- app/` must be empty.

- [ ] **Step 4:** Proceed to superpowers:finishing-a-development-branch.
