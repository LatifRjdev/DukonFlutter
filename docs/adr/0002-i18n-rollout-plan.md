# ADR-0002 — i18n rollout plan for Russian / Tajik / Uzbek

**Status:** Proposed — 2026-04-11
**Related issue:** #29 FE-P1-001

## Context

288 Russian string literals are hardcoded across 59 user-facing screens
in `app/lib/presentation/pages/`. `app_ru.arb`, `app_tg.arb`, and
`app_uz.arb` do exist but are incomplete (~140 keys in `_ru`, ~100 in
`_tg`/`_uz`), so the tg/uz locales technically resolve but the vast
majority of the UI falls back to Russian regardless of locale. For the
app's core markets (Tajik and Uzbek speakers) the product effectively
only speaks Russian.

The scope is too large to land as a single PR — literal-replacement is
mechanical but the **review** cost is not (288 call sites × 3 locales
= ~900 translated entries, each needs a native-speaker sign-off).

## Decision

Three parallel tracks.

### Track 1 — stop the bleed (immediately, this PR)

Add a custom Flutter lint rule that fails CI if a `.dart` file under
`app/lib/presentation/` contains a Cyrillic string literal OUTSIDE of
`AppLocalizations.of(context).*` calls. The rule is scoped to new and
modified files — existing 288 strings are grandfathered via an
allow-list file (`i18n-allowlist.txt`) so CI doesn't explode.

Mechanism:
- Use `custom_lint` + `riverpod_lint`-style package, or a simpler
  `dart run tool/check_i18n.dart` script wired into `pre-push` and CI.
- Current PR ships the script + allow-list populated from the existing
  offenders. Every new offender gets a CI failure.

### Track 2 — incremental migration

Migrate in feature-module batches of ~30 strings each, one PR per
batch. Priority order by user-visibility:

1. `auth/` — login, register, OTP (7 strings)
2. `dashboard/` — KPI labels, header (12)
3. `pos/` — checkout, cart, discount (31) ← highest POS use
4. `products/` — list, form, filters (28)
5. `customer/`, `supplier/` — list, form, detail (22)
6. `more/` — menu tree (14)
7. `finance/`, `expenses/` — (38)
8. `zakat/`, `payroll/`, `shifts/` — (34)
9. `staff/`, `roles/` — (18)
10. Widgets + error messages (48)

Each batch: add keys to all three ARB files, regenerate the typed
accessors, replace literals. Native-speaker review is required for tg
and uz — tracked by a sub-issue per batch.

### Track 3 — the error-message layer

`core/errors/error_messages.dart` (added in PR #50) hardcodes Russian
strings. These need to move to the ARB files too, but they run outside
a `BuildContext` (they're called from blocs). Use a tiny wrapper that
looks up via `AppLocalizations.of(rootContext)` or defers to a static
`ErrorMessages` helper that takes a `Locale` argument and is invoked
from the UI layer instead of the bloc.

## Acceptance criteria

- [x] This ADR merged (track 1 design).
- [ ] Lint script lands (separate PR, same sprint).
- [ ] 10 batches land (separate PRs, ~1/week).
- [ ] tg/uz native-speaker review for each batch.
- [ ] Error-message layer migrated (last).
- [ ] `tool/check_i18n.dart` allow-list is empty → i18n is done.

## Why this is an ADR not code

Three choices need owner input:
1. Which lint mechanism (`custom_lint` plugin vs standalone script).
2. Native-speaker tg/uz sourcing — engineering vs localization
   contractor.
3. Whether to ship tg/uz with fallback-to-ru glyphs until review, or
   block locale switch until 100% coverage.

After those decisions the 10 batches can run in parallel on track 2.

## Reconciliation update — 2026-08-22

`feat/l10n-and-retry-after` shipped a 37-task worst-offender-first
extraction plan (35 `lib/presentation/` files migrated to
`AppLocalizations`/`app_ru.arb`) that was scoped and ordered before
this ADR was discovered mid-branch. Reconciling now, after the fact:

- **Track 2 ordering:** this branch did not follow the batch order
  above (auth → dashboard → pos → …). It prioritized the highest
  hardcoded-string-count files first, cutting across several of the
  ADR's batches at once (dashboard, finance, inventory, pos, product,
  staff, settings, etc.). No further action needed — the ADR's batch
  list should be treated as already partially complete; whoever picks
  up Track 2 next should re-derive remaining scope from
  `tool/i18n-allowlist.txt` rather than the original per-batch string
  counts, which now overcount work already done.
- **tg/uz native-speaker review:** explicitly **not** pursued for this
  branch's work, per an earlier product decision made mid-branch to
  defer tg/uz translation for now. tg and uz continue to fall back to
  Russian for all keys, including the ones this branch added. This is
  a deliberate deferral, not an oversight — the acceptance criterion
  "tg/uz native-speaker review for each batch" is intentionally unmet
  and should stay unchecked until that product decision is revisited.
- **Allowlist:** `tool/i18n-allowlist.txt` has been regenerated via
  `dart run tool/check_i18n.dart --dump-allowlist` and now reflects
  actual current violations (1017 entries, replacing the 859-entry
  file from before this branch). The old allowlist was stale in both
  directions: ~724 of its entries no longer match (either the string
  was extracted by this branch, or its line number drifted because an
  edit elsewhere in the same file shifted line numbers), while ~882
  currently-real violations were missing from it. Investigation traced
  most of that gap to a separate, pre-existing bug: `check_i18n.dart`'s
  `main()` returns a non-zero `int` on failure but never calls
  `dart:io`'s `exit()`/`exitCode`, so the process always exits `0`
  regardless of what it finds. As a result CI's `i18n lint
  (check_i18n.dart)` step in `.github/workflows/ci.yml` has never
  actually failed the build, and ~590 hardcoded strings accumulated
  in files outside this branch's scope between the allowlist's
  original creation and this branch starting, undetected. That exit
  code bug is out of scope for this reconciliation (kept as
  bookkeeping-only) but should be fixed separately, since Track 1 is
  currently not enforcing anything.
- **Remaining scope:** none of the 35 files this branch touched have
  any remaining lint offenders. The ~1017 remaining allowlisted
  violations live entirely in files this branch did not touch, roughly
  40-something screens/blocs/widgets by the mid-branch ~78-file
  estimate minus what's done here. Left for future Track 2 batches, in
  whatever order is convenient at that time.
