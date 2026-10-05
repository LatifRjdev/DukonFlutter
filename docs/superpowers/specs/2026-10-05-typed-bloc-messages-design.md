# Typed Bloc Messages — Design

**Date:** 2026-10-05
**Status:** Approved (scope: both paths at once)
**Base:** `main` at `3f2a948`

## The problem

Blocs put **user-facing Russian text** into state objects. Two sources:

1. **Errors.** `mapErrorToUserMessage` (`lib/core/errors/error_messages.dart`) returns one of
   **11 hardcoded Russian strings**. Called at **125 sites across 51 files**.
2. **Successes.** Blocs construct success states with inline literals —
   `SettingsActionSuccess('Профиль обновлён')`. **9 distinct strings.**

Both land in a `final String message` field on **33 state classes** (28 error carriers, 5 success
carriers) and are read at **~110 sites**, 38 of them snackbars.

None of it can be translated. `app_tg.arb` and `app_uz.arb` cannot reach a string that a bloc
baked in, so a Tajik or Uzbek user sees Russian for every error and every confirmation.

## Why the obvious fix is wrong

The tempting move is to localize inside the bloc — inject `AppLocalizations`, keep
`String message`. It is wrong here: `AppLocalizations.of(context)` is context-bound, and
`.claude/rules/kmp-architecture.md` keeps presentation logic out of anything that would need a
`BuildContext`. A bloc that owns a locale also re-emits stale text when the user changes
language mid-session, because the string was resolved at emit time.

## The shape of the fix

**State carries a code; the widget resolves it.** The code is a value; the string is produced
where a `BuildContext` exists.

This works cleanly because the mapping is *already* a pure function of a closed input set.
`mapErrorToUserMessage` dispatches **only** on runtime exception type and
`ServerException.statusCode` — it never reads the exception's own `message` field, which
`exceptions.dart` documents as diagnostic-only and deliberately English. So replacing the
return type is mechanical and lossless: the same 11 branches, returning an enum value instead
of a literal.

```dart
enum AppMessage {
  // errors
  offline, sessionExpired, badRequest, forbidden, notFound, conflict,
  tooManyRequests, serverError, cacheError, unknownError,
  // successes
  profileUpdated, passwordChanged, expenseAdded, expenseUpdated, expenseDeleted,
  paymentRecorded, paymentAccepted, zakatPaymentRecorded, zakatSettingsSaved,
}
```

`mapErrorToUserMessage` becomes `mapErrorToAppMessage(Object) → AppMessage`, same branches.
Blocs emit `SettingsActionSuccess(AppMessage.profileUpdated)`. A single extension resolves:

```dart
extension AppMessageL10n on AppMessage {
  String resolve(AppLocalizations l10n) => switch (this) { ... };
}
```

A `switch` over an enum with no `default` makes a missing case a **compile error**, so a new
message cannot ship untranslated.

## Decisions worth stating

**One enum, not two.** Errors and successes share a carrier because they share a destination —
`AppSnackbar.success` and `AppSnackbar.error` both take whatever `state.message` held. Splitting
them would force two resolve extensions and two imports at every call site for no gain. The enum
member names carry the distinction.

**`offline` reuses `offlineBannerNoConnection`.** That key already exists with exactly the string
the error path returns for `NetworkException`. `.claude/rules/mobile-l10n.md` requires grepping
the ARB before minting a key; this is the one that already matches.

**Ten new ARB keys, not eleven.** The generic fallback string `'Не удалось выполнить операцию'`
is returned by two branches (unknown exception type, and a `ServerException` with an unmapped
status). Both map to `AppMessage.unknownError` — one key, two producers.

**`exceptions.dart` is untouched.** Its `message` field stays English and diagnostic. This change
does not make it user-facing; it removes the last reason anyone might think it should be.

## What this does NOT do

- Does not translate anything into tg/uz. It makes translation *possible*; the new keys land in
  `l10n_untranslated.json` like every other key awaiting a translator.
- Does not add logging. `exceptions.dart` records that the app has no logging infrastructure and
  that the diagnostic `message` is write-only; that stays true and stays tracked separately.
- Does not touch Russian plural forms. That is a separate deliberate sweep.

## Risk

**The diff is wide and shallow — 33 state classes, ~110 read sites, 125 call sites.** Almost all
of it is mechanical, which is exactly the shape where a careless regex breaks something quietly.
Three controls:

1. The type change is the enforcement. Every unconverted read site is a **compile error**, not a
   silent fallthrough — `flutter analyze` finding nothing is a real signal here.
2. The resolve `switch` has no `default`, so an enum member with no ARB key cannot compile.
3. Snackbar sites are the risk spot: `AppSnackbar.success(context, state.message)` becomes
   `state.message.resolve(l10n)`, and a site that already had a `BuildContext` in scope but no
   `l10n` needs one added. These are counted and listed in the plan rather than swept blind.

**A second-order risk:** some `*ActionSuccess` states may be constructed in more than one place
with different strings, which the enum cannot express without a new member per string. The plan's
first task is an inventory that pins each construction site to exactly one enum member, so this
surfaces before any edit rather than during one.

## Testing

- Unit: every exception type and every mapped status code yields the expected `AppMessage` — the
  same table `mapErrorToUserMessage` is tested against today, retargeted.
- Unit: `resolve` returns a non-empty string for **every** enum member, iterating
  `AppMessage.values` so a new member without a key fails even if someone adds a `default`.
- Widget: one snackbar path and one inline-error path render the resolved Russian text, proving
  the wiring rather than the vocabulary.
- The existing bloc tests assert on `state.message` and will need their expectations retargeted
  to the enum; that count goes in the plan.

## Verification

| Check | Expectation |
|---|---|
| `flutter analyze` | `No issues found!` — and here it is load-bearing, not a formality |
| `flutter test` | failing set identical to the documented 18 macOS goldens |
| `dart run tool/check_i18n.dart` | exit 0; the literal count it scans should **drop** |
| `grep mapErrorToUserMessage lib` | zero hits outside the deprecation shim, if one is kept |
| `flutter gen-l10n` | the 10 new keys appear in `l10n_untranslated.json` for tg and uz |
