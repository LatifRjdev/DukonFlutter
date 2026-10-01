# Session Reset on Logout, and 4xx Logging — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop every data-fetching screen showing "Недостаточно прав" after switching accounts, and make 4xx responses visible in the API log.

**Architecture:** Session-scoped blocs move out of the app-root `MultiBlocProvider` and into `MaterialApp.router`'s `builder`, wrapped in a `MultiBlocProvider` keyed on the signed-in user's id — below the router, above every screen, so changing the key disposes them all without ever rebuilding `MaterialApp` or the static `GoRouter`. Separately, `AllExceptionsFilter` starts logging 4xx at warn level.

**Tech Stack:** Flutter + flutter_bloc + go_router (`app/`), NestJS + Jest (`api/`). Android emulator `emulator-5554`; API on `:4455` under prefix `api`, served from compiled `dist/` so changes need `npm run build` plus a restart; Postgres in container `dukonpro-db` on `:5435`.

**Spec:** `docs/superpowers/specs/2026-10-01-session-reset-and-4xx-logging-design.md`

---

## Do Part B first

Part B is independent of Part A, but it is sequenced first on purpose: **it is what makes Part A's manual verification possible.** Right now a cross-store 403 is logged nowhere, so the emulator check in Task 3 would have to argue from an *absent* log line — which is exactly the reasoning that sent this investigation down a false trail for half an hour. With Part B in place the 403 is visible, so "the stale-store request stopped happening" becomes something you can see rather than infer.

## Facts established before writing this plan

Verified against the live tree; re-verify anything you rely on.

- `app/lib/app.dart:50-80` holds **26** `BlocProvider`s. `AuthBloc` is at `:52`; `SettingsBloc` at `:66-68` (created with `..add(SettingsProfileRequested())`). The other **24** move.
- **`SettingsBloc` is the only bloc consumed above `MaterialApp`** — the `BlocBuilder<SettingsBloc, SettingsState>` at `:82` drives `themeMode`. Confirmed by scanning `:81-95` for any other `BlocBuilder`/`BlocListener`.
- `_AuthLifecycleWatcher` (`:81`, defined at `:142`) calls `context.read<AuthBloc>()`, so it must stay **inside** the root provider. It is about foreground/background lifecycle, not sessions — do not repurpose it.
- The `builder:` at `app.dart:109` wraps every route's content in `MediaQuery > SafeArea > Column[OfflineBanner, Expanded(child)]`.
- **`OfflineBanner` has no bloc dependency** — it resolves `NetworkInfo`, `SyncEngine` and `SyncQueue` from `sl<>` directly, so moving providers around it is safe.
- `AuthAuthenticated` carries `final User user` (`auth_state.dart:13-18`). The other states (`AuthInitial`, `AuthLoading`, `AuthUnauthenticated`, `AuthFailure`, `AuthOtpSent`, `AuthPasswordResetSuccess`) carry no user.
- `AppRouter.router` is a `static final GoRouter` (`app_router.dart:103`), and its `redirect` reads tokens from `AuthLocalDatasource` directly — it does not depend on any bloc.
- `app.dart:8-10` already imports `auth_bloc.dart`, `auth_event.dart` **and `auth_state.dart`**, so `AuthState` and `AuthAuthenticated` are in scope for the `_sessionKeyOf` helper — no import change needed.
- `api/src/common/filters/http-exception.filter.spec.ts` **already exists**; mirror its `makeHost()` helper rather than inventing a new one.

## File structure

| File | Responsibility | Task |
|---|---|---|
| `api/src/common/filters/http-exception.filter.ts` | starts logging 4xx at warn | 1 |
| `api/src/common/filters/http-exception.filter.spec.ts` | pins 4xx-at-warn and 5xx-at-error | 1 |
| `app/lib/app.dart` | session-scoped providers move into the router builder, keyed | 2 |
| `app/test/presentation/session_scope_test.dart` | **new** — pins that a key change yields a different bloc instance | 2 |

---

## Hard constraints

- **Do NOT run `dart format`.** Dart 3.10's tall style rewrites this repo wholesale.
- **Do NOT regenerate goldens.** Neither part changes rendering; if a golden moves, find out why.
- **Do NOT hand-edit `app/lib/l10n/app_localizations*.dart`** (generated) and do not touch the ARB.
- **Do NOT modify `api/src/common/interceptors/logging.interceptor.ts`.** It logs only the success path via `tap()`, and guards reject before interceptors run. Making it log errors too would double-log every failure once the filter covers them.
- **Do NOT modify the Prisma schema** or create a migration.
- **`app/lib/app.dart` is the only Flutter source file Part A should need to change.** If you find yourself editing a bloc or a page, stop and report — that means the diagnosis was wrong.
- **`npm run lint` in `api/` is report-only** (since `4955e41`) but "lint clean" is **not achievable** — the baseline is ~3572 problems. **`npx tsc --noEmit` at 0 errors is the gate.**
- **Green tests do not imply clean types.** ts-jest let a genuine TS2769 pass while `tsc --noEmit` failed on the same file. Run `tsc` separately, every time.

---

## Task 1: Log 4xx responses

**Files:**
- Modify: `api/src/common/filters/http-exception.filter.ts:36-45`
- Modify: `api/src/common/filters/http-exception.filter.spec.ts`

- [ ] **Step 1: Read the existing spec's helper before writing anything**

```bash
cd api
awk 'NR<=60 {print NR": "$0}' src/common/filters/http-exception.filter.spec.ts
```
It defines `makeHost()` returning `{ host, response, request }`. Reuse it — do not write a second mock host.

- [ ] **Step 2: Write the failing tests**

Append to `api/src/common/filters/http-exception.filter.spec.ts`:

```ts
describe('AllExceptionsFilter — 4xx logging', () => {
  // Until this, LoggingInterceptor logged only the success path (its tap() has
  // no error callback, and guards reject before interceptors run at all), and
  // this filter logged only 5xx. So every 4xx was logged NOWHERE — 400, 401,
  // 403, 404, 409. A permissions bug then presents as an empty log, which
  // reads like "no error occurred" and sends you down a false trail.
  it('logs a 4xx at warn level, without a stack', () => {
    const filter = new AllExceptionsFilter();
    const warn = jest.spyOn(filter['logger'], 'warn').mockImplementation();
    const error = jest.spyOn(filter['logger'], 'error').mockImplementation();
    const { host } = makeHost();

    filter.catch(new ForbiddenException('You do not have access to this store'), host);

    expect(error).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledTimes(1);
    const [message, ...rest] = warn.mock.calls[0];
    expect(message).toContain('GET /api/test -> 403');
    // A 403 is an expected outcome, not an exceptional one — a stack would be
    // noise on a line that should be greppable.
    expect(rest.filter((a) => a !== undefined)).toHaveLength(0);
  });

  it('still logs a 5xx at error level, with a stack off-production', () => {
    const filter = new AllExceptionsFilter();
    const error = jest.spyOn(filter['logger'], 'error').mockImplementation();
    const { host } = makeHost();

    filter.catch(new Error('boom'), host);

    expect(error).toHaveBeenCalledTimes(1);
    const [message, stack] = error.mock.calls[0];
    expect(message).toContain('GET /api/test -> 500');
    expect(typeof stack).toBe('string');
  });

  it('does not log 2xx-shaped HttpExceptions below 400', () => {
    // Guards the boundary: the new branch must not start logging redirects.
    const filter = new AllExceptionsFilter();
    const warn = jest.spyOn(filter['logger'], 'warn').mockImplementation();
    const error = jest.spyOn(filter['logger'], 'error').mockImplementation();
    const { host } = makeHost();

    filter.catch(new HttpException('moved', HttpStatus.FOUND), host);

    expect(warn).not.toHaveBeenCalled();
    expect(error).not.toHaveBeenCalled();
  });
});
```

Add `ForbiddenException` to the existing `@nestjs/common` import at the top of the file if it is not already there.

- [ ] **Step 3: Run them and confirm the 4xx one fails**

```bash
npm test -- http-exception.filter.spec.ts
```
Expected: the 4xx test **FAILS** (`warn` called 0 times); the 5xx and boundary tests pass, since 5xx logging already exists and nothing logs a 302 today.

If the 4xx test passes here, stop — something already logs 4xx and this task's premise is wrong.

- [ ] **Step 4: Implement**

In `api/src/common/filters/http-exception.filter.ts`, replace the block at `:36-45`:

```ts
    // Always log server-side. Include stack only off-production so prod logs
    // stay terse and ops-friendly without dropping the info entirely in dev.
    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      const stack =
        exception instanceof Error ? exception.stack : String(exception);
      this.logger.error(
        `${request.method} ${request.url} -> ${status}`,
        this.isProduction ? undefined : stack,
      );
    }
```

with:

```ts
    // Log every 4xx and 5xx server-side.
    //
    // 4xx used to be logged NOWHERE: LoggingInterceptor only logs the success
    // path (its tap() has no error callback), and NestJS runs guards before
    // interceptors, so a guard rejection never reaches it at all. A 403 from
    // StoreAccessGuard therefore left no trace, and an empty log reads like
    // "nothing was denied" — which is how a cross-store access bug went
    // misdiagnosed for half an hour.
    //
    // 4xx is warn with no stack: it is an expected outcome, and a stack would
    // bury the one line you actually want to grep. 5xx keeps error + stack
    // off-production so prod logs stay terse without losing the detail in dev.
    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      const stack =
        exception instanceof Error ? exception.stack : String(exception);
      this.logger.error(
        `${request.method} ${request.url} -> ${status}`,
        this.isProduction ? undefined : stack,
      );
    } else if (status >= HttpStatus.BAD_REQUEST) {
      this.logger.warn(`${request.method} ${request.url} -> ${status}`);
    }
```

- [ ] **Step 5: Run the tests**

```bash
npm test -- http-exception.filter.spec.ts
```
Expected: all pass.

- [ ] **Step 6: Full API suite and typecheck**

```bash
npm test
npx tsc --noEmit
```
Expected: suites green, `tsc` **0 errors**. Report the counts. Do **not** run `npm run lint` expecting zero problems — see the constraints.

- [ ] **Step 7: Prove it works against the running API**

```bash
npm run build
```
Then restart the API (it serves compiled `dist/`, so a rebuild alone changes nothing), and make a request that a guard will reject:

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  "http://localhost:4455/api/stores/00000000-0000-0000-0000-000000000000/products" \
  -H "Authorization: Bearer <any valid user token>"
```
Expected: `403` (or `404`), and **the API log now contains a `WARN` line naming that method, url and status.** Before this task it contained nothing. That line is the deliverable.

- [ ] **Step 8: Commit**

```bash
git add api/src/common/filters/http-exception.filter.ts \
        api/src/common/filters/http-exception.filter.spec.ts
git commit -m "fix(api): log 4xx responses, which were logged nowhere

LoggingInterceptor logs only the success path — its tap() has no error
callback — and NestJS runs guards before interceptors, so a guard
rejection never reaches it. AllExceptionsFilter then logged only 5xx.
Every 400/401/403/404/409 therefore left no trace at all.

That is not merely a gap: an empty log reads as 'nothing was denied', and
a cross-store 403 was misdiagnosed on exactly that basis. 4xx now logs at
warn without a stack; 5xx is unchanged.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Scope the session blocs to the session

**Files:**
- Modify: `app/lib/app.dart`
- Create: `app/test/presentation/session_scope_test.dart`

- [ ] **Step 1: Write the failing test**

This test deliberately does **not** pump `DukonProApp` — that would drag in the router, 26 DI registrations and network clients, and would test the app shell rather than the contract. It pumps the keyed-subtree pattern in isolation, which is the thing that actually has to hold.

Create `app/test/presentation/session_scope_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stand-in for any session-scoped bloc. The contract under test is about
/// provider lifetime, not about any particular bloc's behaviour.
class _CounterCubit extends Cubit<int> {
  _CounterCubit() : super(0);
  void bump() => emit(state + 1);
}

/// Mirrors app.dart: a keyed MultiBlocProvider wrapping the route content,
/// sitting below the router and above every screen.
Widget _subtree(String sessionKey, void Function(_CounterCubit) capture) {
  return MaterialApp(
    home: MultiBlocProvider(
      key: ValueKey(sessionKey),
      providers: [BlocProvider(create: (_) => _CounterCubit())],
      child: Builder(
        builder: (context) {
          capture(context.read<_CounterCubit>());
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}

void main() {
  testWidgets('a session key change disposes the blocs and creates new ones', (tester) async {
    // The bug this guards: every bloc lived at the app root, above the auth
    // gate, so StoreBloc.selectedStore survived logout and the next session
    // fetched against the previous user's store — a 403 that surfaced as
    // "Недостаточно прав" on every screen.
    final seen = <_CounterCubit>[];

    await tester.pumpWidget(_subtree('user-1', seen.add));
    seen.last.bump();
    expect(seen.last.state, 1);

    await tester.pumpWidget(_subtree('user-2', seen.add));
    await tester.pump();

    expect(seen.length, greaterThanOrEqualTo(2));
    expect(identical(seen.first, seen.last), isFalse,
        reason: 'a new session must get a new bloc instance');
    expect(seen.last.state, 0, reason: 'state must not carry over');
  });

  testWidgets('the same session key keeps the same bloc instance', (tester) async {
    // The other half, and the one that matters most: MaterialApp's builder
    // runs on every route build, so the keyed provider must be STABLE across
    // navigation. If this fails, blocs are recreated on every navigation —
    // worse than the bug being fixed.
    final seen = <_CounterCubit>[];

    await tester.pumpWidget(_subtree('user-1', seen.add));
    seen.last.bump();
    await tester.pumpWidget(_subtree('user-1', seen.add));
    await tester.pump();

    expect(identical(seen.first, seen.last), isTrue,
        reason: 'same key must reuse the element, not rebuild the bloc');
    expect(seen.last.state, 1, reason: 'state must survive a rebuild');
  });
}
```

- [ ] **Step 2: Run it**

```bash
cd app
flutter test test/presentation/session_scope_test.dart
```
Expected: **both pass immediately.** This test pins Flutter's keying semantics, which the fix *relies on* — it is a guard against the design being wrong, not a red-green cycle. If the second test fails, **stop**: the whole approach is unsound and needs rethinking before any `app.dart` edit.

- [ ] **Step 3: Restructure `app.dart`**

Keep **only** `AuthBloc` and `SettingsBloc` in the root `MultiBlocProvider` (`:50-80`):

```dart
    return MultiBlocProvider(
      providers: [
        // AuthBloc owns the session and must outlive it. SettingsBloc stays
        // because the BlocBuilder driving themeMode sits above MaterialApp —
        // it is the only bloc consumed up here. Everything else is
        // session-scoped and lives in the router's builder below.
        BlocProvider(create: (_) => sl<AuthBloc>()),
        BlocProvider(
          create: (_) => sl<SettingsBloc>()..add(SettingsProfileRequested()),
        ),
      ],
```

Add a top-level helper above `class DukonProApp`:

```dart
/// Identity of the current session, used to key the session-scoped providers.
///
/// Returns the signed-in user's id, or a sentinel while signed out. Changing
/// it disposes every session-scoped bloc, which is what stops one account's
/// data — most damagingly StoreBloc.selectedStore — leaking into the next.
String _sessionKeyOf(AuthState state) =>
    state is AuthAuthenticated ? 'user:${state.user.id}' : 'anonymous';
```

Then move the other **24** providers into the `builder:` at `:109`, wrapping the existing subtree:

```dart
            builder: (context, child) {
              // Session-scoped providers live HERE, not at the root: they must
              // sit above every screen but below MaterialApp, because
              // AppRouter.router is a `static final GoRouter` and rebuilding
              // MaterialApp.router resets navigation to splash (see the
              // buildWhen comment above, which exists for that reason).
              //
              // MaterialApp's builder runs on every route build, so the key
              // must be STABLE across navigation — same key and position means
              // Flutter reuses the element and the blocs survive. That is
              // pinned by test/presentation/session_scope_test.dart.
              return BlocBuilder<AuthBloc, AuthState>(
                buildWhen: (prev, curr) =>
                    _sessionKeyOf(prev) != _sessionKeyOf(curr),
                builder: (context, authState) {
                  return MultiBlocProvider(
                    key: ValueKey(_sessionKeyOf(authState)),
                    providers: [
                      BlocProvider(create: (_) => sl<StoreBloc>()),
                      BlocProvider(create: (_) => sl<CartBloc>()),
                      BlocProvider(create: (_) => sl<DashboardBloc>()),
                      BlocProvider(create: (_) => sl<ProductListBloc>()),
                      BlocProvider(create: (_) => sl<ProductFormBloc>()),
                      BlocProvider(create: (_) => sl<CategoryBloc>()),
                      BlocProvider(create: (_) => sl<CheckoutBloc>()),
                      BlocProvider(create: (_) => sl<SalesHistoryBloc>()),
                      BlocProvider(create: (_) => sl<StockIntakeBloc>()),
                      BlocProvider(create: (_) => sl<FinanceBloc>()),
                      BlocProvider(create: (_) => sl<ExpenseBloc>()),
                      BlocProvider(create: (_) => sl<DebtBloc>()),
                      BlocProvider(create: (_) => sl<ZakatBloc>()),
                      BlocProvider(create: (_) => sl<CustomerDetailBloc>()),
                      BlocProvider(create: (_) => sl<CustomerListBloc>()),
                      BlocProvider(create: (_) => sl<SupplierListBloc>()),
                      BlocProvider(create: (_) => sl<StaffBloc>()),
                      BlocProvider(create: (_) => sl<RolesBloc>()),
                      BlocProvider(create: (_) => sl<ShiftBloc>()),
                      BlocProvider(create: (_) => sl<PayrollBloc>()),
                      BlocProvider(create: (_) => sl<StaffFormBloc>()),
                      BlocProvider(create: (_) => sl<PrinterBloc>()),
                      BlocProvider(create: (_) => sl<SubscriptionBloc>()),
                      BlocProvider(create: (_) => sl<LoyaltySettingsBloc>()),
                    ],
                    child: MediaQuery(
                      data: MediaQuery.of(context),
                      child: SafeArea(
                        top: false,
                        bottom: false,
                        child: Column(
                          children: [
                            const OfflineBanner(),
                            Expanded(child: child ?? const SizedBox.shrink()),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
```

Count them: **24** providers moved, `AuthBloc` and `SettingsBloc` stay. If your moved list has a different length, you dropped or duplicated one — `flutter analyze` will not always catch a missing provider, but the first screen that needs it will throw at runtime.

- [ ] **Step 4: Analyze and run the scoped test**

```bash
flutter analyze
flutter test test/presentation/session_scope_test.dart
```
Expected: `No issues found!` and both tests pass.

- [ ] **Step 5: Full Flutter suite**

```bash
flutter test 2>&1 | grep -oE '[a-zA-Z_]+_test\.dart: [^\[]*\[E\]' | sed 's/ *\[E\]//' | sort -u
```
Expected: exactly the documented **18** pre-existing macOS golden failures — `balance_page`, `create_delivery_page`, `credits_page`, `currencies_page`, `delivery_detail_page`, `delivery_list_page`, `discounts_page`, `my_stores_page`, `reports_page`, each light and dark. **Compare the sorted set, never the count.** Any new name means the restructure broke a widget test — investigate rather than regenerating anything.

- [ ] **Step 6: i18n lint**

```bash
dart run tool/check_i18n.dart; echo "EXIT=$?"
```
Expected: `scanned 343 files`, `EXIT=0`. Run it unpiped — a pipe masks the exit code.

- [ ] **Step 7: Commit**

```bash
git add app/lib/app.dart app/test/presentation/session_scope_test.dart
git commit -m "fix(app): scope session blocs to the session, not the app

All 26 blocs were provided at the app root, above the auth gate, and
nothing reset them on logout — StoreBloc has no logout handling and
nothing in the app listens for AuthUnauthenticated. So selectedStore kept
pointing at the previous user's store; the next session fetched against
that stale id, StoreAccessGuard returned 403, and mapErrorToUserMessage
rendered it as 'Недостаточно прав' on the dashboard, Товары and Финансы.
Only the first login after a cold start worked, because there was no
stale store yet.

24 of them now live in MaterialApp.router's builder behind a
MultiBlocProvider keyed on the user id — below the router so MaterialApp
and the static GoRouter are never rebuilt (app.dart already documents
that rebuilding MaterialApp.router resets navigation to splash), and
above every screen. AuthBloc and SettingsBloc stay at the root;
SettingsBloc because the themeMode BlocBuilder sits above MaterialApp.

A key cannot be forgotten the way a per-bloc reset event can, and it
closes the whole class: no bloc can leak one account's data into the next.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Verify on the emulator

**Files:** none modified unless a defect is found.

This is where the fix is actually proven. The unit tests pin the keying contract; only the emulator shows the bug is gone.

- [ ] **Step 1: Build and install**

```bash
cd app
flutter run -d emulator-5554
```
Leave it attached. If no device is listed, use `flutter devices --device-timeout 15` — the default timeout is too short here and reports "no devices" on a machine that has three.

- [ ] **Step 2: Confirm the keyed provider is stable across navigation — the critical check**

**This is the one assumption that would make things worse if wrong.** `MaterialApp`'s `builder` runs on every route build; if the keyed provider is not stable, every navigation recreates all 24 blocs.

Sign in as BUSINESS (`+992920777001` / `x8R9s5msWiEzBYWL`), open **Товары** and let it load, then switch to **Финансы** and back to **Товары**.

Expected: the Товары list is still populated and does **not** flash a loading spinner. Cross-check against the API log — there must be **no second** `GET /api/stores/<id>/products` for the return visit. A refetch on every tab switch means the key is unstable; stop and report rather than continuing.

- [ ] **Step 3: Reproduce the original bug path**

Still signed in as BUSINESS, switch the active store via the header selector (this account owns two: "QA Второй магазин" and "QA Магазин Бизнес"), then sign out via Ещё → Настройки → Выйти из аккаунта.

- [ ] **Step 4: Sign in as the other account and check every screen**

Sign in as PREMIUM (`+992920777002` / `yfgYAi5oHqm38w8x`).

Expected, with **no** "Недостаточно прав" and **no** manual "Повторить" anywhere:
- the dashboard renders its figures
- **Товары** renders (empty-state is fine — the accounts have no products)
- **Финансы** renders its sections

Then check the API log for the burst after login: every request must carry the **new** user's store id. A request naming the previous session's store is the bug still present, even if the screen happens to render.

- [ ] **Step 5: Repeat in the other direction**

Sign out, sign back in as BUSINESS, and check the same three screens. The bug appeared from the *second* login onward, so one direction alone does not prove much.

- [ ] **Step 6: Confirm navigation still works**

Walk Главная → Товары → Касса → Финансы → Ещё → Настройки and back. Expected: no resets to splash, no lost state. This is the regression the `MaterialApp.router` comment warns about, and the reason the providers went into the builder rather than the root.

- [ ] **Step 7: Report**

State plainly whether Steps 2, 4 and 5 passed. **If Step 2 failed, the fix is not acceptable** regardless of the rest — recreating every bloc on every navigation is worse than the bug.

- [ ] **Step 8: Commit only if something needed fixing**

If Steps 1-7 are clean there is nothing to commit and this task ends. Otherwise fix, re-run Tasks 2 and 3, and commit with a message naming what was wrong.

---

## Notes for the executor

- **The empty-log trap is the real lesson here.** This bug took far longer than it should have because an absent log line was read as proof that no error occurred. Task 1 exists to make that failure mode impossible next time; do not skip its Step 7, which is what actually proves the log line appears.
- **Do not "simplify" the key into a bool.** `isAuthenticated` would not change when switching directly from one account to another, which is precisely the case that breaks. The key must be the user's identity.
- **`buildWhen` is load-bearing.** Without it, every `AuthLoading`/`AuthFailure` emission rebuilds the subtree — and since the key would be unchanged the blocs would survive, so it would not be *wrong*, just wasteful. With it, the subtree rebuilds only when the session genuinely changes.
- **If a screen throws "Could not find the correct Provider" at runtime**, a bloc was dropped during the move. Compare the moved list against `git show HEAD~1:app/lib/app.dart` and count.
- **Out of scope by decision:** `SettingsBloc` staying at the root means its state, including the previous user's profile, survives logout until reloaded. Intentional, so `themeMode` does not flash on every sign-out.
