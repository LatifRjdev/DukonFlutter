# Subscription: receipt upload, PAST_DUE, and a dead limit field

**Date:** 2026-10-06
**Branch:** `fix/subscription-receipt-and-past-due`
**Scope:** three defects left open by the review of PR #85, all in the subscription
screen and its bloc.

This is a repair spec, not a feature spec. Real card acquiring — DC, Alif,
Visa/Mastercard — is a separate project, blocked on an acquirer contract and on a
deployed backend (see "Relationship to card payments" at the end). The manual
receipt flow stays as the fallback either way, so fixing it is worth doing on its
own terms.

---

## 1. The card-with-receipt path cannot work

### Symptom

A merchant picks a plan, chooses to pay by card, photographs the receipt, and
submits. The screen shows an error. Nothing is recorded — not the receipt, and not
even the plan-change request. The admin panel shows no new request, so there is
nothing for anyone to approve. The merchant's only working option today is "pay
cash", which is a different claim about how they paid.

### Cause

`_onReceiptUploaded` ([subscription_bloc.dart:55-91](app/lib/presentation/blocs/subscription/subscription_bloc.dart#L55-L91))
disagrees with the route in three independent ways:

| | Bloc sends | Route expects |
|---|---|---|
| Path | `/subscription/upload-receipt` | `/subscription/upload-receipt/:paymentId` |
| Multipart field | `receipt` | `file` |
| Order | upload, *then* `request-change` | the `paymentId` must exist first |

The third is the structural one. `paymentId` identifies the `Payment` row the
receipt attaches to, and that row is created by `request-change`
([subscriptions.service.ts:227-262](api/src/modules/subscriptions/subscriptions.service.ts#L227-L262)) —
which the bloc calls *after* the upload, and whose response it discards. So there
is no id to send, and the upload 404s before `request-change` ever runs.

The handler is not a variant of `_onPlanChangeRequested` with an extra step; it is
`_onPlanChangeRequested` with its two steps in the wrong order.

### Why the tests are green

Both existing tests
([subscription_bloc_test.dart:348-413](app/test/presentation/blocs/subscription/subscription_bloc_test.dart#L348-L413))
stub `dioClient.post` against the literal string
`'/stores/store-1/subscription/upload-receipt'` and then `verify` the same string.
They assert that the bloc calls the path the bloc calls. A test written from the
implementation cannot find a disagreement between the implementation and the
server; this one is structurally incapable of it. The same is true of the field
name, which `any(named: 'data')` never inspects, and of the ordering, which
`verify(...).called(1)` does not constrain.

This is the pattern recorded in memory as the project's dominant defect class, with
the test-fixture corollary: *a test that was green through the bug encodes the wrong
contract.*

### Fix

Reverse the order and thread the id through:

1. `POST request-change` with `{plan, paymentMethod}`. Keep the response.
2. Read `id` from it. `requestChange` returns the whole `Payment` row, so the id is
   `response.data['id'] as String?`.
3. `POST upload-receipt/$paymentId` with a `FormData` whose single field is named
   `file`.

If step 2 yields no id — a response shape we did not expect — stop and emit an
error rather than building a URL ending in `/null`.

### Partial failure

Reversing the order creates a state the old code could not reach: the request
exists and the receipt does not. This is not a reason to avoid the reversal — it is
strictly better than today's "neither exists" — but the merchant has to be told the
truth about it, for a specific reason. `requestChange` does not check for an
existing PENDING payment, so a merchant who reads "ошибка" and submits again
creates a *second* pending request for the same plan. Reporting a flat failure would
actively cause that.

So the upload failing after the request succeeded emits
`SubscriptionActionSuccess` with its own message — the request was sent, the
receipt did not attach — and still dispatches the reload, so the pending-payment
banner appears and the merchant can see their request exists. New ARB key
`subscriptionRequestSentWithoutReceipt`, Russian value:
*"Заявка отправлена, но чек не загрузился. Свяжитесь с поддержкой."*

It directs them to support rather than to a retry because there is no UI for
attaching a receipt to an existing payment, and inventing one is out of scope here.

If `request-change` itself fails, nothing was created and the existing
`SubscriptionError` behaviour is correct and unchanged.

### Tests

Replace both existing tests. The new ones have to be able to fail on the real
defect, which means asserting things the old ones never looked at:

- **Ordering and the id.** One `when` for `post` matching `any()`, recording
  `(path, data)` in a list. Assert the recorded paths are, in order,
  `/stores/store-1/subscription/request-change` then
  `/stores/store-1/subscription/upload-receipt/pay-7`, where `pay-7` is the `id`
  the stubbed `request-change` returned. This fails on the current code three
  times over: wrong order, missing id, wrong path.
- **The multipart field name.** Assert the captured `FormData`'s `files` contains
  exactly one entry whose key is `file`. Mocktail's `any(named: 'data')` is what
  hid this; the assertion has to reach into the object.
- **Upload failure after a successful request.** Stub `request-change` to succeed
  and `upload-receipt/...` to throw; expect
  `[Uploading, ActionSuccess(subscriptionRequestSentWithoutReceipt), Loading, Loaded]`.
- **Request failure.** Stub `request-change` to throw; expect
  `[Uploading, Error]` and `verifyNever` any upload.
- **Missing id in the response.** Stub `request-change` to return `{}`; expect
  `[Uploading, Error]` and no upload call.

Keep the existing `wait: const Duration(milliseconds: 200)` and the comment
explaining it — the handler still does real file I/O before reaching the mock, and
that comment records a CI flake that was diagnosed once already.

Each test is verified by reverting the bloc change and confirming it fails for the
stated reason, not merely that it fails.

### Device verification

A passing unit test is not evidence here, because the previous unit tests passed.
On the emulator, as a merchant: pick a plan, pay by card, attach a photo, submit.
Then confirm in the admin panel that the request is listed **and** that the receipt
image opens. Both halves — the earlier lesson was that confirming one element of a
row is not confirming the row.

---

## 2. `PAST_DUE` is unhandled

### Symptom

A merchant whose subscription has lapsed into `PAST_DUE` sees a full-colour,
healthy-looking plan card with a grey badge reading `PAST_DUE` in Latin capitals,
while the backend refuses every gated feature. The screen that exists to explain
their subscription tells them nothing is wrong.

### Cause

Three independent catch-alls, all in agreement by accident:

- `isExpired => status == 'EXPIRED' || status == 'CANCELLED'` and
  `isActive => status == 'ACTIVE' || status == 'TRIAL'`
  ([subscription_state.dart:203-204](app/lib/presentation/blocs/subscription/subscription_state.dart#L203-L204)).
  Two hand-maintained lists over a five-value enum, so `PAST_DUE` is in neither.
  The card's gradient is chosen by `isExpired` and therefore reads as healthy.
- `_statusColor`'s `default:` returns `textMuted`
  ([subscription_page.dart:109-122](app/lib/presentation/pages/settings/subscription_page.dart#L109-L122)).
- `_statusLabel`'s `default:` returns the raw `status` string
  ([subscription_page.dart:124-137](app/lib/presentation/pages/settings/subscription_page.dart#L124-L137)) —
  which is how an untranslated enum name reaches a merchant's screen.

`PAST_DUE` appears nowhere in `app/`. The server, by contrast, is explicit: the
documented gate in
[feature-flag.helper.ts](api/src/common/guards/feature-flag.helper.ts) is
`ACTIVE`/`TRIAL` allowed, everything else denied, and the comment names
`PAST_DUE/CANCELLED/EXPIRED` together as "lapsed".

### Fix

The same treatment `PaymentStatus` already received in this codebase, applied to
the enum one layer up. Two precedents to mirror exactly:
[payment_status.dart](app/lib/presentation/pages/settings/payment_status.dart) and
[admin/lib/subscription-status.ts](admin/lib/subscription-status.ts).

New file `app/lib/presentation/pages/settings/subscription_status.dart`:

```dart
enum SubscriptionStatusKind { active, trial, pastDue, cancelled, expired, unknown }

SubscriptionStatusKind subscriptionStatusKind(String status) => switch (status) {
      'ACTIVE' => SubscriptionStatusKind.active,
      'TRIAL' => SubscriptionStatusKind.trial,
      'PAST_DUE' => SubscriptionStatusKind.pastDue,
      'CANCELLED' => SubscriptionStatusKind.cancelled,
      'EXPIRED' => SubscriptionStatusKind.expired,
      _ => SubscriptionStatusKind.unknown,
    };
```

Then:

- `isActive` becomes `kind == active || kind == trial` — the server's gate, stated
  once.
- `isExpired` becomes **`!isActive`**, not a second list. Anything the server will
  refuse must look refused. `unknown` lands on the pessimistic side deliberately: a
  status we do not recognise is one we cannot promise is working, and the grey card
  under-promises where the colour card over-promises.
- `_statusColor` and `_statusLabel` switch on the kind with no `default:`, so the
  compiler refuses a new enum member without a decision. `pastDue` gets
  `AppColors.error` — it is a problem the merchant must act on, not a neutral state
  like `cancelled`.
- Two new ARB keys: `subscriptionPastDueStatus` = *"Просрочена"*, and
  `subscriptionUnknownStatus` = *"Статус неизвестен"* for the `unknown` kind, so no
  code path can print a raw enum name again. Both get `@` descriptions, since
  `subscriptionUnknownStatus` is a near-duplicate of the existing
  `subscriptionPaymentUnknownStatus` (same value, different enum) and the ARB
  convention is to say how near-duplicates differ.

### Tests

`app/test/presentation/pages/settings/subscription_status_test.dart`, modelled on
`payment_status_test.dart` including its schema-parsing completeness test — reading
`enum SubscriptionStatus` out of `api/prisma/schema.prisma` so the build, not a
person's memory, catches the next added value.

Plus, in the bloc test: `PAST_DUE` is not `isActive` **and** is `isExpired`. Both
directions, pinned exactly. Asserting only `isActive == false` would have passed on
the current code and is exactly the half-assertion that let this through.

---

## 3. `limits.maxStores` is a key the API stopped sending

`SubscriptionLimits.fromJson` reads `maxStores` with a `?? 1` fallback
([subscription_state.dart:8-36](app/lib/presentation/blocs/subscription/subscription_state.dart#L8-L36)).
The column was removed from `SubscriptionPlanConfig` in 2026-05, and
[plan-limit.helper.ts:4-8](api/src/common/guards/plan-limit.helper.ts#L4-L8)
records why: each store carries its own subscription, so a per-merchant store cap
had no architectural anchor and was never enforced. The endpoint sends
`maxProducts`, `maxStaff`, `maxDiscounts` and nothing else.

Nothing renders it, so there is no visible defect — but seven test references assert or supply it,
and they are what would make the next person believe the field is real.

Remove the field, the constructor argument, the `fromJson` line and the `props`
entry, plus:

- the `'maxStores': 3` line in the `fullData` fixture
  ([:53](app/test/presentation/blocs/subscription/subscription_bloc_test.dart#L53))
- three `.having((s) => s.limits.maxStores, …)` assertions
  ([:108](app/test/presentation/blocs/subscription/subscription_bloc_test.dart#L108),
  [:138](app/test/presentation/blocs/subscription/subscription_bloc_test.dart#L138),
  [:164](app/test/presentation/blocs/subscription/subscription_bloc_test.dart#L164))
- the `maxStores: 3` constructor arguments in
  [subscription_page_golden_test.dart:25](app/test/presentation/pages/settings/subscription_page_golden_test.dart#L25)
  and
  [settings_page_golden_test.dart:41](app/test/presentation/pages/settings/settings_page_golden_test.dart#L41)

One of those sites is **not** deleted. The test at
[:148-167](app/test/presentation/blocs/subscription/subscription_bloc_test.dart#L148-L167),
*"should treat maxStores of -1 as unlimited without special-casing it away"*, names
a dead field but covers a live convention: `-1` means unlimited on PREMIUM, and
that is still true of `maxProducts`, `maxStaff` and `maxDiscounts`. It is renamed
to *"should treat a limit of -1 as unlimited without special-casing it away"* and
re-pointed at the surviving fields. Deleting it would quietly drop real coverage
along with the dead field — the mirror image of the mistake being fixed.

This is the fourth instance of the same class as items 1 and 2; removing it keeps
the count honest.

Golden fixtures are edited to drop the argument only. **No goldens are regenerated**
— 18 fail on macOS as a documented baseline, and regenerating would bake local
rendering into the repo.

---

## Verification gates

Unchanged from the project's standing set:

- `flutter analyze` clean
- `flutter test` — the failing **set** identical to the 18 documented macOS
  goldens, compared as a set and not as a count
- `dart run tool/check_i18n.dart` exits 0
- `flutter gen-l10n`, then review `l10n_untranslated.json` — the three new keys are
  expected to appear in the tg/uz backlog, which is a tracked artifact
- `api`: `npm test` green, `npx tsc --noEmit` zero errors

Hard constraints: no `dart format` (Dart 3.10 tall style rewrites the repo); no
golden regeneration; no hand-editing `app_localizations*.dart`; no Prisma schema
change. Items 1–3 need no API change at all — every route and column they depend on
already exists.

---

## Relationship to card payments

The flow fixed in item 1 is named "card" but is not card acquiring: it means *the
merchant paid somewhere else and is submitting proof*. No money moves through the
system, and an admin still approves by hand. It is document handling.

Real acquiring is a separate spec with two external prerequisites neither this spec
nor any amount of code can satisfy: an acquirer contract, and a publicly reachable
backend for the provider's webhook to call — `deploy.yml` currently builds only the
Android and iOS releases, and nothing deploys the API's Dockerfile. The second
prerequisite blocks far more than payments.

Fixing the manual flow is therefore not a step toward acquiring, and does not
become wasted work when acquiring arrives: the fallback path for merchants who pay
by transfer or cash is needed regardless.
