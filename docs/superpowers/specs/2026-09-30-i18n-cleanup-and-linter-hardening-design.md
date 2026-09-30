# Post-Track-2b Cleanup and Linter Hardening — Design

**Date:** 2026-09-30
**Status:** Approved
**Predecessor:** ADR-0002 Track 2b (merged `3f8b37a`, PR #73)
**Sub-projects covered:** C (dead code and dead strings), D (linter hardening)

## Goal

Close the two cheapest independent items left open after Track 2b: delete code and strings that are
provably unreachable, and replace the i18n lint's line-based regex scanner with an AST-based one that
closes all four of its known gaps.

Neither half changes user-visible behaviour. That shared property is the spec boundary, and it gives one
hard verification criterion: **the 18-failure macOS golden baseline must not move, and no translatable
ARB value may change.**

## Why these two together

They are independent of each other but share a verification story, and both are prerequisites for
trusting the work that follows. Sub-projects B1 (the error path) and B2 (Track 3's Bloc strings) will add
new user-facing strings inside Blocs and state classes — precisely the code the lint has to police. A
scanner that can be evaded silently is weak infrastructure for that, and dead strings in the error layer
make the error path harder to reason about than it needs to be.

## Out of scope

- **B1** — the non-context localization mechanism and `error_messages.dart`'s 11 strings. Needs its own
  design: 125 call sites across 50 files, 43 state classes carrying `final String message`, 98 UI
  `.message` reads.
- **B2** — Track 3's 19 Bloc strings (mostly success toasts; 7 interpolate).
- **E** — ARB hygiene: 6 duplicate-value key groups, 3 screen-prefixed keys to promote, 4 generic keys
  parked in feature blocks, 88 dead keys, the two golden tests that hand-compose private widget copies.
- **Logging.** The app has no logger. `error_messages.dart`'s comment advises logging the caught
  exception "via the bloc's logger", but no logger exists and no Bloc logs anything. Introducing one is
  its own sub-project with its own PII questions (`.claude/rules/security.md` forbids logging tokens and
  PII). This spec documents the gap rather than filling it.

---

## Part C — Dead code and dead strings

### C1. Delete `CurrencyRemoteDatasource` entirely

**Evidence it is unreachable, and worse than unreachable:**

1. `grep -rn CurrencyRemoteDatasource lib test` returns only its own file, the DI registration at
   `lib/injection.dart:264`, and its test. `sl<CurrencyRemoteDatasource>()` has **zero** resolution
   sites; `getLatestRates`/`getRateHistory` are never called outside the file and its test.
2. **Its endpoints do not exist.** The datasource calls `/currencies/latest-rates` and
   `/currencies/rate-history`. The backend controller
   (`api/src/modules/currencies/currencies.controller.ts`) declares `@Get('rates')` and
   `@Get('rates/history')`. `lib/presentation/pages/finance/currencies_page.dart` calls
   `/currencies/rates` (line 118) and `/currencies/rates/history` (line 152) — the page is correct and
   the datasource is broken.
3. Its test passes only because `DioClient` is mocked, so it never exercised the wrong paths. This is a
   test that validated nothing about reality; deleting it removes a false signal, not coverage.
4. The page defines its own `_CurrencyRate` (`currencies_page.dart:17`) and its own flag map
   (`:29-33`) with a better fallback (`'🏳️'`) than the datasource's `''`. Nothing is lost.

**Delete:**
- `app/lib/data/datasources/remote/currency_remote_datasource.dart` — the whole file: `CurrencyRate`,
  `CurrencyRateHistory`, the abstract class, `CurrencyRemoteDatasourceImpl`, and the `_flags` map.
- The DI registration at `app/lib/injection.dart:264`.
- `app/test/data/datasources/remote/currency_remote_datasource_test.dart`.

**Explicitly not done here:** the page's direct `sl<DioClient>()` usage bypasses the
repository/datasource layering the project's own rules prescribe (`.claude/rules/api-integration.md`).
Fixing that means writing a *working* datasource plus a repository and wiring the page to a Bloc — a
feature-shaped change, not cleanup. Deleting the broken class does not make that worse; it removes a
decoy that looks like the layer already exists.

### C2. Document `message` on the exception types as diagnostic-only

`app/lib/core/errors/exceptions.dart` declares `final String message` on all four exception types.
It is **written at 108 construction sites and read nowhere** — `mapErrorToUserMessage` dispatches on
runtime type and `statusCode` only, and discards it.

Keep the field. Six of those 108 sites pass a genuine server-supplied message
(`e.response?.data?['message']`), so the field is capturing real diagnostic data that a future logger
would want. Deleting it would touch 108 sites to destroy information.

Add a dartdoc to each of the four classes (or one shared comment) recording three facts: the field is
never shown to a user; `mapErrorToUserMessage` discards it, dispatching on type and status; and no
logger currently consumes it, so today it is write-only. Anyone tempted to render it in the UI or to
delete it as dead needs all three.

### C3. Convert `debt_repository_impl.dart`'s three Russian literals to English

Because the field is diagnostic-only, Russian text in it is misleading — it looks user-facing and is
allowlisted as if deferred, when in fact it can never reach a screen. English matches the defaults
already present in `exceptions.dart` (`'No internet connection'`, `'Unauthorized'`).

| Line | Current | Becomes |
|---|---|---|
| 94 | `const NetworkException('Нет соединения')` | `const NetworkException('No connection')` |
| 98 | `const ServerException('Ошибка сервера')` | `const ServerException('Server error')` |
| 100 | `... ?? 'Не удалось выполнить операцию'` | `... ?? 'Operation failed'` |

Line 100 is the fallback for a server-supplied `e.response?.data?['message']`; only the fallback text
changes, not the preference for the server's own message.

Then remove the three now-unnecessary allowlist lines. Allowlist block 3 goes from 13 entries to 10 —
the 10 remaining are `error_messages.dart`'s, which stay deferred to B1. All three removed entries are
single-occurrence, so this is a straight −3; Part D then adds 5 duplicate lines under the multiset rule,
for a net 48 → 50. Update block 3's own inline comment, which currently states "13 entries here cover 14
occurrences" — after C3 it is 10 covering 11.

---

## Part D — Rewrite the lint on `package:analyzer`

### Current state

`app/tool/check_i18n.dart` (142 lines) reads each file line by line and applies the regex
`['"][^'"]*[Ѐ-ԯ][^'"]*['"]` with `allMatches`, skipping lines whose trimmed form starts with `//`.
It scans 344 files (all of `lib` except `lib/l10n/`) and is enforced in CI
(`.github/workflows/ci.yml:128`).

All four of its known gaps are consequences of being line-based and regex-based:

| # | Gap | Current exposure |
|---|---|---|
| 1 | One `path::literal` allowlist entry whitelists *unlimited* occurrences of that literal in that file | 5 of 48 entries legitimately cover 2 occurrences each; nothing detects a 3rd appearing |
| 2 | The comment guard only skips lines *beginning* with `//`, so a trailing `foo(); // 'Пример'` false-positives | zero — verified no Cyrillic in any trailing or block comment across all 344 files |
| 3 | Continuation lines inside `'''…'''` carry no quote character, so they are invisible | zero — all 30 `'''` occurrences are SQL DDL in `lib/data/datasources/local/` |
| 4 | `lib/l10n/` is skipped by *directory*, so a hand-written helper placed there would never be scanned | zero — the directory holds only generated `app_localizations*.dart` and the three ARBs |

Gap 2 cannot be fixed properly by patching the regex: you cannot cut a line at its first `//` without
breaking literals that legitimately contain `//` (URLs). Gap 3 cannot be fixed line-by-line at all.
Both dissolve if the scanner understands Dart syntax.

### Approach

Add `analyzer` to `app/pubspec.yaml`'s `dev_dependencies`. It is already present in `pubspec.lock` as a
transitive dependency of `flutter_lints`, so this is a declaration rather than a new download.

Parse each file with `parseString(content: ..., throwIfDiagnostics: false)` and walk the AST with a
`RecursiveAstVisitor`, overriding the three string node types:

- `visitSimpleStringLiteral` — `'…'`, `"…"`, `r'…'`, and `'''…'''` alike, each a single node
- `visitAdjacentStrings` — `'a' 'b'` juxtaposition
- `visitStringInterpolation` — `'… ${expr} …'`

Report a node when its source contains a character in `[Ѐ-ԯ]`. Comments are not AST nodes of these
types and are never visited, so **gap 2 closes structurally** rather than by a guard that has to be
maintained. A `'''…'''` literal is one node regardless of how many source lines it spans, so **gap 3
closes structurally** too.

### Allowlist key compatibility — a hard requirement

The allowlist key stays `<path>::<node source>`, and all 48 existing entries must keep matching without
edits. This is verified, not assumed:

- For a simple literal, `node.toSource()` yields the source text including its quotes — byte-identical
  to what the regex captured. Example: `'сом.'`.
- 5 entries are interpolations (`printer_bloc.dart`'s `'Ошибка печати: ${mapErrorToUserMessage(e)}'` and
  four siblings). A `StringInterpolation` node's `toSource()` yields the full original text including
  `${…}`, again identical to the regex capture.
- Raw strings are the one place the two could disagree: the regex captures from the first quote and so
  drops an `r` prefix, whereas `toSource()` keeps it. **There are currently zero Cyrillic-bearing raw
  strings anywhere in `lib`**, so no existing entry is affected. The implementation should still key on
  `toSource()` (the honest representation) and the plan must include a test pinning the behaviour for
  `r'…'` so the choice is deliberate rather than accidental.

A migration that silently rewrote allowlist entries would defeat the point, so the plan verifies all 48
keys resolve unchanged before anything else is judged.

### Gap 1 — occurrence counting

Make the allowlist a **multiset**: a `path::literal` line repeated N times permits exactly N
occurrences of that literal in that file. Report when the actual count exceeds the permitted count.

This needs no format change and no new syntax. 43 of the 48 current entries are single-occurrence and
stay exactly as they are; the 5 that legitimately cover 2 occurrences each gain a duplicate line. The
count is self-documenting — the number of identical lines *is* the permitted count.

The 5 entries needing a duplicate, measured 2026-09-30:

```
lib/core/errors/error_messages.dart::'Не удалось выполнить операцию'
lib/presentation/blocs/subscription/subscription_bloc.dart::'Заявка отправлена, ожидайте подтверждения'
lib/presentation/pages/settings/subscription_page.dart::'Бизнес'
lib/presentation/pages/settings/subscription_page.dart::'Премиум'
lib/presentation/pages/settings/subscription_page.dart::'Старт'
```

Count these from the tool's own output during implementation rather than trusting this list — the
adjacent figure in this project's history has been wrong twice (a "13 lines for 14 occurrences" claim
that was really 14 for 15, and a "53 literals" count that was 57). If the implementation finds a number
other than 5, the discrepancy is the finding.

Rejected alternative: a `path::literal::count` third field. It would require deciding whether the field
is optional, and a missing count would have to mean either "1" or "unlimited" — both surprising.
Repetition has no such ambiguity.

### Gap 4 — narrow the `lib/l10n` exclusion

Replace the `rel.startsWith('lib/l10n/')` directory skip with a filename match on
`app_localizations*.dart`. Generated output is excluded because it is generated, not because of where it
sits; a hand-written helper in that directory should be scanned like any other file.

This exclusion is heavily load-bearing and must not be widened by accident: with it removed, the lint
reports **3186** offenders.

### Parse failures must be a hard error

`throwIfDiagnostics: false` keeps a file with syntax errors from crashing the tool — but the file would
then contribute **zero** string nodes and pass silently. That would be a worse blind spot than any of
the four being closed, because it would be invisible and would scale with however many files failed.

Any file whose parse produces errors must make the tool report that file and exit non-zero, with a
message distinguishing "this file could not be parsed" from "this file contains hardcoded strings". The
count of successfully scanned files must remain in the output so a sudden drop is visible.

### Performance

Parsing 344 files is more work than 344 regex sweeps. `parseString` does syntactic parsing only — no
resolution, no summaries — so the expected cost is low, but it must be **measured** and reported rather
than assumed. If wall-clock time on the full `lib` tree exceeds roughly 10 seconds the result should be
reported as a finding, since the tool runs on every CI push and in the pre-commit path.

---

## Testing

**The 9 existing tests in `app/test/tool/check_i18n_test.dart` must pass unmodified.** They assert exit
codes and scan behaviour through the public `run(args, {repoRootOverride})` entry point, not
implementation internals, so they are the primary regression net for the rewrite. If any existing test
needs editing to accommodate the new scanner, that is a signal the rewrite changed observable behaviour
and needs justification — not a licence to edit the test.

**New tests, one per closed gap, each proven to FAIL against the current regex implementation.** A guard
that passes before the fix proves nothing; this project has already shipped one vacuous regression test
(a Tajik-character case whose literal also contained base-range Cyrillic, so the old regex already
matched it) and the mistake is cheap to repeat. Required cases:

1. **Occurrence counting** — a literal appearing 3 times in a file with 2 allowlist lines must fail;
   with 3 lines it must pass.
2. **Trailing comment** — `foo(); // 'Пример'` must NOT be reported.
3. **Multi-line string** — a `'''…'''` literal whose Cyrillic sits on a continuation line, with no quote
   on that line, must be reported.
4. **`lib/l10n` narrowing** — a hand-written file in `lib/l10n/` must be scanned; `app_localizations_ru.dart`
   must still be excluded.
5. **Parse failure** — a file with a syntax error must cause a non-zero exit naming that file, not a
   silent pass.
6. **Allowlist key compatibility** — every one of the 48 committed entries resolves against the real
   `lib` tree unchanged.
7. **Raw string keying** — pins whether `r'Привет'`'s key includes the `r` prefix, so the decision is
   deliberate.

**Non-vacuity probe**, as used in Track 2b: append a Cyrillic literal to a file in `lib/core`, confirm
the lint exits 1 naming that file, restore, confirm exit 0. Run unpiped — a pipe masks the exit code.

## Verification

| Check | Expectation |
|---|---|
| `flutter analyze` | `No issues found!` |
| `dart run tool/check_i18n.dart` | exit 0, and the scanned-file count still **344**: `lib` holds 348 `.dart` files, the 4 under `lib/l10n/` are all generated and all match `app_localizations*.dart`, so narrowing the skip from directory to filename excludes exactly the same 4 files today. The count changing is itself a finding. |
| `flutter test` | the failing **set** identical to the documented 18 macOS goldens — compared as a set, never as a count |
| ARB | no translatable value changed; `flutter gen-l10n` produces no diff |
| Allowlist | **48 → 50 lines**: minus 3 removed by C3 (`debt_repository_impl.dart`'s literals, all single-occurrence), plus 5 duplicates added by the multiset rule. Entry lines going *up* is expected here — the file gets longer while becoming stricter. |
| `injection.dart` | one registration removed; app still builds and `flutter analyze` stays clean |

Golden images must not be regenerated. If a golden moves, something in this spec's "no user-visible
change" premise is wrong and the cause must be found rather than the baseline updated.

## Risks

- **The rewrite is the risk.** C is three small deletions with compiler-checked consequences; D replaces
  working, CI-green infrastructure. The mitigation is that the 9 existing tests are behavioural and must
  pass untouched, and that the 48-key compatibility check runs against the real tree.
- **A silently narrower scan.** The failure mode that would matter most is the new scanner reporting
  success because it examined less than it should. Two guards: the scanned-file count stays in the
  output and is asserted, and parse failures are hard errors.
- **Scope creep toward B1.** `error_messages.dart` is adjacent to everything in Part C and stays
  untouched; its 10 allowlist entries must survive this work unchanged.
