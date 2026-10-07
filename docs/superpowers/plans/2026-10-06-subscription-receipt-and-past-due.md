# Subscription Receipt, PAST_DUE, and Dead Limit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair three defects on the subscription screen: the card-with-receipt flow that records nothing, the `PAST_DUE` status that renders as healthy, and a limit field the API stopped sending in May.

**Architecture:** All changes are client-side; no API route, DTO, or Prisma change. Item 1 reverses two HTTP calls inside one bloc handler so the `paymentId` the upload needs exists before the upload. Item 2 extracts the subscription-status vocabulary into its own module with an exhaustive, `default`-free mapping, mirroring `payment_status.dart`, and derives `isActive`/`isExpired` from it. Item 3 deletes a dead field and its seven test references.

**Tech Stack:** Flutter 3.x / Dart 3.10, `flutter_bloc`, `dio` (multipart), `equatable`, `bloc_test` + `mocktail`, `flutter gen-l10n` ARB localization.

**Spec:** `docs/superpowers/specs/2026-10-06-subscription-receipt-and-past-due-design.md`

**Worktree:** `/Users/latifrjdev/Downloads/01_Проекты/Dukon/.worktrees/subscription-gaps`, branch `fix/subscription-receipt-and-past-due`, based on `main` at `4a66e07`.

---

## Environment notes

Run every `flutter`/`dart` command from the `app/` subdirectory of the worktree. Run `npm` from `api/`.

**The emulator and API are shared with the main checkout** — there is one Android emulator (`emulator-5554`) and one API on `:4455`. The API serves from compiled `dist/`, so no API change is needed here and **the API does not need rebuilding for this plan**.

QA logins (both on `+992` numbers, as the project requires):
- `+992920777001` / `x8R9s5msWiEzBYWL` — BUSINESS
- `+992920777002` / `yfgYAi5oHqm38w8x` — PREMIUM

Postgres: container `dukonpro-db` on `:5435`, `psql -U dukonpro -d dukonpro`.

**Rate limit trap:** `THROTTLE_LIMIT=100` per 60s **including logins**. Log in once and reuse the token; logging in per curl call trips the throttle and the resulting 401s look like auth bugs.

**Line numbers in this plan are from `eaa2d6b`**, the formatting commit already on this branch — **not** from `main`. They are a locating aid only: Tasks 1 and 3 both edit `subscription_bloc_test.dart` before Task 5 does, so by Task 5 every number below their edits has shifted. **Always match on the quoted content, never on the line number alone.** If the content at a cited line is not what this plan quotes, search for the content.

**The pre-commit hook is already satisfied and must stay that way.** `lefthook` runs `dart format --set-exit-if-changed` on staged Dart files, and on Dart 3.10 the formatter rewrites this repo's older files wholesale. Commit `eaa2d6b` reformatted the nine files this branch touches, in isolation, so every commit below passes the hook honestly. Two consequences:

- **Write new and edited Dart in the formatter's style**, so `dart format --set-exit-if-changed` stays clean. After editing a Dart file, check with `dart format --output=none --set-exit-if-changed <file>` and fix by hand if it complains. Running `dart format` on **a file this branch already touches** is now safe — it is a no-op. Running it on any **other** file is still forbidden.
- **Never bypass the hook.** A `block-no-verify` guard rejects the flag, and that guard is the newer and more explicit instruction. If a commit is rejected, fix what it reports.

**A `Read`-tool hook in this repo truncates files that have prior observations to line 1.** Use `awk '{print NR": "$0}' <path>` to read, or `Read` with a narrow `offset`/`limit` and check you got what you asked for. Three subagents have stalled on this.

**`sed -i` here is BSD sed.** It does not expand `\n` in a replacement and does not support `\b`. The verification steps below use `perl -pi -e` where a newline is needed; do not "simplify" them back to `sed`.

## Hard constraints

- **Never run `dart format` on a file outside this branch's set.** Dart 3.10's tall style rewrites 385+ lines per file. The nine files already reformatted in `eaa2d6b` are listed in that commit; those are safe and any other file is not.
- **Never regenerate goldens.** 18 fail on macOS as a documented baseline; regenerating bakes local font rendering into the repo.
- **Never hand-edit `app/lib/l10n/app_localizations*.dart`.** They come from `flutter gen-l10n`.
- **Do not touch `api/prisma/schema.prisma`** or any API source. This plan is client-only.
- Only edit `app_ru.arb`. `app_tg.arb` / `app_uz.arb` are translated separately; new keys are expected to land in the `l10n_untranslated.json` backlog.

## File structure

| File | Responsibility | Change |
|---|---|---|
| `app/lib/presentation/pages/settings/subscription_status.dart` | The `SubscriptionStatus` vocabulary: one enum, one total mapping. No Flutter imports, so the bloc can use it. | **Create** |
| `app/test/presentation/pages/settings/subscription_status_test.dart` | Pins each mapping and reads `enum SubscriptionStatus` out of `schema.prisma` for completeness. | **Create** |
| `app/lib/presentation/blocs/subscription/subscription_state.dart` | `isActive`/`isExpired` derive from the kind; `maxStores` removed. | Modify |
| `app/lib/presentation/blocs/subscription/subscription_bloc.dart` | `_onReceiptUploaded` ordering, path, and multipart field name. | Modify |
| `app/lib/presentation/pages/settings/subscription_page.dart` | `_statusColor`/`_statusLabel` switch on the kind with no `default`. | Modify |
| `app/lib/core/errors/app_message.dart` | New member `subscriptionRequestSentWithoutReceipt`. | Modify |
| `app/lib/presentation/l10n/app_message_l10n.dart` | Its resolver arm (no `default`, so this is mandatory to compile). | Modify |
| `app/lib/l10n/app_ru.arb` | Three new keys in the `subscription*` block. | Modify |
| `app/test/presentation/blocs/subscription/subscription_bloc_test.dart` | Receipt-flow tests rewritten; `PAST_DUE` added; `maxStores` sites removed. | Modify |
| `app/test/presentation/pages/settings/subscription_page_golden_test.dart` | Drop `maxStores:` argument. | Modify |
| `app/test/presentation/pages/settings/settings_page_golden_test.dart` | Drop `maxStores:` argument. | Modify |

`subscription_status.dart` sits beside `payment_status.dart` in `pages/settings/` rather than under `blocs/` because that is where its sibling already lives and the bloc already imports across that boundary (`subscription_bloc.dart:7`). Follow the established placement; do not relocate `payment_status.dart`.

---

## Task 1: Remove the dead `maxStores` limit

`SubscriptionLimits` reads `maxStores`, which `SubscriptionPlanConfig` has not had since 2026-05 — see the comment at `api/src/common/guards/plan-limit.helper.ts:4-8` explaining that a per-merchant store cap had no architectural anchor. The endpoint sends only `maxProducts`, `maxStaff`, `maxDiscounts`. Nothing renders `maxStores`; seven test references keep it looking real — three `.having` assertions and four fixture literals. Counted, not recalled.

Deletions cannot be driven by a new failing test, so the guard here is different: edit the tests first so they stop asserting the dead contract, confirm green, then remove the field and confirm `flutter analyze` finds no surviving reference.

**Files:**
- Modify: `app/test/presentation/blocs/subscription/subscription_bloc_test.dart:53,113,154,168-188`
- Modify: `app/test/presentation/pages/settings/subscription_page_golden_test.dart:25`
- Modify: `app/test/presentation/pages/settings/settings_page_golden_test.dart:41`
- Modify: `app/lib/presentation/blocs/subscription/subscription_state.dart:7-37`

- [ ] **Step 1: Re-point the `-1 = unlimited` test instead of deleting it**

This test names a dead field but covers a live convention: `-1` means unlimited on PREMIUM, still true of the three surviving limits. Deleting it would drop real coverage along with the dead field.

In `app/test/presentation/blocs/subscription/subscription_bloc_test.dart`, replace lines 168-188 with:

```dart
      blocTest<SubscriptionBloc, SubscriptionState>(
        'should treat a limit of -1 as unlimited without special-casing it away',
        setUp: () => mockGet(<String, dynamic>{
          'plan': 'PREMIUM',
          'limits': {
            'maxProducts': -1,
            'maxStaff': -1,
            'maxDiscounts': -1,
          },
        }),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>()
              .having((s) => s.limits.maxProducts, 'limits.maxProducts', -1)
              .having((s) => s.limits.maxStaff, 'limits.maxStaff', -1)
              .having((s) => s.limits.maxDiscounts, 'limits.maxDiscounts', -1),
        ],
      );
```

- [ ] **Step 2: Remove the remaining `maxStores` test sites**

In the same file, delete line 53 (`'maxStores': 3,` inside the `fullData` fixture), line 113 (`.having((s) => s.limits.maxStores, 'limits.maxStores', 3)`), and line 154 (`.having((s) => s.limits.maxStores, 'limits.maxStores', 1)`).

In `app/test/presentation/pages/settings/subscription_page_golden_test.dart`, delete line 25 (`maxStores: 3,`).

In `app/test/presentation/pages/settings/settings_page_golden_test.dart`, delete line 41 (`maxStores: 3,`).

Delete **only** those argument/assertion lines. Do not regenerate goldens and do not change any other fixture value — the golden images depend on every other field.

- [ ] **Step 3: Run the bloc tests — they must pass before the field is removed**

Run from `app/`:
```bash
flutter test test/presentation/blocs/subscription/subscription_bloc_test.dart
```
Expected: all pass. They now assert nothing about `maxStores` while the field still exists, which is the point — green here proves the assertions were the only thing holding it.

- [ ] **Step 4: Remove the field from the model**

In `app/lib/presentation/blocs/subscription/subscription_state.dart`, replace lines 7-37 with:

```dart
// `maxStores` was removed here in 2026-10: the column was dropped from
// SubscriptionPlanConfig in 2026-05 (see api/src/common/guards/plan-limit.helper.ts)
// because each store carries its own subscription, so a per-merchant store cap
// had no architectural anchor. This class kept reading it with a `?? 1`
// fallback, and three test fixtures asserted it — the shape that makes the next
// reader believe a field is real.
class SubscriptionLimits extends Equatable {
  final int maxProducts;
  final int maxStaff;
  final int maxDiscounts;

  const SubscriptionLimits({
    required this.maxProducts,
    required this.maxStaff,
    required this.maxDiscounts,
  });

  factory SubscriptionLimits.fromJson(Map<String, dynamic> json) =>
      SubscriptionLimits(
        maxProducts: (json['maxProducts'] as num?)?.toInt() ?? 500,
        maxStaff: (json['maxStaff'] as num?)?.toInt() ?? 2,
        maxDiscounts: (json['maxDiscounts'] as num?)?.toInt() ?? 0,
      );

  factory SubscriptionLimits.defaults() => const SubscriptionLimits(
        maxProducts: 500,
        maxStaff: 2,
        maxDiscounts: 0,
      );

  @override
  List<Object?> get props => [maxProducts, maxStaff, maxDiscounts];
}
```

- [ ] **Step 5: Verify no reference survives**

Run from `app/`:
```bash
grep -rn maxStores lib test
```
Expected: **exactly one** hit — the explanatory comment Step 4 itself adds at the top of `SubscriptionLimits`. Anything else is a site Step 2 missed.

(An earlier draft of this step expected zero hits, which contradicted Step 4's own comment text. The comment is the point of the change and stays; the grep is a sweep for *code and fixture* references, not for the word.)

```bash
flutter analyze
```
Expected: `No issues found!`

```bash
flutter test test/presentation/blocs/subscription/subscription_bloc_test.dart
```
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/.worktrees/subscription-gaps
git add app/lib/presentation/blocs/subscription/subscription_state.dart \
        app/test/presentation/blocs/subscription/subscription_bloc_test.dart \
        app/test/presentation/pages/settings/subscription_page_golden_test.dart \
        app/test/presentation/pages/settings/settings_page_golden_test.dart
git commit --file - <<'MSG'
fix(app): drop limits.maxStores, a key the API stopped sending in May

The column was removed from SubscriptionPlanConfig in 2026-05 because each
store carries its own subscription, so a per-merchant cap had no anchor and was
never enforced. The endpoint sends maxProducts/maxStaff/maxDiscounts; this
model kept reading maxStores behind a `?? 1` fallback, so it silently read as 1
forever. Nothing rendered it, so there was no visible defect — but seven test
sites asserted it, which is what would make the next reader believe it is real.

One of those sites is kept rather than deleted. "should treat maxStores of -1
as unlimited" names the dead field but covers a live convention: -1 still means
unlimited for the three surviving limits. It is renamed and re-pointed at them.
Deleting it would have dropped real coverage along with the dead field.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
```

---

## Task 2: The `SubscriptionStatus` vocabulary module

`PAST_DUE` appears nowhere in `app/`. The server is explicit — `api/src/common/guards/feature-flag.helper.ts` documents the gate as `ACTIVE`/`TRIAL` allowed, everything else denied, naming `PAST_DUE/CANCELLED/EXPIRED` together as lapsed. The client instead has three independent catch-alls that happen to agree.

This task creates the vocabulary only. Tasks 3 and 4 consume it.

**Files:**
- Create: `app/lib/presentation/pages/settings/subscription_status.dart`
- Create: `app/test/presentation/pages/settings/subscription_status_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/presentation/pages/settings/subscription_status_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/presentation/pages/settings/subscription_status.dart';

// Guards the defect this file was extracted for: PAST_DUE appeared nowhere in
// the app. It was in neither of subscription_state's two hand-kept lists, so a
// lapsed merchant got a full-colour plan card, and it fell through the page's
// two `default:` branches, so the badge printed the raw enum name in Latin
// capitals while the server refused every gated feature.
void main() {
  test('should recognise PAST_DUE rather than falling through to unknown', () {
    expect(subscriptionStatusKind('PAST_DUE'), SubscriptionStatusKind.pastDue);
  });

  test('should treat ACTIVE as a working subscription', () {
    expect(subscriptionStatusKind('ACTIVE'), SubscriptionStatusKind.active);
  });

  test('should treat TRIAL as a working subscription', () {
    expect(subscriptionStatusKind('TRIAL'), SubscriptionStatusKind.trial);
  });

  test('should keep TRIAL distinct from ACTIVE', () {
    // Both are allowed by the server, but the card renders them differently —
    // TRIAL carries a countdown and ACTIVE carries an expiry date. Collapsing
    // them into one kind would lose that.
    expect(subscriptionStatusKind('TRIAL'),
        isNot(subscriptionStatusKind('ACTIVE')));
  });

  test('should treat CANCELLED as its own end state', () {
    expect(
        subscriptionStatusKind('CANCELLED'), SubscriptionStatusKind.cancelled);
  });

  test('should treat EXPIRED as its own end state', () {
    // Pinned exactly rather than as "not active". CANCELLED is a decision the
    // merchant made and EXPIRED is one that happened to them; the page gives
    // them different colours, so one kind over both would be wrong.
    expect(subscriptionStatusKind('EXPIRED'), SubscriptionStatusKind.expired);
  });

  test('should not fold an unrecognised status into a working one', () {
    expect(subscriptionStatusKind('SOMETHING_NEW'),
        SubscriptionStatusKind.unknown);
  });

  test('should cover every SubscriptionStatus the schema actually defines', () {
    // Reads the schema rather than restating it. A hardcoded list is where
    // someone would have to REMEMBER to add a value; this is where the build
    // tells them. Mirrors payment_status_test.dart and the admin's
    // subscription-status test, both of which parse the same file.
    final schema = File('../api/prisma/schema.prisma').readAsStringSync();
    final block =
        RegExp(r'^enum SubscriptionStatus\s*\{([^}]*)\}', multiLine: true)
            .firstMatch(schema);
    expect(block, isNotNull,
        reason: 'SubscriptionStatus not found in schema.prisma');

    final fromSchema = block!
        .group(1)!
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'//.*$'), '').trim())
        .where((l) => l.isNotEmpty);

    for (final status in fromSchema) {
      expect(subscriptionStatusKind(status),
          isNot(SubscriptionStatusKind.unknown),
          reason: '$status has no deliberate mapping');
    }
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run from `app/`:
```bash
flutter test test/presentation/pages/settings/subscription_status_test.dart
```
Expected: FAIL at compile — `Error: Couldn't resolve the package 'dukonpro/presentation/pages/settings/subscription_status.dart'` or `Undefined name 'SubscriptionStatusKind'`. It must fail for a missing file, not a failed assertion.

- [ ] **Step 3: Create the module**

Create `app/lib/presentation/pages/settings/subscription_status.dart`:

```dart
/// What a subscription's status means, as a value rather than a string.
///
/// Mirrors `enum SubscriptionStatus` in `api/prisma/schema.prisma`. `PAST_DUE`
/// used to appear nowhere in this app: `subscription_state.dart` kept two
/// hand-written lists (`isActive` = ACTIVE|TRIAL, `isExpired` =
/// EXPIRED|CANCELLED) over a five-value enum, so a lapsed merchant was in
/// neither and got a full-colour, healthy-looking plan card; and the page's
/// `_statusLabel` had a `default:` returning the raw status, so the badge
/// printed `PAST_DUE` in Latin capitals.
///
/// The server has no such ambiguity — `api/src/common/guards/feature-flag.helper.ts`
/// documents the gate as ACTIVE/TRIAL allowed, everything else denied, and
/// names PAST_DUE/CANCELLED/EXPIRED together as lapsed. This enum exists so the
/// client states that rule once instead of in three places that agree by
/// coincidence.
///
/// Deliberately free of Flutter imports: the bloc's state objects depend on it.
enum SubscriptionStatusKind {
  active,

  /// Allowed by the server exactly like [active], but kept separate because the
  /// plan card renders a trial countdown where a paid plan renders an expiry
  /// date.
  trial,

  /// Lapsed and billable: the server refuses every gated feature. Treated as a
  /// problem the merchant must act on, not a neutral end state — which is why
  /// it takes the error colour rather than the muted one [cancelled] gets.
  pastDue,

  /// The merchant's own decision.
  cancelled,

  /// Ran out without being renewed.
  expired,

  /// A status the schema has gained and this file has not. Must stay on the
  /// pessimistic side of `isActive`: a status we cannot recognise is one we
  /// cannot promise is working, and a grey card that under-promises beats a
  /// colour card that over-promises.
  unknown,
}

SubscriptionStatusKind subscriptionStatusKind(String status) =>
    switch (status) {
      'ACTIVE' => SubscriptionStatusKind.active,
      'TRIAL' => SubscriptionStatusKind.trial,
      'PAST_DUE' => SubscriptionStatusKind.pastDue,
      'CANCELLED' => SubscriptionStatusKind.cancelled,
      'EXPIRED' => SubscriptionStatusKind.expired,
      _ => SubscriptionStatusKind.unknown,
    };
```

- [ ] **Step 4: Run the test to verify it passes**

Run from `app/`:
```bash
flutter test test/presentation/pages/settings/subscription_status_test.dart
```
Expected: `+8: All tests passed!`

- [ ] **Step 5: Verify the schema test can actually fail**

The completeness test is the one that matters most and the one most likely to be vacuous — if the regex misses, `fromSchema` is empty and the loop asserts nothing. Prove it bites:

```bash
sed -i.bak "s/'PAST_DUE' => SubscriptionStatusKind.pastDue,//" lib/presentation/pages/settings/subscription_status.dart
flutter test test/presentation/pages/settings/subscription_status_test.dart
```
Expected: **two** failures — the explicit `PAST_DUE` test, and `should cover every SubscriptionStatus the schema actually defines` reporting `PAST_DUE has no deliberate mapping`. If only the first fails, the regex is not matching the schema and must be fixed before continuing.

Restore:
```bash
mv lib/presentation/pages/settings/subscription_status.dart.bak lib/presentation/pages/settings/subscription_status.dart
flutter test test/presentation/pages/settings/subscription_status_test.dart
```
Expected: back to `+8: All tests passed!`

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/.worktrees/subscription-gaps
git add app/lib/presentation/pages/settings/subscription_status.dart \
        app/test/presentation/pages/settings/subscription_status_test.dart
git commit --file - <<'MSG'
feat(app): a single SubscriptionStatus vocabulary, checked against the schema

PAST_DUE appeared nowhere in the app. The client described a five-value enum
with three independent catch-alls that agreed by coincidence, and the server
describes it once: feature-flag.helper.ts documents ACTIVE/TRIAL as allowed and
names PAST_DUE/CANCELLED/EXPIRED together as lapsed.

This states that rule once, the way PaymentStatus was already handled in this
repo, including the completeness test that parses the enum out of
schema.prisma — so the next value added server-side fails the build rather than
waiting for someone to remember.

`unknown` is kept as its own kind and will sit on the pessimistic side of
isActive. Folding an unrecognised status into a working one is exactly how this
defect stayed invisible.

Nothing consumes it yet; the next two commits replace the catch-alls.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
```

---

## Task 3: Derive `isActive`/`isExpired` from the kind

`subscription_state.dart:212-213` is two hand-maintained lists:

```dart
  bool get isExpired => status == 'EXPIRED' || status == 'CANCELLED';
  bool get isActive => status == 'ACTIVE' || status == 'TRIAL';
```

`PAST_DUE` is in neither, and `isExpired` drives the plan card's gradient (`subscription_page.dart:173-184`), so a lapsed merchant gets the healthy gradient.

**Files:**
- Modify: `app/test/presentation/blocs/subscription/subscription_bloc_test.dart`
- Modify: `app/lib/presentation/blocs/subscription/subscription_state.dart:212-213`

- [ ] **Step 1: Write the failing tests**

Append inside the existing top-level `group` that holds the load tests in `app/test/presentation/blocs/subscription/subscription_bloc_test.dart` — immediately after the `-1 = unlimited` test rewritten in Task 1:

```dart
      blocTest<SubscriptionBloc, SubscriptionState>(
        'should report a PAST_DUE subscription as lapsed, not as active',
        setUp: () => mockGet(<String, dynamic>{
          'plan': 'BUSINESS',
          'status': 'PAST_DUE',
        }),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          // BOTH directions. Asserting only isActive == false passed on the old
          // code — PAST_DUE was in neither list — and that half-assertion is
          // exactly what let a lapsed merchant keep the full-colour card, since
          // the gradient is chosen by isExpired.
          isA<SubscriptionLoaded>()
              .having((s) => s.isActive, 'isActive', false)
              .having((s) => s.isExpired, 'isExpired', true),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should treat a status it does not recognise as lapsed rather than active',
        setUp: () => mockGet(<String, dynamic>{
          'plan': 'BUSINESS',
          'status': 'SOMETHING_NEW',
        }),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>()
              .having((s) => s.isActive, 'isActive', false)
              .having((s) => s.isExpired, 'isExpired', true),
        ],
      );
```

- [ ] **Step 2: Run them to make sure they fail**

Run from `app/`:
```bash
flutter test test/presentation/blocs/subscription/subscription_bloc_test.dart
```
Expected: **2 failures**, both on `isExpired` — `Expected: isExpired: true / Actual: false`. `isActive` already reads `false` for both inputs on the old code; `isExpired` is the half that was broken. If a failure mentions `isActive` instead, the fixture is wrong.

- [ ] **Step 3: Write the implementation**

In `app/lib/presentation/blocs/subscription/subscription_state.dart`, replace lines 212-213 with:

```dart
  /// The server's gate, stated once: `feature-flag.helper.ts` allows ACTIVE and
  /// TRIAL and refuses everything else.
  bool get isActive =>
      kind == SubscriptionStatusKind.active ||
      kind == SubscriptionStatusKind.trial;

  /// Deliberately the negation of [isActive] and not a second list. It used to
  /// be `EXPIRED || CANCELLED`, which left PAST_DUE in neither — so the plan
  /// card, whose gradient this getter chooses, rendered a lapsed subscription
  /// in full colour while the backend refused every gated feature. Anything the
  /// server will refuse has to look refused, including a status this app has
  /// not heard of.
  bool get isExpired => !isActive;

  SubscriptionStatusKind get kind => subscriptionStatusKind(status);
```

Add the import alongside the existing ones at the top of the file (after line 3):

```dart
import '../../pages/settings/subscription_status.dart';
```

- [ ] **Step 4: Run the tests to verify they pass**

Run from `app/`:
```bash
flutter test test/presentation/blocs/subscription/subscription_bloc_test.dart
flutter analyze
```
Expected: all tests pass; `No issues found!`

- [ ] **Step 5: Confirm the pre-existing assertions still hold**

The `fullData` test at `:117-118` already asserts `isActive: true, isExpired: false` for `ACTIVE`, and another at `:215`/`:227` asserts both for other statuses. These must still pass unchanged — if any now fails, the negation changed behaviour for a status that was already handled correctly, which is a regression, not a fix. Report it rather than editing those assertions.

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/.worktrees/subscription-gaps
git add app/lib/presentation/blocs/subscription/subscription_state.dart \
        app/test/presentation/blocs/subscription/subscription_bloc_test.dart
git commit --file - <<'MSG'
fix(app): a lapsed subscription no longer renders as a healthy one

isActive was ACTIVE|TRIAL and isExpired was EXPIRED|CANCELLED — two lists kept
by hand over a five-value enum, so PAST_DUE was in neither. The plan card picks
its gradient from isExpired, so a merchant whose subscription had lapsed saw
the full-colour card on the one screen that exists to explain their
subscription, while the backend refused every gated feature.

isExpired is now the negation of isActive rather than a second list, so the two
cannot disagree, and isActive restates the server's documented gate exactly.
An unrecognised status lands on the lapsed side on purpose: a grey card that
under-promises beats a colour card that over-promises.

Both tests assert both directions. Asserting only isActive == false would have
passed on the broken code — PAST_DUE was false there too — and isExpired was
the half that mattered.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
```

---

## Task 4: Exhaustive status colour and label on the page

`_statusColor` (`subscription_page.dart:109-122`) returns `textMuted` from its `default:`, and `_statusLabel` (`:124-137`) returns the **raw status string** — which is how `PAST_DUE` reaches a merchant's screen untranslated, in Latin capitals.

Removing the `default:` is the point: the compiler then refuses a new enum member without a decision.

**Files:**
- Modify: `app/lib/l10n/app_ru.arb`
- Modify: `app/lib/presentation/pages/settings/subscription_page.dart:109-137,15`

- [ ] **Step 1: Add the two ARB keys**

In `app/lib/l10n/app_ru.arb`, insert after line 1265 (`"subscriptionExpiredStatus": "Истекла",`) so the keys stay inside the contiguous `subscription*` block, as this ARB's organisation requires:

```json
  "subscriptionPastDueStatus": "Просрочена",
  "@subscriptionPastDueStatus": { "description": "Subscription-status badge for PAST_DUE — the subscription lapsed and is billable, and the server already refuses every gated feature. Distinct from `subscriptionExpiredStatus` (\"Истекла\", ran out and was not renewed) and from `cancelled` (\"Отменена\", the merchant's own decision): all three are refused by the backend, but they are three different things for the merchant to do next" },
  "subscriptionUnknownStatus": "Статус неизвестен",
  "@subscriptionUnknownStatus": { "description": "Subscription-status badge for a status value the server sent that the app does not recognise. Same value as `subscriptionPaymentUnknownStatus` but a different enum — that one is for a Payment row's status, this one for the Subscription's; kept separate per this ARB's pattern of not merging same-value keys across features. Exists so no code path can print a raw enum name again: the page's `default:` used to return the status string itself, which is how PAST_DUE reached a merchant's screen in Latin capitals" },
```

Validate the JSON before going further:
```bash
cd app && python3 -m json.tool lib/l10n/app_ru.arb > /dev/null && echo "valid JSON"
```
Expected: `valid JSON`

- [ ] **Step 2: Regenerate localizations**

Run from `app/`:
```bash
flutter gen-l10n
```
Expected: no errors. `lib/l10n/app_localizations.dart` and friends are regenerated — **never hand-edit them**.

```bash
grep -c "subscriptionPastDueStatus\|subscriptionUnknownStatus" lib/l10n/app_localizations.dart
```
Expected: a non-zero count. If zero, `gen-l10n` did not pick the keys up.

- [ ] **Step 3: Replace both helpers**

In `app/lib/presentation/pages/settings/subscription_page.dart`, replace lines 109-137 with:

```dart
  // Both switches are exhaustive over SubscriptionStatusKind with no `default`,
  // so a value added to the enum fails the build instead of silently taking a
  // neutral grey and printing its own name. `_statusLabel`'s old `default:`
  // returned the raw status, which is how PAST_DUE reached a merchant's screen
  // in Latin capitals.
  Color _statusColor(String status) => switch (subscriptionStatusKind(status)) {
        SubscriptionStatusKind.active => AppColors.success,
        SubscriptionStatusKind.trial => AppColors.info,
        // PAST_DUE shares EXPIRED's error colour rather than CANCELLED's muted
        // one: it is a problem the merchant has to act on, not a settled end
        // state.
        SubscriptionStatusKind.pastDue => AppColors.error,
        SubscriptionStatusKind.expired => AppColors.error,
        SubscriptionStatusKind.cancelled => context.textMuted,
        SubscriptionStatusKind.unknown => context.textMuted,
      };

  String _statusLabel(String status) {
    final l10n = AppLocalizations.of(context)!;
    return switch (subscriptionStatusKind(status)) {
      SubscriptionStatusKind.active => l10n.subscriptionActiveStatus,
      SubscriptionStatusKind.trial => l10n.subscriptionTrialStatus,
      SubscriptionStatusKind.pastDue => l10n.subscriptionPastDueStatus,
      SubscriptionStatusKind.expired => l10n.subscriptionExpiredStatus,
      SubscriptionStatusKind.cancelled => l10n.cancelled,
      SubscriptionStatusKind.unknown => l10n.subscriptionUnknownStatus,
    };
  }
```

Add the import after line 15 (`import 'payment_status.dart';`):

```dart
import 'subscription_status.dart';
```

- [ ] **Step 4: Verify the switches are genuinely exhaustive**

A `switch` expression with a `_ =>` arm would compile but defeat the purpose. Prove the compiler is enforcing it:

```bash
cd app
cp lib/presentation/pages/settings/subscription_status.dart /tmp/status.keep
perl -pi -e 's/^  unknown,$/  unknown,\n  probe,/' lib/presentation/pages/settings/subscription_status.dart
flutter analyze 2>&1 | grep -c "non_exhaustive_switch\|not exhaustive"
```

`perl`, not `sed` — BSD sed would insert a literal `n` instead of a newline and the probe would silently not exist, making this check pass for the wrong reason. The `^...$` anchors keep it off the `_ => SubscriptionStatusKind.unknown,` line.
Expected: a non-zero count, naming both `_statusColor` and `_statusLabel`. If zero, one of the switches still has a catch-all arm and must be fixed.

Restore:
```bash
cp /tmp/status.keep lib/presentation/pages/settings/subscription_status.dart
rm -f /tmp/status.keep
flutter analyze
git diff --stat lib/presentation/pages/settings/subscription_status.dart
```
Expected: `No issues found!`, and an **empty** `git diff --stat` — proof the probe is gone rather than merely not flagged.

- [ ] **Step 5: Run the i18n linter and the full app suite**

Run from `app/`:
```bash
dart run tool/check_i18n.dart ; echo "exit=$?"
```
Expected: `exit=0`. A non-zero exit of 3 means the allow-list has entries that are now unused — report it rather than editing the allow-list blind.

```bash
flutter test 2>&1 | tail -30
```
Expected: the failing set is **exactly** the 18 documented macOS golden failures. Compare the set of test names, not the count — a count that happens to match while the names differ is a regression hiding behind a coincidence.

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/.worktrees/subscription-gaps
git add app/lib/l10n/app_ru.arb app/lib/l10n/app_localizations*.dart \
        app/lib/presentation/pages/settings/subscription_page.dart \
        app/l10n_untranslated.json
git commit --file - <<'MSG'
fix(app): the status badge no longer prints a raw enum name

_statusLabel's `default:` returned the status string itself, so a PAST_DUE
subscription put "PAST_DUE" on a merchant's screen in Latin capitals, and
_statusColor's default gave it the same neutral grey as a cancellation.

Both switches are now exhaustive over SubscriptionStatusKind with no `default`,
so the next value added to the enum fails the build rather than quietly
inheriting a wrong colour and its own name as a label. Verified by adding a
probe member and confirming the analyzer rejects both switches.

PAST_DUE takes EXPIRED's error colour, not CANCELLED's muted one: it is a
problem to act on rather than a settled end state. The new unknown-status key
exists so no code path can reach a raw enum name again.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
```

---

## Task 5: Make the card-with-receipt flow work

`_onReceiptUploaded` (`subscription_bloc.dart:55-87`) disagrees with its route three ways: path (`upload-receipt` vs `upload-receipt/:paymentId`), multipart field (`receipt` vs `file`), and order — the `paymentId` is created by `request-change`, which the handler calls *afterwards* and whose response it discards. So the upload 404s and the request never runs: paying by card records nothing at all.

**Files:**
- Modify: `app/lib/core/errors/app_message.dart:33,47`
- Modify: `app/lib/presentation/l10n/app_message_l10n.dart:41`
- Modify: `app/lib/l10n/app_ru.arb:1453`
- Modify: `app/lib/presentation/blocs/subscription/subscription_bloc.dart:2,55-87`
- Modify: `app/test/presentation/blocs/subscription/subscription_bloc_test.dart:380-470`

- [ ] **Step 1: Add the message value and its ARB key**

Reversing the order creates a state the old code could not reach: the request exists and the receipt does not. That must not read as a flat failure, because `requestChange` does not de-duplicate pending payments — a merchant who saw "ошибка" and resubmitted would create a second request for the same plan.

In `app/lib/core/errors/app_message.dart`, replace line 47 with:

```dart
  subscriptionRequestSent,

  /// The plan-change request was created but its receipt did not upload. Its own
  /// member rather than an error, deliberately: the request DOES exist, and
  /// `requestChange` does not de-duplicate pending payments, so telling the
  /// merchant it failed would make them resubmit and create a second one.
  subscriptionRequestSentWithoutReceipt,
```

In `app/lib/presentation/l10n/app_message_l10n.dart`, replace line 41 with:

```dart
        AppMessage.subscriptionRequestSent => l10n.subscriptionRequestSent,
        AppMessage.subscriptionRequestSentWithoutReceipt =>
          l10n.subscriptionRequestSentWithoutReceipt,
```

In `app/lib/l10n/app_ru.arb`, insert after line 1454 (the `@subscriptionRequestSent` description) so the key stays in its prefix block:

```json
  "subscriptionRequestSentWithoutReceipt": "Заявка отправлена, но чек не загрузился. Свяжитесь с поддержкой.",
  "@subscriptionRequestSentWithoutReceipt": { "description": "Snackbar when the plan-change request was created but the receipt image failed to upload. It points the merchant at support rather than at a retry on purpose: there is no UI for attaching a receipt to an existing payment, and resubmitting the form would create a second pending request, since request-change does not de-duplicate. Distinct from `subscriptionRequestSent`, where the receipt did attach" },
```

The `unknownError` doc comment at `app_message.dart:32` says "Two branches share this"; Step 3 adds a third. Update it to:

```dart
  /// Three branches share this: an unrecognised exception type, a
  /// ServerException whose status code has no specific mapping, and a
  /// request-change response with no payment id in it.
  unknownError,
```

- [ ] **Step 2: Regenerate localizations and validate**

Run from `app/`:
```bash
python3 -m json.tool lib/l10n/app_ru.arb > /dev/null && echo "valid JSON"
flutter gen-l10n
grep -c subscriptionRequestSentWithoutReceipt lib/l10n/app_localizations.dart
```
Expected: `valid JSON`, no gen-l10n errors, non-zero count.

- [ ] **Step 3: Write the failing tests**

Replace lines 389-470 of `app/test/presentation/blocs/subscription/subscription_bloc_test.dart` — both existing tests — with the following. The old ones stubbed `post` against the literal path the bloc called and then verified that same string, so they asserted the implementation against itself and could not fail on any of the three defects.

```dart
      // Records every post in order, so a test can assert the SEQUENCE and the
      // URL the bloc built from the first response. The replaced tests matched
      // `'/stores/store-1/subscription/upload-receipt'` exactly — a path the
      // server does not have — and then verified that same literal, which is
      // why three real mismatches stayed green for months.
      late List<({String path, Object? data})> posts;

      void recordPosts({String? requestChangeId = 'pay-7', Object? uploadThrows}) {
        posts = [];
        when(() => dioClient.post<dynamic>(any(), data: any(named: 'data')))
            .thenAnswer((invocation) async {
          final path = invocation.positionalArguments.first as String;
          final data = invocation.namedArguments[const Symbol('data')];
          posts.add((path: path, data: data));
          if (path.contains('/upload-receipt')) {
            if (uploadThrows != null) throw uploadThrows;
            return resp({'ok': true});
          }
          return resp(requestChangeId == null
              ? <String, dynamic>{}
              : <String, dynamic>{'id': requestChangeId});
        });
      }

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should create the change request first, then upload the receipt to that payment',
        wait: const Duration(milliseconds: 200),
        setUp: () {
          recordPosts();
          mockGet(fullData, payments: paymentsFixture);
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(SubscriptionReceiptUploaded(
          storeId: 'store-1',
          plan: 'BUSINESS',
          paymentMethod: 'CARD',
          receiptPath: receiptPath,
        )),
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionActionSuccess(AppMessage.subscriptionRequestSent),
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>(),
        ],
        verify: (_) {
          // The order and the id in the URL, in one assertion. The receipt
          // attaches to a Payment row that request-change creates, so an upload
          // sent first has no id to carry — the old code sent it first and
          // discarded the response that held the id.
          expect(posts.map((p) => p.path).toList(), [
            '/stores/store-1/subscription/request-change',
            '/stores/store-1/subscription/upload-receipt/pay-7',
          ]);
          expect(posts.first.data, {'plan': 'BUSINESS', 'paymentMethod': 'CARD'});
        },
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should name the multipart field file, as the route interceptor requires',
        wait: const Duration(milliseconds: 200),
        setUp: () {
          recordPosts();
          mockGet(fullData, payments: paymentsFixture);
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(SubscriptionReceiptUploaded(
          storeId: 'store-1',
          plan: 'BUSINESS',
          paymentMethod: 'CARD',
          receiptPath: receiptPath,
        )),
        verify: (_) {
          // Reaches INTO the FormData. `any(named: 'data')` never looked, which
          // is how a field named 'receipt' survived against
          // FileInterceptor('file', ...) in subscriptions.controller.ts:95.
          final upload =
              posts.firstWhere((p) => p.path.contains('/upload-receipt'));
          final formData = upload.data as FormData;
          expect(formData.files.map((e) => e.key).toList(), ['file']);
        },
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should tell the merchant the request went through when only the receipt upload fails',
        wait: const Duration(milliseconds: 200),
        setUp: () {
          recordPosts(uploadThrows: const NetworkException());
          mockGet(fullData, payments: paymentsFixture);
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(SubscriptionReceiptUploaded(
          storeId: 'store-1',
          plan: 'BUSINESS',
          paymentMethod: 'CARD',
          receiptPath: receiptPath,
        )),
        // Not an error state: the request EXISTS. request-change does not
        // de-duplicate pending payments, so reporting a flat failure would make
        // the merchant resubmit and create a second request for the same plan.
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionActionSuccess(
              AppMessage.subscriptionRequestSentWithoutReceipt),
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>(),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should emit an error and never upload when the change request itself fails',
        wait: const Duration(milliseconds: 200),
        setUp: () {
          posts = [];
          when(() => dioClient.post<dynamic>(any(), data: any(named: 'data')))
              .thenThrow(const NetworkException());
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(SubscriptionReceiptUploaded(
          storeId: 'store-1',
          plan: 'BUSINESS',
          paymentMethod: 'CARD',
          receiptPath: receiptPath,
        )),
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionError(AppMessage.offline),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should stop rather than build an upload URL when the response carries no payment id',
        wait: const Duration(milliseconds: 200),
        setUp: () => recordPosts(requestChangeId: null),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(SubscriptionReceiptUploaded(
          storeId: 'store-1',
          plan: 'BUSINESS',
          paymentMethod: 'CARD',
          receiptPath: receiptPath,
        )),
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionError(AppMessage.unknownError),
        ],
        verify: (_) {
          // Posting to a path ending in `/null` would 404 exactly like the bug
          // being fixed, and look identical in the logs.
          expect(posts.where((p) => p.path.contains('/upload-receipt')), isEmpty);
        },
      );
```

Keep the surrounding `setUp`/`tearDown` that create and delete the temp `receiptPath` file (`:365-378`) and keep every `wait: const Duration(milliseconds: 200)` — the handler still does real file I/O before reaching the mock, and that duration documents a diagnosed CI flake that failed about 1 run in 6.

The comment block immediately above the tests (`:380-388`) explains that `wait`. **Keep it, and change its opening from "Both tests in this group need an explicit `wait`" to "Every test in this group needs an explicit `wait`"** — there are five now. Leave the rest of it alone; it records a diagnosis, not a description of the count.

- [ ] **Step 4: Run them to make sure they fail**

Run from `app/`:
```bash
flutter test test/presentation/blocs/subscription/subscription_bloc_test.dart
```
Expected: **4 failures** among the five new tests, and each must fail for its own reason — read the messages rather than counting:
- ordering/id test: the recorded paths are `upload-receipt` then `request-change`, i.e. reversed and with no id;
- multipart test: the field key is `receipt`, not `file`;
- upload-failure test: `[Uploading, Error]` instead of `ActionSuccess(...WithoutReceipt)`;
- missing-id test: `[Uploading, ActionSuccess]` — the old code never looked at the response.

The fourth test (`request change itself fails`) **passes** on the old code, because the single `thenThrow` catches whichever call goes first. That is expected and is why it is not sufficient on its own.

- [ ] **Step 5: Write the implementation**

In `app/lib/presentation/blocs/subscription/subscription_bloc.dart`, replace lines 55-87 with:

```dart
  Future<void> _onReceiptUploaded(
    SubscriptionReceiptUploaded event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionUploading());

    // Order matters, and it used to be reversed. The receipt attaches to a
    // Payment row, and that row is created by request-change — so the request
    // has to come first and its id has to be carried into the upload path.
    // Reversed, the upload had no id, hit a route that does not exist
    // (`upload-receipt` without `/:paymentId`), 404'd, and the request never
    // ran at all: paying by card recorded nothing.
    final String paymentId;
    try {
      final response = await _dioClient.post<dynamic>(
        '/stores/${event.storeId}/subscription/request-change',
        data: {
          'plan': event.plan,
          'paymentMethod': event.paymentMethod,
        },
      );
      final id = (response.data as Map<String, dynamic>?)?['id'] as String?;
      if (id == null || id.isEmpty) {
        // Stop rather than POST to a path ending in `/null`, which would 404
        // exactly like the bug this replaces and look the same in the logs.
        emit(const SubscriptionError(AppMessage.unknownError));
        return;
      }
      paymentId = id;
    } catch (e) {
      emit(SubscriptionError(mapErrorToAppMessage(e)));
      return;
    }

    // Past this point the request exists. An upload failure must NOT read as a
    // flat failure: requestChange does not de-duplicate pending payments, so a
    // merchant who resubmitted would create a second request for the same plan.
    try {
      final formData = FormData.fromMap({
        // Named 'file' because the route is FileInterceptor('file', ...) —
        // subscriptions.controller.ts:95. It used to be 'receipt'.
        'file': await MultipartFile.fromFile(
          event.receiptPath,
          filename: 'receipt.jpg',
        ),
      });
      await _dioClient.post<dynamic>(
        '/stores/${event.storeId}/subscription/upload-receipt/$paymentId',
        data: formData,
      );
      emit(const SubscriptionActionSuccess(
          AppMessage.subscriptionRequestSent));
    } catch (_) {
      emit(const SubscriptionActionSuccess(
          AppMessage.subscriptionRequestSentWithoutReceipt));
    }

    // Reloads either way, so the pending-payment banner confirms the request
    // exists even when the receipt did not attach.
    add(SubscriptionLoadRequested(storeId: event.storeId));
  }
```

`MultipartFile.fromFile` takes the path directly, so the `File(...)` wrapper is gone and `dart:io` becomes the bloc's only unused import. Delete line 2 (`import 'dart:io';`) — `flutter analyze` will flag it otherwise. Check first that nothing else in the file uses `File`:

```bash
cd app && grep -n "File(" lib/presentation/blocs/subscription/subscription_bloc.dart
```
Expected: only the `MultipartFile.fromFile` call. If anything else appears, keep the import.

- [ ] **Step 6: Run the tests to verify they pass**

Run from `app/`:
```bash
flutter test test/presentation/blocs/subscription/subscription_bloc_test.dart
flutter analyze
```
Expected: all tests pass; `No issues found!`

- [ ] **Step 7: Verify each new test actually guards its own defect**

A test suite that goes green proves nothing here, because the suite it replaced was green through the bug. Revert each mismatch one at a time and confirm the expected test — and only it — fails:

```bash
cd app
cp lib/presentation/blocs/subscription/subscription_bloc.dart /tmp/bloc.keep

# (a) field name back to 'receipt'
sed -i.bak "s/'file': await MultipartFile/'receipt': await MultipartFile/" lib/presentation/blocs/subscription/subscription_bloc.dart
flutter test test/presentation/blocs/subscription/subscription_bloc_test.dart 2>&1 | grep -E "multipart field|All tests passed"
# Expected: the 'should name the multipart field file' test FAILS.
cp /tmp/bloc.keep lib/presentation/blocs/subscription/subscription_bloc.dart

# (b) drop the paymentId from the path
sed -i.bak 's|upload-receipt/\$paymentId|upload-receipt|' lib/presentation/blocs/subscription/subscription_bloc.dart
flutter test test/presentation/blocs/subscription/subscription_bloc_test.dart 2>&1 | grep -E "then upload the receipt|All tests passed"
# Expected: the ordering/id test FAILS.
cp /tmp/bloc.keep lib/presentation/blocs/subscription/subscription_bloc.dart

flutter test test/presentation/blocs/subscription/subscription_bloc_test.dart
# Expected: back to all passing.
rm -f lib/presentation/blocs/subscription/subscription_bloc.dart.bak /tmp/bloc.keep
```

If a revert leaves the suite green, that test does not guard what its name claims and must be fixed before committing.

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/.worktrees/subscription-gaps
git add app/lib/presentation/blocs/subscription/subscription_bloc.dart \
        app/lib/core/errors/app_message.dart \
        app/lib/presentation/l10n/app_message_l10n.dart \
        app/lib/l10n/app_ru.arb app/lib/l10n/app_localizations*.dart \
        app/l10n_untranslated.json \
        app/test/presentation/blocs/subscription/subscription_bloc_test.dart
git commit --file - <<'MSG'
fix(app): paying a subscription by card now records something

The handler disagreed with its route three ways, and the third was structural.
The receipt attaches to a Payment row that request-change creates, and the
handler called request-change AFTER the upload and discarded its response — so
there was no paymentId to send, the upload hit `upload-receipt` without the
`/:paymentId` segment the route requires, 404'd, and request-change never ran.
A merchant paying by card created no request, no receipt, and nothing for an
admin to approve. The only working path was "paid cash", a different claim
about how they paid.

The multipart field was 'receipt' against FileInterceptor('file', ...).

Both replaced tests stubbed post() against the literal path the bloc called and
then verified that same literal, so they asserted the implementation against
itself and could not fail on the order, the id, or the field name. The new ones
record the calls and assert the sequence, the id inside the upload URL, and the
FormData key — then each was checked by reverting the specific mismatch it
claims to guard.

Reversing the order makes one new state reachable: request created, receipt
not. It emits its own success message rather than an error, because
requestChange does not de-duplicate pending payments — "ошибка" would make the
merchant resubmit and create a second request for the same plan. It reloads
either way so the pending banner confirms the request exists.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
```

---

## Task 6: Device verification and full gates

Unit tests are necessary and not sufficient here: the tests this branch replaced were green while the feature recorded nothing. Every claim in this task is verified by looking, not by inferring.

**Files:** none — verification only.

- [ ] **Step 1: Confirm the stack is up**

```bash
adb devices
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4455/api/health
docker ps --filter name=dukonpro-db --format '{{.Names}} {{.Status}}'
```
Expected: `emulator-5554 device`; a 2xx or 404 from the API (anything but a connection refusal); the container `Up`.

If the API is down, start it from `api/` with `npm run start:prod` (it serves compiled `dist/`). **Do not rebuild it** — no API source changed on this branch, and a rebuild only adds ways to fail.

If a health check succeeds but behaviour looks stale, an orphaned `node` process may be holding the port with its cwd in a deleted worktree; `pkill -f "node dist/main"` does not match it. Check which process actually serves the port before trusting anything:
```bash
for p in $(lsof -nP -iTCP:4455 -sTCP:LISTEN -t); do lsof -a -p $p -d cwd -Fn | grep ^n; done
```
This exact symptom cost most of a previous session.

- [ ] **Step 2: Install this branch's build**

Run from `app/`:
```bash
flutter run -d emulator-5554
```
Leave it attached for hot reload during the walkthrough.

- [ ] **Step 3: Verify the card-with-receipt flow end to end**

Sign in as `+992920777001` / `x8R9s5msWiEzBYWL`. Go to Настройки → Подписка. Pick a plan other than the current one, choose payment by card, attach any photo, submit.

On the device, confirm:
- the snackbar reads "Заявка отправлена, ожидайте подтверждения" — **not** the without-receipt variant, which would mean the upload failed;
- the pending-payment banner appears on the card;
- a row appears in the payment history with a non-blank title and an "Ожидает" badge.

Then in the database, confirm the receipt actually attached:
```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "SELECT id, status, method, \"receiptImage\" FROM \"Payment\" ORDER BY \"createdAt\" DESC LIMIT 3;"
```
Expected: the newest row is `PENDING` / `CARD` with a non-null `receiptImage` under `uploads/receipts/`.

- [ ] **Step 4: Verify the admin sees both halves**

Open `http://localhost:3000`, sign in as an admin, find the request. Confirm the request is listed **and** that the receipt image opens.

Both halves, separately. The lesson from this file's history is that confirming one element of a row is not confirming the row — a previous device check verified a status badge and missed that every title rendered blank.

- [ ] **Step 5: Verify PAST_DUE on the device**

Find the store the signed-in merchant owns, and force its status. Resolve the id from the phone number rather than pasting one in — guessing which of several stores the session is on is how a "nothing changed" result gets misread as a broken fix:

```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -t -c \
  "SELECT s.id, s.name, sub.status FROM \"Store\" s
     JOIN \"User\" u ON u.id = s.\"ownerId\"
     LEFT JOIN \"Subscription\" sub ON sub.\"storeId\" = s.id
    WHERE u.phone = '+992920777001';"
```
Note the id and the current status — you need the original value to restore it. Then:

```bash
STORE_ID=<the id from above>
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "UPDATE \"Subscription\" SET status='PAST_DUE' WHERE \"storeId\"='${STORE_ID}';"
```

Brace `${STORE_ID}` — in zsh an unbraced `"$STORE_ID:..."` is parsed as a `:P`-style parameter modifier and silently substitutes something else.

Pull to refresh the subscription screen. Confirm:
- the plan card is **grey**, not the brand gradient;
- the badge reads **"Просрочена"** in Russian — if any Latin text appears, `_statusLabel` is still falling through.

Restore the status you noted before the update — not a hardcoded `ACTIVE`, which would silently promote a store that had been on `TRIAL`:
```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "UPDATE \"Subscription\" SET status='<the status you noted>' WHERE \"storeId\"='${STORE_ID}';"
```

Then re-run the `SELECT` above and confirm it reads what it read at the start. Leave the database as it was found: this is the shared dev database, and an abandoned `PAST_DUE` row will look like a bug to the next person.

- [ ] **Step 6: Run the full gate set**

From `app/`:
```bash
flutter analyze
dart run tool/check_i18n.dart ; echo "i18n exit=$?"
flutter test 2>&1 | tail -40
flutter gen-l10n && git diff --stat l10n_untranslated.json
```
Expected: `No issues found!`; i18n exit 0; the failing test set **identical as a set** to the 18 documented macOS goldens; `l10n_untranslated.json` showing the three new keys added to the tg/uz backlog — a tracked artifact to commit, not a byproduct to discard.

From `api/`:
```bash
npm test
npx tsc --noEmit ; echo "tsc exit=$?"
```
Expected: green, `tsc exit=0`. Nothing in `api/` changed, so this is a guard against an accidental edit, not a real risk. Green tests do not imply clean types here — `ts-jest` has let a real `TS2769` through before — so run both.

- [ ] **Step 7: Commit any localization backlog change**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/.worktrees/subscription-gaps
git status --short
```
If `app/l10n_untranslated.json` is dirty:
```bash
git add app/l10n_untranslated.json
git commit -m "chore(l10n): record the three new subscription keys in the tg/uz backlog

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```
If nothing is dirty, this branch is complete — proceed to superpowers:finishing-a-development-branch.
