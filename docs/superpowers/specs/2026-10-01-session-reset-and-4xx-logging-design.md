# Session Reset on Logout, and 4xx Logging — Design

**Date:** 2026-10-01
**Status:** Approved
**Base:** `main` at `8e112be`

## The bug

After signing out and signing in as a different user, **every data-fetching screen shows a red
"Недостаточно прав"** instead of content — the dashboard, Товары, Финансы. Each needs its own manual
"Повторить" to recover. It is the first thing a user sees after switching accounts.

Reproduced repeatedly on the emulator against two real accounts. **Касса is unaffected**, which is the
clue: it is a local cart screen that fetches nothing.

## Diagnosis

Three facts, each verified:

1. **Every bloc is provided at the app root.** `app/lib/app.dart`'s `MultiBlocProvider` creates ~25
   blocs above the router and above any auth gate, so they outlive logout. The DI registrations are
   `registerFactory`, so this is purely a widget-tree lifetime issue, not a DI one.
2. **Nothing resets them.** `StoreBloc` has no logout handling, and across the whole app nothing listens
   for `AuthUnauthenticated` except `splash_page.dart`, which only navigates. `AuthBloc._onLogoutRequested`
   deletes tokens and the cached user and emits `AuthUnauthenticated` — it does not touch other blocs.
3. **So `StoreBloc.selectedStore` survives**, pointing at the previous user's store. The next session
   fetches against that stale `storeId`, `StoreAccessGuard` rejects it, and `mapErrorToUserMessage`
   turns the 403 into "Недостаточно прав". "Повторить" fires after the store list has refreshed to the
   new user's stores, hits the right store, and succeeds.

This also explains why the *first* login in a freshly launched app works: there is no stale store yet.

### A false lead worth recording

The API log showed **zero 403s**, which I initially presented as proof that the server never denied
anything. That was wrong, and it cost about half an hour. `grep` at the moment of two `curl` calls that
demonstrably returned 403 shows neither of them in the log. The reason is Part B below: 4xx responses
are logged nowhere. An absent log line is not evidence of an absent error.

## Part A — recreate session-scoped blocs when the session changes

**Not** by keying the root `MultiBlocProvider`. Providers must sit above the routes, the routes are built
by `MaterialApp.router`, and `AppRouter.router` is a `static final GoRouter` — so keying the root would
recreate `MaterialApp` around a long-lived router. `app.dart:83-87` already carries a comment about a
rebuild of `MaterialApp.router` resetting navigation back to splash; that is a trap this codebase has
already fallen into once.

The right insertion point is **`MaterialApp.router`'s `builder`**, which wraps the content of every
route — below the router, above the screens. It already exists, wrapping `child` with `OfflineBanner`.

- **Root keeps `AuthBloc` and `SettingsBloc`.** `AuthBloc` owns the session. `SettingsBloc` must stay
  because the `BlocBuilder<SettingsBloc>` that drives `themeMode` sits above `MaterialApp`; it is also
  the only bloc consumed above `MaterialApp`, which I verified rather than assumed.
- **The other blocs move into the `builder`**, wrapped in a `MultiBlocProvider` carrying
  `key: ValueKey(sessionKey)`.
- **`sessionKey`** is the authenticated user's id, with a distinct sentinel while unauthenticated. It is
  read from `AuthBloc`'s state via a `BlocBuilder` with a `buildWhen` that fires only when the key
  actually changes — transient `AuthLoading`/`AuthFailure` states must not churn the subtree.

When the key changes, Flutter disposes every session-scoped bloc and builds new ones. That closes the
whole class of cross-account leakage, not just the `selectedStore` symptom: the previous user's product
list, customers and finances cannot flash into the next session either.

`MaterialApp` and the `GoRouter` are never recreated, so navigation is untouched.

**Why a key rather than a reset event per bloc:** ~25 blocs would each need a Reset event, and the next
bloc anyone adds would silently miss it. A key cannot be forgotten.

## Part B — log 4xx responses

`LoggingInterceptor` logs inside `tap(() => …)`, which only runs on the **success** path; it has no
error callback. And NestJS runs guards *before* interceptors, so a guard rejection never reaches it at
all. `AllExceptionsFilter` then logs only `status >= 500`.

The result: **every 4xx is logged nowhere** — 400, 401, 403, 404, 409. For a permissions bug that is
exactly the information needed, and its absence actively misleads, as it did here.

Fix in `AllExceptionsFilter`: log 4xx at `warn` with method, url and status, no stack (a 403 is not an
exceptional condition and a stack adds noise). 5xx keeps `error` plus the stack off-production. Also
correct the comment above that block, which claims "Always log server-side" while the code does so only
for 5xx.

Deliberately **not** changing `LoggingInterceptor` — making it log errors too would double-log every
failure once the filter covers them.

## Testing

**Part B is straightforwardly testable** and gets a unit test: the filter logs a 4xx at warn level with
no stack, and still logs a 5xx at error with one.

**Part A is awkward to unit-test** and I would rather say so than write a test that looks like proof and
is not. A bloc-level test cannot observe widget-tree disposal, and a full widget test of `DukonProApp`
pulls in the router, ~25 DI registrations and network clients. What is practical:

- A widget test that pumps the keyed subtree with two different session keys and asserts the inner bloc
  instance is **not** the same object across the change — that is the actual contract, and it is
  testable in isolation from the app shell.
- Manual verification on the emulator against the two QA accounts: sign in as one, switch store, sign
  out, sign in as the other, and confirm the dashboard, Товары and Финансы render **without** any
  "Недостаточно прав". That is the reproduction that found the bug, so it is the one that proves it
  fixed.

## Verification

| Check | Expectation |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test` | failing set unchanged from the documented 18 macOS goldens |
| `dart run tool/check_i18n.dart` | exit 0, 343 files |
| `api`: `npm test`, `npx tsc --noEmit` | green, 0 errors |
| Manual re-login on both QA accounts | no "Недостаточно прав" on any screen |
| API log after a deliberate cross-store request | the 403 now appears |

## Risks

- **The `builder` runs on every route build.** The keyed `MultiBlocProvider` must be stable across
  navigation — same key, same position, so Flutter reuses the element and the blocs survive. If that
  reasoning is wrong the blocs would be recreated on every navigation, which would be far worse than the
  bug. **This must be checked explicitly during implementation**, not assumed: navigate between tabs and
  confirm state (e.g. a loaded product list) persists.
- **`SettingsBloc` staying at root** means its state also survives logout. That is intentional for
  `themeMode`, but it also carries the previous user's profile until reloaded. Acceptable, and noted so
  it is a decision rather than an oversight.
