# Post-Track-2b Cleanup and Linter Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete code and strings that are provably unreachable, and replace the i18n lint's line-based regex scanner with an AST-based one that closes all four of its known gaps.

**Architecture:** Two independent halves. Part C (Tasks 1–3) is deletion and documentation with compiler-checked consequences. Part D (Tasks 4–7) replaces `tool/check_i18n.dart`'s regex with `package:analyzer`, so that comment handling and multi-line literals stop being special cases and become structural properties of parsing Dart. Task 8 verifies the whole branch.

**Tech Stack:** Dart 3.10.4, Flutter, `package:analyzer` 7.7.1 (already in `pubspec.lock` transitively via `flutter_lints`).

**Spec:** `docs/superpowers/specs/2026-09-30-i18n-cleanup-and-linter-hardening-design.md`

---

## Facts established before writing this plan

These were verified against the live tree and the analyzer API. Do not re-derive them from memory, but *do* re-verify any number before you rely on it — this project has shipped two off-by-one count claims already.

- `lib` held **348** `.dart` files when this plan was written, of which **4** are under `lib/l10n/` (`app_localizations.dart`, `app_localizations_ru.dart`, `app_localizations_tg.dart`, `app_localizations_uz.dart` — all generated), giving a scanned count of **344**.
  **Task 1 deletes one file, so from Task 2 onward the tree is 347 `.dart` files and the scanned count is 343.** Tasks 4, 7 and 8 below assert **343**. If you are running Task 4+ and see 344, Task 1's deletion did not land; if you see anything else, a file was added or removed and that is the finding.
- `tool/i18n-allowlist.txt` has **48** entry lines (non-blank, non-`#`).
- **5** of those 48 cover 2 occurrences each and will each need a duplicate line under the multiset rule.
- The four exception classes' `message` field is written at **108** construction sites and read **nowhere**.
- The current tool skips lines whose trimmed form starts with `//`, `debugPrint(`, `log(`, or `print(`. The diagnostic-call part of that guard currently suppresses **zero** literals in `lib` — verified by scanning all 344 files.
- Analyzer API, verified by running a probe against 7.7.1:
  - `parseString(content: ..., throwIfDiagnostics: false).errors` is populated and non-deprecated. `parseString` does no resolution, so any entry in `.errors` is a genuine syntax error — `errors.isNotEmpty` is a sufficient test, and no `Severity` import is needed.
  - `SimpleStringLiteral.toSource()` on `r'Мир'` returns `r'Мир'` — **including** the `r`. The old regex began matching at the first quote and dropped it. There are zero Cyrillic-bearing raw strings in `lib` today, so no committed entry is affected, but the difference must be pinned by a test.
  - A `'''…'''` literal is a single `SimpleStringLiteral` node regardless of how many source lines it spans.
  - `'аб' 'вг'` is one `AdjacentStrings` node; `toSource()` returns `'аб' 'вг'`.
  - `StringInterpolation.toSource()` returns the full original text including `${…}` — byte-identical to what the old regex captured for `'Ошибка печати: ${mapErrorToUserMessage(e)}'`.
  - For `'${cond ? "Да" : "Нет"}'`, the concatenated `InterpolationString` parts are **empty**. This is why Task 4 reports an interpolation only when its *literal chunks* carry Cyrillic: the old regex reported `"Да"` and `"Нет"` individually for this shape, and matching that keeps keys stable.

## File structure

| File | Responsibility | Task |
|---|---|---|
| `app/lib/data/datasources/remote/currency_remote_datasource.dart` | **deleted** — broken and unreachable | 1 |
| `app/lib/injection.dart` | DI registration removed | 1 |
| `app/test/data/datasources/remote/currency_remote_datasource_test.dart` | **deleted** — tested a mocked client against nonexistent endpoints | 1 |
| `app/lib/core/errors/exceptions.dart` | documents `message` as diagnostic-only | 2 |
| `app/lib/data/repositories/debt_repository_impl.dart` | diagnostic strings become English | 3 |
| `app/tool/i18n-allowlist.txt` | 3 entries removed, 5 duplicated, preamble updated | 3, 6 |
| `app/pubspec.yaml` | declares `analyzer` | 4 |
| `app/tool/check_i18n.dart` | AST scanner replacing the regex | 4, 5, 6, 7 |
| `app/test/tool/check_i18n_test.dart` | 9 existing tests unchanged + 8 new | 4, 5, 6, 7 |

---

## Hard constraints — read before touching anything

- **Do NOT run `dart format`.** Dart 3.10's tall style rewrites this repo wholesale (measured: 385 lines on one file; the repo is ~55:1 old-style). It would bury the change. If a tool or habit runs it, revert and reapply by hand.
- **Do NOT regenerate any golden `.png`.** Neither half of this work changes user-visible output. If a golden moves, the premise is wrong — find the cause, do not update the baseline.
- **Do NOT hand-edit `app/lib/l10n/app_localizations*.dart`** — generated by `flutter gen-l10n`.
- **`app/lib/core/errors/error_messages.dart` stays untouched** and its 10 allowlist entries must survive unchanged. It is deferred to sub-project B1.
- **18 pre-existing macOS golden failures** are expected — a tolerance difference vs Linux CI, not a regression. Always compare the failing **set**, never the count. The 9 pages are `my_stores`, `discounts`, `create_delivery`, `delivery_list`, `delivery_detail`, `credits`, `balance`, `reports`, `currencies`, each light + dark.

---

## Task 1: Delete `CurrencyRemoteDatasource`

**Files:**
- Delete: `app/lib/data/datasources/remote/currency_remote_datasource.dart`
- Delete: `app/test/data/datasources/remote/currency_remote_datasource_test.dart`
- Modify: `app/lib/injection.dart` (registration near line 264)

- [ ] **Step 1: Re-confirm it is unreachable before deleting anything**

```bash
cd app
grep -rn "CurrencyRemoteDatasource" lib test
grep -rn "sl<CurrencyRemoteDatasource>" lib test
```
Expected: the first prints only the datasource file itself, one line in `lib/injection.dart`, and the test file. The second prints **nothing**.

If either shows a real consumer, STOP — the premise is wrong and this task needs rethinking rather than forcing.

- [ ] **Step 2: Re-confirm its endpoints do not exist**

```bash
cd ..
grep -rn "@Get(" api/src/modules/currencies/currencies.controller.ts
grep -n "dio.get\|_dioClient.get" app/lib/presentation/pages/finance/currencies_page.dart app/lib/data/datasources/remote/currency_remote_datasource.dart
```
Expected: the controller declares `@Get('rates')` and `@Get('rates/history')`. The page calls `/currencies/rates` and `/currencies/rates/history` (correct); the datasource calls `/currencies/latest-rates` and `/currencies/rate-history` (both 404).

This is the real justification for deletion — "unused" alone would leave open the option of wiring it up, and wiring up a class that calls nonexistent endpoints would be worse than deleting it.

- [ ] **Step 3: Confirm the page does not depend on the deleted flag map**

```bash
grep -n "flags\|🇺🇸" app/lib/presentation/pages/finance/currencies_page.dart
```
Expected: the page defines its own `flags` map around lines 29–33 with a `'🏳️'` fallback. The datasource's `_flags` had a `''` fallback, so nothing is lost.

- [ ] **Step 4: Delete the two files**

```bash
cd app
git rm lib/data/datasources/remote/currency_remote_datasource.dart
git rm test/data/datasources/remote/currency_remote_datasource_test.dart
```

- [ ] **Step 5: Remove the DI registration**

Open `app/lib/injection.dart`, find the registration (near line 264) and delete it. It looks like:

```dart
  sl.registerLazySingleton<CurrencyRemoteDatasource>(
    () => CurrencyRemoteDatasourceImpl(dioClient: sl()),
  );
```

Also delete the now-unused `import` of `currency_remote_datasource.dart` at the top of the file. `flutter analyze` will name both if you miss one.

- [ ] **Step 6: Verify the compiler agrees nothing referenced it**

```bash
flutter analyze
```
Expected: `No issues found!`

This is the safety property that makes the deletion trustworthy — had any consumer existed, this would be a build error rather than a silent behaviour change.

- [ ] **Step 7: Run the test suite and compare the failing set**

```bash
flutter test 2>&1 | tail -3
```
Expected: `-18` failures, and the failing set is the documented 18 goldens. `currencies_page` is among them and was already failing before this task, so it proves nothing either way here — that is expected, not a problem.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor(data): delete the broken, unreachable CurrencyRemoteDatasource

It had zero resolution sites, and its two endpoints do not exist:
it called /currencies/latest-rates and /currencies/rate-history while
the backend serves rates and rates/history. currencies_page.dart already
calls the correct paths and has its own flag map. Its test passed only
because DioClient was mocked, so it validated nothing about reality."
```

---

## Task 2: Document `message` as diagnostic-only

**Files:**
- Modify: `app/lib/core/errors/exceptions.dart`

- [ ] **Step 1: Re-confirm the field is never read**

```bash
cd app
grep -rn "ServerException\|CacheException\|NetworkException\|UnauthorizedException" lib --include="*.dart" | grep "\.message"
grep -n "\.message" lib/core/errors/error_messages.dart
```
Expected: the first prints only the four constructor declarations in `exceptions.dart`. The second prints **nothing** — `mapErrorToUserMessage` dispatches on runtime type and `statusCode` and never reads the field.

- [ ] **Step 2: Count the construction sites, so the comment's claim is accurate**

```bash
grep -rn "ServerException(\|CacheException(\|NetworkException(\|UnauthorizedException(" lib --include="*.dart" | grep -v "lib/core/errors/exceptions.dart" | wc -l
```
Expected: `108`. If the number differs, use the number you measured in the comment below rather than the one written here.

- [ ] **Step 3: Replace the file contents**

Write `app/lib/core/errors/exceptions.dart`:

```dart
/// Exception types thrown by the data layer.
///
/// **The `message` field on every type below is diagnostic-only — it is never
/// shown to a user.** Three facts are worth knowing before you render it, log
/// it, or delete it as dead:
///
/// 1. `mapErrorToUserMessage` (lib/core/errors/error_messages.dart) is the only
///    thing that turns these into user-facing text, and it dispatches purely on
///    runtime type and [ServerException.statusCode]. It never reads `message`.
/// 2. The field is written at 108 construction sites and read at none. Six of
///    those sites pass a genuine server-supplied string
///    (`e.response?.data?['message']`), so it is capturing real diagnostic
///    detail — which is why it is kept rather than deleted.
/// 3. There is no logger consuming it. The app has no logging infrastructure at
///    all, so today the field is write-only. Introducing one is tracked
///    separately and has its own PII constraints (see .claude/rules/security.md,
///    which forbids logging tokens and PII).
///
/// Consequence for i18n: text in this field must NOT be translated, and must
/// not be treated as deferred UI copy. English is correct here.
class ServerException implements Exception {
  final String message;
  final int? statusCode;
  const ServerException(this.message, {this.statusCode});
}

class CacheException implements Exception {
  final String message;
  const CacheException(this.message);
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'No internet connection']);
}

class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'Unauthorized']);
}
```

Note the class bodies are byte-identical to the current file. Only the leading dartdoc is new.

- [ ] **Step 4: Verify nothing changed behaviourally**

```bash
flutter analyze
git diff --stat lib/core/errors/exceptions.dart
```
Expected: `No issues found!`, and the diff shows insertions only — zero deletions other than any whitespace you touched. If a line inside a class body changed, you edited too much.

- [ ] **Step 5: Commit**

```bash
git add lib/core/errors/exceptions.dart
git commit -m "docs(errors): record that exception message is diagnostic-only

Written at 108 sites, read at none: mapErrorToUserMessage dispatches on
runtime type and statusCode and discards it, and no logger consumes it.
Documenting this is what makes the next commit's English text correct
rather than an untranslated regression."
```

---

## Task 3: Convert `debt_repository_impl.dart`'s three literals to English

**Files:**
- Modify: `app/lib/data/repositories/debt_repository_impl.dart` (lines 94, 98, 100)
- Modify: `app/tool/i18n-allowlist.txt`

- [ ] **Step 1: Read the three sites and confirm they are exception arguments**

```bash
cd app
sed -n '88,104p' lib/data/repositories/debt_repository_impl.dart
```
Expected: three Cyrillic literals, each an argument to a `NetworkException` / `ServerException` constructor — i.e. the field Task 2 just documented as never user-visible. Line 100 is a `??` fallback for a server-supplied message.

- [ ] **Step 2: Apply the three replacements**

| Line | From | To |
|---|---|---|
| 94 | `const NetworkException('Нет соединения')` | `const NetworkException('No connection')` |
| 98 | `const ServerException('Ошибка сервера')` | `const ServerException('Server error')` |
| 100 | `?? 'Не удалось выполнить операцию',` | `?? 'Operation failed',` |

Change only the literal text. Line 100 must keep preferring the server's own message; only the fallback changes.

- [ ] **Step 3: Remove the three allowlist entries**

Delete these three lines from `app/tool/i18n-allowlist.txt`:

```
lib/data/repositories/debt_repository_impl.dart::'Не удалось выполнить операцию'
lib/data/repositories/debt_repository_impl.dart::'Нет соединения'
lib/data/repositories/debt_repository_impl.dart::'Ошибка сервера'
```

- [ ] **Step 4: Update block 3's now-wrong inline comment**

`app/tool/i18n-allowlist.txt` lines 79–80 currently read:

```
# covers every occurrence of that literal in that file. 13 entries here cover
# 14 occurrences.
```

Block 3 now holds only `error_messages.dart`'s entries. Replace with:

```
# covers every occurrence of that literal in that file. 10 entries here cover
# 11 occurrences ('Не удалось выполнить операцию' appears twice, at the
# <=400 ServerException fallback and the unknown-exception fallback).
#
# debt_repository_impl.dart's three literals used to sit here. They were
# removed because Exception.message is diagnostic-only and never reaches a
# screen (see lib/core/errors/exceptions.dart), so English is correct there
# and there is nothing to defer.
```

Also update block 3's prose if it still describes `debt_repository_impl.dart` as deferred — after this task, only `error_messages.dart` is.

- [ ] **Step 5: Verify the lint is clean and the count dropped by exactly 3**

```bash
dart run tool/check_i18n.dart; echo "EXIT=$?"
grep -c "^lib/" tool/i18n-allowlist.txt
```
Expected: `EXIT=0`, and the entry count is **45** (48 − 3). Run the lint **unpiped** — a pipe masks the exit code.

- [ ] **Step 6: Confirm no Cyrillic remains in the file**

```bash
grep -n "[Ѐ-ԯ]" lib/data/repositories/debt_repository_impl.dart || echo "clean"
```
Expected: `clean`.

- [ ] **Step 7: Commit**

```bash
git add lib/data/repositories/debt_repository_impl.dart tool/i18n-allowlist.txt
git commit -m "fix(errors): make debt repository diagnostic strings English

These are Exception.message arguments, which mapErrorToUserMessage
discards — they can never reach a screen. Russian text there looked
user-facing and was allowlisted as deferred, which was untrue. English
matches the defaults already in exceptions.dart, and the three
allowlist entries go away rather than becoming permanent exceptions."
```

---

## Task 4: Rewrite the scanner on `package:analyzer`

This is the risky task: it replaces working, CI-green infrastructure. The 9 existing tests are the primary regression net and **must pass unmodified**.

**Files:**
- Modify: `app/pubspec.yaml` (`dev_dependencies`)
- Modify: `app/tool/check_i18n.dart` (full rewrite)
- Modify: `app/test/tool/check_i18n_test.dart` (2 new tests appended)

- [ ] **Step 1: Write the two failing tests for the gaps AST closes structurally**

Append to `app/test/tool/check_i18n_test.dart`, inside `main()`:

```dart
  test('a Cyrillic string inside a trailing comment is not reported', () async {
    // The old scanner skipped a line only when its *trimmed* form began with
    // '//', so Cyrillic in a trailing comment false-positived. Fixing that with
    // a regex is not possible without breaking literals that legitimately
    // contain '//' (URLs); parsing Dart makes it structural, because a comment
    // is not a string-literal node at all.
    File('${tempDir.path}/lib/presentation/sample.dart')
        .writeAsStringSync("void f() { g(); } // 'Пример'\n");
    File('${tempDir.path}/tool/i18n-allowlist.txt').writeAsStringSync('');

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 0, reason: 'a comment is not a string literal');
  });

  test("Cyrillic on a continuation line of a ''' literal is reported", () async {
    // The old scanner was line-based and required a quote character on the same
    // line as the Cyrillic. A multi-line literal's middle lines have neither, so
    // they were invisible. An AST sees one node regardless of line count.
    File('${tempDir.path}/lib/presentation/sample.dart').writeAsStringSync(
      "const s = '''\nМногострочный текст\n''';\n",
    );
    File('${tempDir.path}/tool/i18n-allowlist.txt').writeAsStringSync('');

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 1, reason: 'a multi-line literal is one node');
  });
```

- [ ] **Step 2: Prove both new tests FAIL against the current regex scanner**

```bash
cd app
flutter test test/tool/check_i18n_test.dart --reporter expanded
```
Expected: the two new tests **FAIL** — the trailing-comment one returns 1 where 0 is expected, and the multi-line one returns 0 where 1 is expected. The 9 existing tests pass.

**A guard that passes before the fix is decoration.** This project already shipped one vacuous regression test (a Tajik case whose literal also contained base-range Cyrillic, so the old regex already matched it). If either test passes here, stop and work out why before touching the scanner.

- [ ] **Step 3: Declare the `analyzer` dependency**

In `app/pubspec.yaml`, under `dev_dependencies`, after the `flutter_lints` entry, add:

```yaml
  # AST-based scanning for tool/check_i18n.dart. Already present in
  # pubspec.lock as a transitive dependency of flutter_lints, so declaring it
  # directly costs no extra download — it just makes the import legitimate
  # (depend_on_referenced_packages).
  analyzer: ^7.7.1
```

Then:

```bash
flutter pub get
```
Expected: succeeds, and `pubspec.lock`'s `analyzer` entry changes `dependency: transitive` to `dependency: "direct dev"` with the same `version: "7.7.1"`. **If the resolved version changes, stop and report it** — a major bump could move the `.errors` API this plan depends on.

- [ ] **Step 4: Replace `app/tool/check_i18n.dart` in full**

```dart
// Lint script: fail if any .dart file under lib/ contains a Cyrillic string
// literal that is not covered by tool/i18n-allowlist.txt.
//
// AST-based (package:analyzer). The previous implementation applied
// ['"][^'"]*[Ѐ-ԯ][^'"]*['"] line by line, which had four structural gaps:
//
//   1. Allow-list entries were a Set, so ONE entry permitted UNLIMITED
//      occurrences of that literal in the file. Re-adding an already-covered
//      string elsewhere in the same file passed silently.
//   2. Comments were skipped only when the line *began* with '//', so a
//      trailing `foo(); // 'Пример'` false-positived. This cannot be fixed with
//      a regex without breaking literals that legitimately contain '//' (URLs).
//   3. A '''...''' literal's continuation lines carry no quote character and so
//      were invisible to a line-based scan.
//   4. lib/l10n was skipped by DIRECTORY, so a hand-written helper placed there
//      would never be scanned.
//
// Parsing Dart dissolves 2 and 3 rather than guarding against them: a comment
// is not a string-literal node, and a multi-line literal is one node however
// many lines it spans. 1 and 4 are fixed below explicitly.
//
// The previous header said regex was chosen to avoid "pulling extra packages".
// package:analyzer was already in pubspec.lock as a transitive dependency of
// flutter_lints, so that cost was already being paid.
//
// Allow-list entries are keyed `<relative-path>::<literal source>`, never by
// line number. Line-number keys broke every time an unrelated edit landed above
// an already-allow-listed line: the entry silently stopped matching and a
// known violation reappeared as "new". See the Reconciliation section of
// docs/adr/0002-i18n-rollout-plan.md for that happening twice.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

Future<void> main(List<String> args) async {
  // main() must stay void/non-int: Dart only applies a returned int to the
  // process exit code for a *synchronous* `int main()`. For
  // `Future<int> main() async` the value is silently dropped and the process
  // always exits 0, so CI would never observe a failure.
  exitCode = await run(args);
}

// Full Cyrillic block + supplement (U+0400-U+052F), not [а-яА-ЯёЁ]: the
// Russian-only class cannot see the Tajik/Uzbek letters ӯ қ ғ ҳ ҷ ӣ, which let
// genuine wrong-language bugs through.
final _cyrillic = RegExp(r'[Ѐ-ԯ]');

// Calls whose string arguments are diagnostics, not UI copy. The old scanner
// expressed this as "the line starts with debugPrint(", which missed nested and
// multi-line calls. It currently suppresses nothing in lib/ — verified across
// all scanned files — but the intent is real and is preserved here in a
// form that actually works.
const _diagnosticCalls = {'debugPrint', 'log', 'print'};

/// Collects the source text of every Cyrillic-bearing string literal, one entry
/// per occurrence, in visit order.
class _CyrillicLiteralCollector extends RecursiveAstVisitor<void> {
  final found = <({String source, int offset})>[];

  bool _isDiagnosticArgument(StringLiteral node) {
    final args = node.parent;
    if (args is! ArgumentList) return false;
    final call = args.parent;
    return call is MethodInvocation &&
        _diagnosticCalls.contains(call.methodName.name);
  }

  void _record(StringLiteral node) {
    if (_isDiagnosticArgument(node)) return;
    final source = node.toSource();
    if (!_cyrillic.hasMatch(source)) return;
    found.add((source: source, offset: node.offset));
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    // Covers '…', "…", r'…' and '''…''' alike — all one node. Note toSource()
    // keeps a raw string's `r` prefix, where the old regex dropped it.
    _record(node);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    // 'аб' 'вг' is one logical string, so report the juxtaposition once.
    // Deliberately do NOT recurse: that would report each part a second time.
    _record(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    // Only the literal chunks are copy. If the Cyrillic lives solely inside an
    // interpolated expression — '${cond ? "Да" : "Нет"}' — the interpolation
    // itself is not copy; the nested literals are, and the recursion below
    // reports them individually. That also keeps keys identical to the old
    // regex, which reported "Да" and "Нет" separately for this shape while
    // reporting 'Ошибка: ${x}' whole.
    final literalParts = node.elements
        .whereType<InterpolationString>()
        .map((e) => e.value)
        .join();
    if (_cyrillic.hasMatch(literalParts) && !_isDiagnosticArgument(node)) {
      found.add((source: node.toSource(), offset: node.offset));
    }
    for (final element in node.elements.whereType<InterpolationExpression>()) {
      element.expression.accept(this);
    }
  }
}

/// True for gen-l10n output. Matched by FILENAME, not by directory: these files
/// are excluded because they are generated (app_localizations_ru.dart is
/// Russian by definition), not because of where they sit. A hand-written helper
/// dropped into lib/l10n must still be scanned.
bool _isGeneratedLocalization(String relativePath) {
  final name = relativePath.split('/').last;
  return name == 'app_localizations.dart' ||
      (name.startsWith('app_localizations_') && name.endsWith('.dart'));
}

/// `repoRootOverride` exists purely so tests can point this at a temp directory
/// instead of the real repo — production callers (main(), CI) never pass it.
Future<int> run(List<String> args, {String? repoRootOverride}) async {
  final repoRoot = repoRootOverride ?? Directory.current.path;
  // Scan all of lib/, not just lib/presentation: the narrower root was a blind
  // spot that let 71 user-facing literals in lib/core, lib/data and lib/domain
  // survive the whole Track 2 migration untouched.
  final scanRoot = Directory('$repoRoot/lib');
  if (!scanRoot.existsSync()) {
    stderr.writeln('lib not found — run from app/ directory');
    return 2;
  }

  final allowlistFile = File('$repoRoot/tool/i18n-allowlist.txt');
  final dumpAllowlist = args.contains('--dump-allowlist');

  // A MULTISET, not a Set: a `path::literal` line repeated N times permits
  // exactly N occurrences. This is gap 1 — with a Set, one entry covered
  // unlimited repeats.
  final allowed = <String, int>{};
  if (allowlistFile.existsSync() && !dumpAllowlist) {
    for (final line in allowlistFile.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      allowed[trimmed] = (allowed[trimmed] ?? 0) + 1;
    }
  }

  // Collect and sort so the report and the --dump-allowlist output are
  // deterministic regardless of filesystem enumeration order.
  final files = <File>[];
  await for (final entity in scanRoot.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) files.add(entity);
  }
  files.sort((a, b) => a.path.compareTo(b.path));

  final seen = <String, int>{};
  final offenders = <({String key, String display})>[];
  final unparseable = <String>[];
  var scanned = 0;

  for (final file in files) {
    final rel = file.path.substring(repoRoot.length + 1);
    if (_isGeneratedLocalization(rel)) continue;
    scanned++;

    final content = file.readAsStringSync();
    final parsed = parseString(content: content, throwIfDiagnostics: false);
    // parseString does no resolution, so every entry here is a syntax error.
    //
    // This check is NOT optional. The parser recovers from syntax errors and
    // still hands back a unit — a PARTIAL tree, not an empty one. Scanning that
    // tree would find some literals while silently missing whatever fell inside
    // the unparsed region, so the tool would report success having examined only
    // part of the file. That is a worse blind spot than any of the four this
    // rewrite closes, because it is invisible and partial rather than total.
    if (parsed.errors.isNotEmpty) {
      unparseable.add('$rel  ${parsed.errors.first}');
      continue;
    }

    final collector = _CyrillicLiteralCollector();
    parsed.unit.accept(collector);
    for (final hit in collector.found) {
      final key = '$rel::${hit.source}';
      seen[key] = (seen[key] ?? 0) + 1;
      if (seen[key]! <= (allowed[key] ?? 0)) continue;
      final line = parsed.lineInfo.getLocation(hit.offset).lineNumber;
      offenders.add((key: key, display: '$rel:$line'));
    }
  }

  if (unparseable.isNotEmpty) {
    stdout.writeln(
      'check_i18n: ${unparseable.length} file(s) could not be parsed. This is a '
      'hard failure rather than a skip: an unparseable file contributes no '
      'string literals and would otherwise pass silently.',
    );
    for (final u in unparseable) {
      stdout.writeln('  $u');
    }
    return 2;
  }

  // --dump-allowlist rewrites tool/i18n-allowlist.txt from the current
  // offenders and exits 0. Used when bootstrapping or resyncing the list.
  if (dumpAllowlist) {
    // One line PER OCCURRENCE, deliberately not de-duplicated: the allow-list
    // is a multiset, so collapsing duplicates here would regenerate a file that
    // permits more occurrences than actually exist.
    final lines = offenders.map((o) => o.key).toList()..sort();
    allowlistFile.writeAsStringSync('${lines.join('\n')}\n');
    stdout.writeln(
      'check_i18n: wrote ${lines.length} entries to tool/i18n-allowlist.txt',
    );
    return 0;
  }

  if (offenders.isEmpty) {
    stdout.writeln(
      'check_i18n: scanned $scanned files, no new hardcoded Cyrillic strings.',
    );
    return 0;
  }
  stdout.writeln(
    'check_i18n: found ${offenders.length} hardcoded Cyrillic string(s) '
    'outside the grandfathered allow-list. Move them into app_ru.arb and '
    'use AppLocalizations.of(context).yourKey, or (temporarily) add them '
    'to tool/i18n-allowlist.txt with a TODO.',
  );
  for (final o in offenders.take(50)) {
    stdout.writeln('  ${o.key}  (${o.display})');
  }
  if (offenders.length > 50) {
    stdout.writeln('  ... and ${offenders.length - 50} more.');
  }
  return 1;
}
```

- [ ] **Step 5: Run the whole test file**

```bash
flutter test test/tool/check_i18n_test.dart --reporter expanded
```
Expected: **all 11 pass** — the 9 pre-existing and the 2 new.

If a pre-existing test now fails, that is a signal the rewrite changed observable behaviour. Diagnose it; do **not** edit the test to match the new code. The 9 existing tests are the contract.

- [ ] **Step 6: Migrate the allowlist to the multiset rule, then verify**

The code you just wrote makes the allowlist a multiset, so run the lint first and expect **`EXIT=1` with exactly 5 offenders** — surplus occurrences the old Set-based lookup silently permitted. This is the gap-1 fix working, not a key-migration failure.

```bash
dart run tool/check_i18n.dart; echo "EXIT=$?"
```

Read the 5 reported keys from the output — **that list is authoritative, not the one below.** Measured 2026-10-01 it was:

```
lib/core/errors/error_messages.dart::'Не удалось выполнить операцию'
lib/presentation/blocs/subscription/subscription_bloc.dart::'Заявка отправлена, ожидайте подтверждения'
lib/presentation/pages/settings/subscription_page.dart::'Старт'
lib/presentation/pages/settings/subscription_page.dart::'Бизнес'
lib/presentation/pages/settings/subscription_page.dart::'Премиум'
```

Add one duplicate line per surplus occurrence, immediately below the existing line and inside its current block. Then update the preamble, which still describes the old Set model, to state the multiset rule: an entry permits exactly one occurrence, and N identical lines permit N. Fix block 3's count line too — with the duplicate it is 11 lines covering 11 occurrences across 10 distinct literals.

```bash
dart run tool/check_i18n.dart; echo "EXIT=$?"
grep -c "^lib/" tool/i18n-allowlist.txt
```
Expected: `EXIT=0`, `scanned 343 files`, and **50** entry lines (45 + 5).

`EXIT=0` is a strong compatibility signal: if the AST produced a different key for any committed entry, that entry would stop matching and its literal would surface as an offender.

**Tightening the rule and migrating the data to it belong in one commit.** An earlier revision of this plan split them across Tasks 4 and 6, which left the lint red in between — a state that breaks `git bisect` and any per-commit CI.

- [ ] **Step 7: Measure the runtime**

```bash
time dart run tool/check_i18n.dart
```
Record the wall-clock time. Parsing 343 files costs more than 343 regex sweeps. If it exceeds roughly **10 seconds**, report it as a finding — it runs on every CI push (`.github/workflows/ci.yml:128`). That is its **only** consumer: `lefthook.yml`'s pre-commit hook runs api prettier/tsc/eslint plus `dart format`/`dart analyze`, and does not invoke this tool.

- [ ] **Step 8: Prove non-vacuity end to end**

```bash
printf "\nconst probe = 'Проверка области сканирования';\n" >> lib/core/utils/formatters.dart
dart run tool/check_i18n.dart; echo "EXIT=$?"
git checkout lib/core/utils/formatters.dart
dart run tool/check_i18n.dart; echo "EXIT=$?"
git status --short
```
Expected: `EXIT=1` naming `formatters.dart` in the middle run, `EXIT=0` either side, and `git status --short` clean afterwards. Run **unpiped** — `| tail` masks the exit code.

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock tool/check_i18n.dart test/tool/check_i18n_test.dart
git commit -m "refactor(i18n): scan with package:analyzer instead of a line regex

Comments and multi-line literals stop being special cases: a comment is
not a string-literal node, and a '''...''' literal is one node however
many lines it spans. Both new tests were proven to fail against the
regex first. All 9 existing tests pass unmodified, and all committed
allowlist keys still resolve — node.toSource() reproduces what the
regex captured, including for interpolations."
```

---

## Task 5: Make parse failures a hard error

The code from Task 4 already returns 2 for unparseable files. This task proves it, because an untested hard-failure path is indistinguishable from a silent skip.

**Files:**
- Modify: `app/test/tool/check_i18n_test.dart` (1 new test)

- [ ] **Step 1: Write the failing test**

Append inside `main()`:

```dart
  test('a file that cannot be parsed is a hard failure, not a silent skip', () async {
    // The analyzer recovers from syntax errors and returns a PARTIAL unit rather
    // than nothing (verified: 'class Broken { void f( {' yields 4 errors and a
    // non-empty unit). So the danger is not an empty scan but a partial one —
    // literals outside the broken region are still found, which makes the gap
    // look like success. Exit 2 forces the file to be fixed instead.
    File('${tempDir.path}/lib/presentation/broken.dart')
        .writeAsStringSync('class Broken { void f( {\n');
    File('${tempDir.path}/tool/i18n-allowlist.txt').writeAsStringSync('');

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 2, reason: 'exit 2 = the tool could not do its job');
  });
```

Exit 2 is deliberately distinct from exit 1 ("found offenders") and matches the existing "lib not found" path.

- [ ] **Step 2: Run it**

```bash
flutter test test/tool/check_i18n_test.dart --reporter expanded
```
Expected: **all 12 pass**.

If this test fails, `parsed.errors` is not populated the way this plan assumes. Diagnose before proceeding — print `parsed.errors` for the broken input and adjust the detection, keeping the hard-failure semantics.

- [ ] **Step 3: Confirm the check against the old scanner would have been vacuous**

```bash
git stash
flutter test test/tool/check_i18n_test.dart --plain-name 'a file that cannot be parsed is a hard failure, not a silent skip' 2>&1 | tail -5
git stash pop
```
Expected: FAILS against the regex scanner (returns 0, not 2) — confirming the guard is real. If `git stash` is awkward mid-task, instead check out the parent revision of `tool/check_i18n.dart` into place, run, and restore.

- [ ] **Step 4: Commit**

```bash
git add test/tool/check_i18n_test.dart
git commit -m "test(i18n): pin that an unparseable file exits 2, not 0"
```

---

## Task 6: Occurrence counting — make the allowlist a multiset

Task 4 already ships the counting code *and* the migrated allowlist (the two are one semantic change, so splitting them would leave the lint red in between). This task adds the tests that pin the behaviour.

**Files:**
- Modify: `app/test/tool/check_i18n_test.dart` (2 new tests)
- Modify: `app/tool/i18n-allowlist.txt`

- [ ] **Step 1: Write the two failing tests**

Append inside `main()`:

```dart
  test('three occurrences are not covered by two allow-list lines', () async {
    // Gap 1: entries were held in a Set, so one line covered unlimited repeats
    // of that literal in that file. A third copy appearing was invisible.
    File('${tempDir.path}/lib/presentation/sample.dart').writeAsStringSync(
      "const a = 'Повтор';\nconst b = 'Повтор';\nconst c = 'Повтор';\n",
    );
    File('${tempDir.path}/tool/i18n-allowlist.txt').writeAsStringSync(
      "lib/presentation/sample.dart::'Повтор'\n"
      "lib/presentation/sample.dart::'Повтор'\n",
    );

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 1, reason: '2 permitted, 3 present');
  });

  test('three occurrences are covered by three allow-list lines', () async {
    // The other half of the contract: repetition is how the permitted count is
    // expressed, so N lines must permit exactly N occurrences.
    File('${tempDir.path}/lib/presentation/sample.dart').writeAsStringSync(
      "const a = 'Повтор';\nconst b = 'Повтор';\nconst c = 'Повтор';\n",
    );
    File('${tempDir.path}/tool/i18n-allowlist.txt').writeAsStringSync(
      "lib/presentation/sample.dart::'Повтор'\n"
      "lib/presentation/sample.dart::'Повтор'\n"
      "lib/presentation/sample.dart::'Повтор'\n",
    );

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 0, reason: '3 permitted, 3 present');
  });
```

- [ ] **Step 2: Run them**

```bash
flutter test test/tool/check_i18n_test.dart --reporter expanded
```
Expected: **all 14 pass**. (The first would have returned 0 against the Set-based scanner — that is the gap being closed, and Task 4's implementation already closes it.)

- [ ] **Step 3: Verify the lint is still clean and the count is 50**

```bash
dart run tool/check_i18n.dart; echo "EXIT=$?"
grep -c "^lib/" tool/i18n-allowlist.txt
```
Expected: `EXIT=0`, and **50** entry lines (45 after Task 3, plus the 5 duplicates). Entry lines going *up* while the gate gets stricter is the expected outcome here.

- [ ] **Step 4: Prove the committed allowlist is exactly the live offender multiset**

`--dump-allowlist` rewrites the file from scratch, so it drops the comment blocks — a whole-file `diff` will always differ. Compare only the entry lines:

```bash
cp tool/i18n-allowlist.txt /tmp/allowlist-committed.txt
dart run tool/check_i18n.dart --dump-allowlist
grep "^lib/" /tmp/allowlist-committed.txt | sort > /tmp/a.txt
grep "^lib/" tool/i18n-allowlist.txt | sort > /tmp/b.txt
diff /tmp/a.txt /tmp/b.txt && echo "ENTRY LINES IDENTICAL" || echo "DIFFERS — investigate"
git checkout tool/i18n-allowlist.txt
git status --short
```
Expected: `ENTRY LINES IDENTICAL`, then a clean `git status --short`.

This is the strongest available check on the allowlist: it proves simultaneously that no entry is stale (every line corresponds to a real occurrence) and that none is missing (every occurrence has a line). Under the multiset rule it also proves the duplicate counts are exactly right — a missing or surplus duplicate shows up as a line-count difference.

**Restore the file afterwards.** The `git checkout` above is not optional; without it you commit a comment-stripped allowlist.

- [ ] **Step 5: Commit**

```bash
git add test/tool/check_i18n_test.dart
git commit -m "test(i18n): pin that the allowlist counts occurrences

Two tests pin both halves of the contract: N lines permit exactly N
occurrences, and N+1 occurrences fail. The counting code and the migrated
allowlist shipped together in the AST rewrite, because tightening the
rule and migrating the data to it are one semantic change."
```

---

## Task 7: Exclude generated localizations by filename, and pin raw-string keying

**Files:**
- Modify: `app/test/tool/check_i18n_test.dart` (2 new tests)

The code from Task 4 already matches by filename via `_isGeneratedLocalization`. This task proves both halves of that behaviour and pins the raw-string decision.

- [ ] **Step 1: Write the two tests**

Append inside `main()`:

```dart
  test('a hand-written file under lib/l10n is scanned', () async {
    // Gap 4: the skip used to be rel.startsWith('lib/l10n/'), excluding the
    // whole directory. Generated files are excluded because they are generated,
    // not because of where they sit — so a hand-written helper dropped into
    // lib/l10n must still be policed. The existing
    // 'generated localizations under lib/l10n are not scanned' test is the
    // other half of this contract and must keep passing.
    Directory('${tempDir.path}/lib/l10n').createSync(recursive: true);
    File('${tempDir.path}/lib/l10n/l10n_helpers.dart')
        .writeAsStringSync("const s = 'Помощник';\n");
    File('${tempDir.path}/tool/i18n-allowlist.txt').writeAsStringSync('');

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 1, reason: 'only generated app_localizations*.dart is excluded');
  });

  test("a raw string's allow-list key keeps the r prefix", () async {
    // Deliberate difference from the old regex, which began matching at the
    // first quote and so produced 'Сырая' as the key. node.toSource() is the
    // honest representation. There are zero Cyrillic-bearing raw strings in lib
    // today, so no committed entry is affected — this pins the choice so it
    // stays deliberate rather than becoming an accident someone "fixes".
    File('${tempDir.path}/lib/presentation/sample.dart')
        .writeAsStringSync("const s = r'Сырая';\n");
    final allowlistFile = File('${tempDir.path}/tool/i18n-allowlist.txt');
    allowlistFile.writeAsStringSync('');

    await check_i18n.run(['--dump-allowlist'], repoRootOverride: tempDir.path);

    expect(
      allowlistFile.readAsStringSync().trim(),
      "lib/presentation/sample.dart::r'Сырая'",
    );
  });
```

- [ ] **Step 2: Write the allowlist compatibility test**

This is the one test that runs against the **real** repo rather than a temp directory, so the regex→AST key migration stays guarded after the branch merges. Append inside `main()`:

```dart
  test('every committed allow-list entry still resolves against the real lib tree', () async {
    // Guards the regex -> AST key migration. Keys are `<path>::<literal source>`
    // and all committed entries must keep matching without edits: if the AST
    // produced a different source form for any of them (raw-string prefixes and
    // interpolations are the risky shapes), that entry would stop matching and
    // its literal would surface as an offender, failing this test.
    //
    // `flutter test` runs with the CWD at app/, which is the repo root this
    // tool expects. This is deliberately the same check CI runs — it asserts
    // the committed allowlist and the live tree agree, so it fails if either
    // drifts.
    final repoRoot = Directory.current.path;
    final entries = File('$repoRoot/tool/i18n-allowlist.txt')
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
    expect(entries, isNotEmpty, reason: 'sanity: the allow-list must be found');

    final code = await check_i18n.run([], repoRootOverride: repoRoot);

    expect(code, 0,
        reason: 'either a committed entry stopped matching, or a new '
            'unallowlisted literal appeared in lib/');
  });
```

Note what this does and does not prove. It proves every entry still matches *something* and that nothing new is unlisted. It does **not** prove the absence of stale entries — that is what Task 6's `--dump-allowlist` entry-line diff covers, and the two checks are complementary.

- [ ] **Step 3: Run the full file**

```bash
flutter test test/tool/check_i18n_test.dart --reporter expanded
```
Expected: **all 17 pass**, including the pre-existing `generated localizations under lib/l10n are not scanned`.

- [ ] **Step 4: Confirm the scanned count is unchanged**

```bash
dart run tool/check_i18n.dart; echo "EXIT=$?"
find lib -name "*.dart" | wc -l
find lib/l10n -name "*.dart" | wc -l
```
Expected: `EXIT=0` with `scanned 343 files`; **347** total; 4 under `lib/l10n`. All 4 generated files match `app_localizations*.dart`, so narrowing from directory to filename excludes exactly the same set today. **If the scanned count changes when you make this edit, that is a finding** — it would mean a file in `lib/l10n` is not actually generated output, or a generated file does not match the pattern.

- [ ] **Step 5: Commit**

```bash
git add test/tool/check_i18n_test.dart
git commit -m "test(i18n): pin l10n exclusion, raw-string keying, and allowlist compatibility"
```

---

## Task 8: Whole-branch verification

**Files:** none modified unless a defect is found.

- [ ] **Step 1: Lint**

```bash
cd app
dart run tool/check_i18n.dart; echo "EXIT=$?"
```
Expected: `scanned 343 files`, `EXIT=0`. Unpiped.

- [ ] **Step 2: Analyze**

```bash
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3: The scanner's own test file**

```bash
flutter test test/tool/check_i18n_test.dart
```
Expected: **17 passed** — the 9 originals unmodified plus 8 new.

- [ ] **Step 4: Confirm the 9 original tests were not edited**

```bash
cd ..
git diff main...HEAD -- app/test/tool/check_i18n_test.dart | grep "^-" | grep -v "^---"
```
Expected: **no output**. The rewrite must be purely additive to this file. Any deleted line means an existing test was weakened to accommodate the new scanner, which needs explicit justification.

- [ ] **Step 5: ARB untouched**

```bash
cd app
git diff main...HEAD --stat -- lib/l10n/
flutter gen-l10n && git status --short
```
Expected: the first prints nothing (no ARB or generated file changed on this branch); the second prints nothing.

- [ ] **Step 6: Full suite against the documented baseline**

```bash
flutter test 2>&1 | grep -oE '[a-zA-Z_]+_test\.dart: [^\[]*\[E\]' | sed 's/ *\[E\]//' | sort -u
```
Expected: exactly the 18 known macOS golden failures — `balance_page`, `create_delivery_page`, `credits_page`, `currencies_page`, `delivery_detail_page`, `delivery_list_page`, `discounts_page`, `my_stores_page`, `reports_page`, each light and dark.

**Compare the sorted set, never the count.** Any new name is a regression: investigate it rather than regenerating a golden. Note `currency_remote_datasource_test.dart` is gone, so total passing count drops — that is expected from Task 1, not a regression.

- [ ] **Step 7: Confirm no golden image was touched**

```bash
cd ..
git diff main...HEAD --name-only | grep "\.png$" || echo "no goldens touched"
```
Expected: `no goldens touched`.

- [ ] **Step 8: Confirm the allowlist arithmetic**

```bash
cd app
grep -c "^lib/" tool/i18n-allowlist.txt
grep -c "error_messages.dart" tool/i18n-allowlist.txt
```
Expected: **50** entry lines total. `error_messages.dart` appears **11** times — its 10 distinct literals plus the one duplicate for the literal that occurs twice. Those are B1's, deferred, and must not have been migrated by this branch.

- [ ] **Step 9: Report the runtime measured in Task 4 Step 7**

State the wall-clock time for `dart run tool/check_i18n.dart` in the completion report, whether or not it exceeded 10 seconds. It runs on every CI push, so the number matters even when it is fine.

- [ ] **Step 10: Commit only if something needed fixing**

If Steps 1–9 are clean there is nothing to commit and this task ends. Otherwise fix the defect, re-run Steps 1–9, and commit with a message naming what was wrong.

---

## Notes for the executor

- **The 9 pre-existing scanner tests are the contract.** They exercise `run(args, {repoRootOverride})` and assert exit codes and dump output, not internals, which is exactly why they survive an implementation swap. If one fails, the rewrite changed observable behaviour — that is a bug in the rewrite until proven otherwise, never a reason to edit the test.
- **Every new gap test must fail against the old scanner.** Tasks 4, 5 and 6 include that proof explicitly. This project shipped one vacuous regression test already: a Tajik-letter case whose literal also contained base-range Cyrillic, so the old regex matched it anyway and the test passed before the fix.
- **Do not widen the generated-file exclusion.** With it removed entirely the lint reports 3186 offenders, so it is heavily load-bearing. Narrowing it from directory to filename is the intended change; anything broader is a regression.
- **Exit codes carry meaning:** 0 = clean, 1 = offenders found, 2 = the tool could not do its job (no `lib`, or a file would not parse). Keep that distinction — CI treats any non-zero as failure, but a human reading the log needs to know which happened.
- **Part C's safety comes from the compiler,** not from review. Deleting `CurrencyRemoteDatasource` and its DI registration turns any missed consumer into a build error. That is the same property that made Track 2b's `CurrencyRate.label` and `ZReport.duration` removals safe.
- **Possible follow-up, deliberately not in scope:** the scanner could warn about *stale* allowlist entries (entries whose literal no longer occurs). That would have flagged Task 3's three removals automatically. It is additive and would make CI noisier, so it belongs in its own change with its own decision about whether it warns or fails.
