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
