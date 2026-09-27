# i18n: 9-File Migration + Content-Based Allow-list Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fully migrate every currently-hardcoded Cyrillic string in 9 specific files into `app_ru.arb`/`AppLocalizations`, and fix `check_i18n.dart`'s allow-list to key by content instead of line number so it can never desync from unrelated edits again.

**Architecture:** One foundational task changes the lint tool's allow-list key scheme (`file:line` → `file::content`) and adds real unit test coverage for it — every other file-migration task benefits from this immediately (no more line-drift risk while the migration itself is in progress across 9 files over multiple commits). Then one task per file, each self-contained: add ARB keys (reusing existing ones wherever the exact Russian text is already there), regenerate localizations, replace literals, verify. A final task regenerates the (now much shorter) allow-list and runs the full verification suite.

**Tech Stack:** Dart, Flutter, `flutter gen-l10n`, `intl`-backed `AppLocalizations`.

**Working directory:** create a new worktree per `superpowers:using-git-worktrees` (branch e.g. `feat/i18n-nine-file-migration`) before starting Task 1 — do not implement on `main`. All commands below assume `cd`'d into that worktree's `app/` directory.

---

### Task 1: `check_i18n.dart` — content-keyed allow-list + tool test coverage

**Files:**
- Modify: `app/tool/check_i18n.dart` (full rewrite below)
- Create: `app/test/tool/check_i18n_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `app/test/tool/check_i18n_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/check_i18n.dart' as check_i18n;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('check_i18n_test_');
    Directory('${tempDir.path}/lib/presentation').createSync(recursive: true);
    Directory('${tempDir.path}/tool').createSync(recursive: true);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('a string already in the allow-list by content is skipped', () async {
    File('${tempDir.path}/lib/presentation/sample.dart')
        .writeAsStringSync("const text = 'Сохранить';\n");
    File('${tempDir.path}/tool/i18n-allowlist.txt')
        .writeAsStringSync("lib/presentation/sample.dart::'Сохранить'\n");

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 0);
  });

  test('an unlisted Cyrillic literal is reported and exits 1', () async {
    File('${tempDir.path}/lib/presentation/sample.dart')
        .writeAsStringSync("const text = 'Новая строка';\n");
    File('${tempDir.path}/tool/i18n-allowlist.txt').writeAsStringSync('');

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 1);
  });

  test('moving an already-allow-listed string to a different line in the same file is still recognized (the bug this fixes)', () async {
    File('${tempDir.path}/tool/i18n-allowlist.txt')
        .writeAsStringSync("lib/presentation/sample.dart::'Отмена'\n");
    // Originally at line 1; now pushed down to line 4 by unrelated edits above it.
    File('${tempDir.path}/lib/presentation/sample.dart').writeAsStringSync(
      '// unrelated edit 1\n// unrelated edit 2\n// unrelated edit 3\n'
      "const text = 'Отмена';\n",
    );

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 0);
  });

  test('--dump-allowlist writes file::content entries, not file:line', () async {
    File('${tempDir.path}/lib/presentation/sample.dart')
        .writeAsStringSync("const text = 'Пример';\n");
    final allowlistFile = File('${tempDir.path}/tool/i18n-allowlist.txt');
    allowlistFile.writeAsStringSync('');

    await check_i18n.run(['--dump-allowlist'], repoRootOverride: tempDir.path);

    expect(
      allowlistFile.readAsStringSync().trim(),
      "lib/presentation/sample.dart::'Пример'",
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/tool/check_i18n_test.dart`
Expected: FAIL — `check_i18n.dart` doesn't expose a public `run(...)` function with a `repoRootOverride` parameter yet (only a private `_run(args)` hardcoded to `Directory.current.path`), so this won't even compile.

- [ ] **Step 3: Rewrite `tool/check_i18n.dart`**

Replace the entire file content with:

```dart
// Very small lint script: fail if any .dart file under lib/presentation/
// contains a Cyrillic string literal that is NOT wrapped in
// AppLocalizations.of(context).<key>, Text.rich, debugLabel, log calls,
// or inside an existing allow-list.
//
// Intentionally regex-based (no AST) so we can run it as a `dart run`
// pre-commit / CI step without pulling extra packages. False positives
// are added to tool/i18n-allowlist.txt to keep the signal clean during
// the incremental migration described in docs/adr/0002-i18n-rollout-plan.md.
//
// Allow-list entries are keyed by `<relative-path>::<matched-substring>`,
// not by line number. Line-number keys broke every time an unrelated
// edit landed above an already-allow-listed line in the same file — the
// entry silently stopped matching and the same, already-known violation
// reappeared as "new" (see docs/adr/0002-i18n-rollout-plan.md's
// Reconciliation section for this happening once before, and
// docs/superpowers/specs/2026-09-27-i18n-nine-file-migration-design.md
// for the second occurrence that prompted this fix). Content-keying
// means an already-covered string stays covered no matter which line it
// ends up on.

import 'dart:io';

Future<void> main(List<String> args) async {
  // `main()` itself must stay `void`/non-int here: Dart only auto-applies a
  // returned int to the process exit code for a *synchronous* `int main()`.
  // For `Future<int> main() async`, the returned value is silently dropped
  // and the process always exits 0 regardless of what the script found.
  // Route the real logic through `run` and set `exitCode` explicitly so
  // CI actually observes failures.
  exitCode = await run(args);
}

/// `repoRootOverride` exists purely so tests can point this at a temp
/// directory instead of the real repo — production callers (main(), CI)
/// never pass it and get `Directory.current.path` as before.
Future<int> run(List<String> args, {String? repoRootOverride}) async {
  final repoRoot = repoRootOverride ?? Directory.current.path;
  final presentation = Directory('$repoRoot/lib/presentation');
  if (!presentation.existsSync()) {
    stderr.writeln('lib/presentation not found — run from app/ directory');
    return 2;
  }

  final allowlistFile = File('$repoRoot/tool/i18n-allowlist.txt');
  final dumpAllowlist = args.contains('--dump-allowlist');
  // When dumping we start from a blank allowlist so every current
  // offender is captured in one pass.
  final allowlist = (allowlistFile.existsSync() && !dumpAllowlist)
      ? allowlistFile
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
          .toSet()
      : <String>{};

  final cyrillicInString = RegExp(r'''['"][^'"]*[а-яА-ЯёЁ][^'"]*['"]''');

  final offenders = <String>[];
  var scanned = 0;
  await for (final entity in presentation.list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    scanned++;
    final rel = entity.path.substring(repoRoot.length + 1);
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = cyrillicInString.firstMatch(line);
      if (match == null) continue;
      final content = match.group(0)!;
      final key = '$rel::$content';
      if (allowlist.contains(key)) continue;
      // Skip debugPrint / log / comments
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') ||
          trimmed.startsWith('debugPrint(') ||
          trimmed.startsWith('log(') ||
          trimmed.startsWith('print(')) {
        continue;
      }
      offenders.add('$key  $trimmed');
    }
  }

  // --dump-allowlist writes every offender's key to tool/i18n-allowlist.txt
  // and exits 0. Used once when bootstrapping the allow-list (or
  // resyncing it) so CI can start enforcing the rule for new code.
  if (dumpAllowlist) {
    final locations = offenders
        .map((o) => o.split('  ').first)
        .toSet()
        .toList()
      ..sort();
    allowlistFile.writeAsStringSync('${locations.join('\n')}\n');
    stdout.writeln(
      'check_i18n: wrote ${locations.length} locations to tool/i18n-allowlist.txt',
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
    stdout.writeln('  $o');
  }
  if (offenders.length > 50) {
    stdout.writeln('  ... and ${offenders.length - 50} more.');
  }
  return 1;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/tool/check_i18n_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Regenerate the allow-list in the new format**

Run: `dart run tool/check_i18n.dart --dump-allowlist`

This rewrites `tool/i18n-allowlist.txt` with `file::content` entries for
every currently-hardcoded string repo-wide (not just the 9 files this
plan migrates — everything else stays grandfathered exactly as before,
just in the new key format). Expect a count in the same ballpark as the
current 1022-line file (exact count may differ slightly — that's fine,
it reflects real current state).

- [ ] **Step 6: Verify the lint still passes clean**

Run: `dart run tool/check_i18n.dart`
Expected: `check_i18n: scanned <N> files, no new hardcoded Cyrillic strings.`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add tool/check_i18n.dart tool/i18n-allowlist.txt test/tool/check_i18n_test.dart
git commit -m "fix(app): key i18n allow-list by content instead of line number"
```

---

### Task 2: Migrate `customer_list_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/customer/customer_list_page.dart`

This file already declares `final l10n = AppLocalizations.of(context)!;`
in `build()` and uses it for `l10n.back` / `l10n.a11yAddClient` — reuse
that same binding, don't add a second one.

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"cancel"\|"save"\|"create"' lib/l10n/app_ru.arb`
Expected: confirms `cancel: "Отмена"` and `save: "Сохранить"` already exist (both reused below). Also run `grep -n "phoneLabel" lib/l10n/app_ru.arb` — confirms `phoneLabel: "Телефон"` exists (reused below).

- [ ] **Step 2: Add new keys to `app_ru.arb`**

Add these entries (append near other `customer*`-prefixed keys if any exist — check with `grep -n '"customer' lib/l10n/app_ru.arb` first; otherwise add a new contiguous block):

```json
  "customerListTitle": "Клиенты",
  "customerListSearchHint": "Поиск клиента",
  "customerListFilterAll": "Все",
  "customerListFilterDebt": "С долгом",
  "customerListFilterVip": "VIP",
  "customerListFilterNew": "Новые",
  "customerListEmptyTitle": "Клиентов пока нет",
  "customerListEmptySubtitle": "Добавьте первого клиента, чтобы отслеживать продажи и долги",
  "customerListEmptyButton": "Добавить клиента",
  "customerListFilterEmptyTitle": "Нет клиентов по этому фильтру",
  "customerListFilterEmptySubtitle": "Попробуйте выбрать другой фильтр",
  "customerListResetFilterButton": "Сбросить фильтр",
  "customerListAddDialogTitle": "Новый клиент",
  "customerListNameLabel": "Имя",
  "customerListNameHint": "Введите имя клиента",
  "customerListAddConfirm": "Добавить",
  "customerListStatsLine": "{count} клиентов  |  Долг: {debt}",
```

Add the corresponding `@customerListStatsLine` placeholder metadata entry (this file's existing placeholder entries are all typed `String` per convention — match that):

```json
  "@customerListStatsLine": {
    "placeholders": {
      "count": { "type": "String" },
      "debt": { "type": "String" }
    }
  },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors.

- [ ] **Step 4: Replace literals in `customer_list_page.dart`**

Find and replace each of the following (all in this one file):

| Find | Replace with |
|---|---|
| `const Text('Клиенты',` | `Text(l10n.customerListTitle,` |
| `hintText: 'Поиск клиента',` | `hintText: l10n.customerListSearchHint,` |
| `_filterChip('Все', 'all')` | `_filterChip(l10n.customerListFilterAll, 'all')` |
| `_filterChip('С долгом', 'debt')` | `_filterChip(l10n.customerListFilterDebt, 'debt')` |
| `_filterChip('VIP', 'vip')` | `_filterChip(l10n.customerListFilterVip, 'vip')` |
| `_filterChip('Новые', 'new')` | `_filterChip(l10n.customerListFilterNew, 'new')` |
| `title: 'Клиентов пока нет',` | `title: l10n.customerListEmptyTitle,` |
| `subtitle: 'Добавьте первого клиента, чтобы отслеживать продажи и долги',` | `subtitle: l10n.customerListEmptySubtitle,` |
| `buttonText: 'Добавить клиента',` | `buttonText: l10n.customerListEmptyButton,` |
| `title: 'Нет клиентов по этому фильтру',` | `title: l10n.customerListFilterEmptyTitle,` |
| `subtitle: 'Попробуйте выбрать другой фильтр',` | `subtitle: l10n.customerListFilterEmptySubtitle,` |
| `buttonText: 'Сбросить фильтр',` | `buttonText: l10n.customerListResetFilterButton,` |
| `title: const Text('Новый клиент'),` | `title: Text(AppLocalizations.of(dialogContext)!.customerListAddDialogTitle),` |
| `labelText: 'Имя',` | `labelText: AppLocalizations.of(context)!.customerListNameLabel,` |
| `hintText: 'Введите имя клиента',` | `hintText: AppLocalizations.of(context)!.customerListNameHint,` |
| `labelText: 'Телефон',` (inside `_showAddCustomerDialog`) | `labelText: AppLocalizations.of(context)!.phoneLabel,` |
| `child: const Text('Отмена'),` (inside `_showAddCustomerDialog`) | `child: Text(AppLocalizations.of(dialogContext)!.cancel),` |
| `child: const Text('Добавить'),` | `child: Text(AppLocalizations.of(dialogContext)!.customerListAddConfirm),` |
| `'${customers.length} клиентов  \|  Долг: ${_formatPrice(totalDebt)}',` | `l10n.customerListStatsLine(customers.length.toString(), _formatPrice(totalDebt)),` |

Note: `_showAddCustomerDialog`'s dialog `builder` receives its own
`dialogContext`, not the outer `build(BuildContext context)`'s
`context`/`l10n` — use `AppLocalizations.of(dialogContext)!` inside that
closure, matching the file's own existing scoping.

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart` — expect this file to no longer appear in the offender list (check with `dart run tool/check_i18n.dart 2>&1 | grep customer_list_page` — expect no output).
Run: `flutter analyze` — expect `No issues found!`.
Run: `flutter test test/presentation/pages/customer/ --reporter expanded` (if a test directory exists for this page — check with `ls test/presentation/pages/customer/` first; if none exists, skip this run) — expect all passing.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart lib/presentation/pages/customer/customer_list_page.dart
git commit -m "fix(app): migrate customer_list_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 3: Migrate `expense_list_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/finance/expense_list_page.dart`

Current offenders (all 4, verbatim):
```
85: title: const Text('Удалить расход?'),
86: content: const Text('Это действие нельзя отменить.'),
90: child: const Text('Отмена'),
100: child: const Text('Удалить', style: TextStyle(color: AppColors.error)),
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"cancel"\|"delete"' lib/l10n/app_ru.arb`
Expected: confirms `cancel: "Отмена"` and `delete: "Удалить"` already exist — reuse both.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "expenseListDeleteTitle": "Удалить расход?",
  "actionCannotBeUndone": "Это действие нельзя отменить.",
```

`actionCannotBeUndone` is deliberately unprefixed — it's a generic
confirmation body reused by Tasks 4 and this one (per
`.claude/rules/mobile-l10n.md`'s "reuse a generic key if the string
plausibly belongs elsewhere" rule). Add an `@actionCannotBeUndone`
description only if you find its meaning ambiguous next to any
existing similarly-named key — check first with
`grep -n "CannotBeUndone\|нельзя отменить" lib/l10n/app_ru.arb`.

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

| Find | Replace with |
|---|---|
| `title: const Text('Удалить расход?'),` | `title: Text(AppLocalizations.of(ctx)!.expenseListDeleteTitle),` |
| `content: const Text('Это действие нельзя отменить.'),` | `content: Text(AppLocalizations.of(ctx)!.actionCannotBeUndone),` |
| `child: const Text('Отмена'),` | `child: Text(AppLocalizations.of(ctx)!.cancel),` |
| `child: const Text('Удалить', style: TextStyle(color: AppColors.error)),` | `child: Text(AppLocalizations.of(ctx)!.delete, style: TextStyle(color: AppColors.error)),` |

(The dialog's `builder: (ctx) => AlertDialog(...)` — confirm the actual
parameter name is `ctx` by reading the surrounding code first; use
whatever it's actually called.)

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep expense_list_page` — expect no output.
Run: `flutter analyze` — expect clean.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart lib/presentation/pages/finance/expense_list_page.dart
git commit -m "fix(app): migrate expense_list_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 4: Migrate `discounts_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/settings/discounts_page.dart`

Current offenders (all 14, verbatim):
```
79: title: const Text('Удалить скидку?'),
80: content: Text('Вы уверены, что хотите удалить "$name"?'),
84: child: const Text('Отмена'),
91: child: const Text('Удалить', style: TextStyle(color: AppColors.error)),
131: Text(isEdit ? 'Редактировать скидку' : 'Новая скидка',
137: labelText: 'Название', border: OutlineInputBorder()),
145: ButtonSegment(value: 'percent', label: Text('% Процент')),
146: ButtonSegment(value: 'fixed', label: Text('Сум Фиксированная')),
159: labelText: type == 'percent' ? 'Значение (%)' : 'Значение (TJS)',
168: labelText: 'Мин. сумма заказа (условие, необязательно)',
192: child: Text(isEdit ? 'Сохранить' : 'Создать',
238: title: const Text('Скидки'),
257: ElevatedButton(onPressed: _load, child: const Text('Повторить')),
263: child: Text('Нет скидок. Нажмите + для создания.',
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"cancel"\|"delete"\|"save"\|"create"\|"retry"' lib/l10n/app_ru.arb`
Expected: confirms all five exist (`cancel`, `delete`, `save`, `create`,
`retry`) — reuse all. `actionCannotBeUndone` was already added in Task 3
— reused implicitly is NOT needed here since this dialog's body is the
name-interpolated confirmation, not the generic one.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "discountsDeleteTitle": "Удалить скидку?",
  "discountsDeleteConfirmBody": "Вы уверены, что хотите удалить \"{name}\"?",
  "discountsEditTitle": "Редактировать скидку",
  "discountsNewTitle": "Новая скидка",
  "discountsNameLabel": "Название",
  "discountsTypePercent": "% Процент",
  "discountsTypeFixed": "Сум Фиксированная",
  "discountsValuePercentLabel": "Значение (%)",
  "discountsValueFixedLabel": "Значение (TJS)",
  "discountsMinOrderLabel": "Мин. сумма заказа (условие, необязательно)",
  "discountsPageTitle": "Скидки",
  "discountsEmptyState": "Нет скидок. Нажмите + для создания.",
```

Add placeholder metadata for the interpolated one:

```json
  "@discountsDeleteConfirmBody": {
    "placeholders": {
      "name": { "type": "String" }
    }
  },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

Read the file first to confirm the exact `BuildContext` variable in scope at each of these 14 call sites (some are inside dialog builders with their own `ctx`, some are in the main `build(context)`). Replace:

| Find | Replace with (adjust the context variable to match what's actually in scope) |
|---|---|
| `title: const Text('Удалить скидку?'),` | `title: Text(AppLocalizations.of(ctx)!.discountsDeleteTitle),` |
| `content: Text('Вы уверены, что хотите удалить "$name"?'),` | `content: Text(AppLocalizations.of(ctx)!.discountsDeleteConfirmBody(name)),` |
| `child: const Text('Отмена'),` | `child: Text(AppLocalizations.of(ctx)!.cancel),` |
| `child: const Text('Удалить', style: TextStyle(color: AppColors.error)),` | `child: Text(AppLocalizations.of(ctx)!.delete, style: TextStyle(color: AppColors.error)),` |
| `Text(isEdit ? 'Редактировать скидку' : 'Новая скидка',` | `Text(isEdit ? AppLocalizations.of(context)!.discountsEditTitle : AppLocalizations.of(context)!.discountsNewTitle,` |
| `labelText: 'Название', border: OutlineInputBorder()),` | `labelText: AppLocalizations.of(context)!.discountsNameLabel, border: OutlineInputBorder()),` |
| `ButtonSegment(value: 'percent', label: Text('% Процент')),` | `ButtonSegment(value: 'percent', label: Text(AppLocalizations.of(context)!.discountsTypePercent)),` |
| `ButtonSegment(value: 'fixed', label: Text('Сум Фиксированная')),` | `ButtonSegment(value: 'fixed', label: Text(AppLocalizations.of(context)!.discountsTypeFixed)),` |
| `labelText: type == 'percent' ? 'Значение (%)' : 'Значение (TJS)',` | `labelText: type == 'percent' ? AppLocalizations.of(context)!.discountsValuePercentLabel : AppLocalizations.of(context)!.discountsValueFixedLabel,` |
| `labelText: 'Мин. сумма заказа (условие, необязательно)',` | `labelText: AppLocalizations.of(context)!.discountsMinOrderLabel,` |
| `child: Text(isEdit ? 'Сохранить' : 'Создать',` | `child: Text(isEdit ? AppLocalizations.of(context)!.save : AppLocalizations.of(context)!.create,` |
| `title: const Text('Скидки'),` | `title: Text(AppLocalizations.of(context)!.discountsPageTitle),` |
| `ElevatedButton(onPressed: _load, child: const Text('Повторить')),` | `ElevatedButton(onPressed: _load, child: Text(AppLocalizations.of(context)!.retry)),` |
| `child: Text('Нет скидок. Нажмите + для создания.',` | `child: Text(AppLocalizations.of(context)!.discountsEmptyState,` |

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep discounts_page` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/settings/discounts_page_golden_test.dart --reporter expanded` (this golden test was confirmed to exist earlier — see the CI investigation) — expect it still passes (visible text unchanged).

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart lib/presentation/pages/settings/discounts_page.dart
git commit -m "fix(app): migrate discounts_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 5: Migrate `my_stores_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/settings/my_stores_page.dart`

Current offenders (all 18, verbatim):
```
62: 'GROCERY': 'Продукты',
63: 'CLOTHING': 'Одежда',
64: 'ELECTRONICS': 'Электроника',
65: 'HARDWARE': 'Стройматериалы',
66: 'PHARMACY': 'Аптека',
67: 'OTHER': 'Другое',
111: isEdit ? 'Редактировать магазин' : 'Добавить магазин',
121: labelText: 'Название *',
126: ? 'Введите название'
133: labelText: 'Категория *',
152: labelText: 'Адрес',
160: labelText: 'Телефон',
195: isEdit ? 'Сохранить' : 'Создать',
259: title: const Text('Мои магазины'),
280: child: const Text('Повторить'),
297: 'Нет магазинов',
307: label: const Text('Добавить магазин'),
393: 'Активный',
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"save"\|"create"\|"retry"\|"address"\|"phoneLabel"\|"category"\|"createStoreNameRequiredError"' lib/l10n/app_ru.arb`
Expected: `save`, `create`, `retry`, `address`, `phoneLabel`, `category`
all already exist — reuse them. `createStoreNameRequiredError` also
already exists holding exactly `"Введите название"` — reuse it for
line 126's validator message instead of minting a new key (same meaning:
store-name-required validation text).

Also check whether the `StoreCategory` enum's 6 category labels
(GROCERY/CLOTHING/ELECTRONICS/HARDWARE/PHARMACY/OTHER) are already
localized anywhere else in the app — run:
`grep -rn "'GROCERY':\|'CLOTHING':\|storeCategoryGrocery" lib/ --include="*.dart" | grep -v my_stores_page`.
If another file already has this exact mapping localized, reuse those
keys instead of the new ones below; if not (expected — this is likely
the only place these 6 labels are spelled out), proceed with new keys.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "storeCategoryGrocery": "Продукты",
  "storeCategoryClothing": "Одежда",
  "storeCategoryElectronics": "Электроника",
  "storeCategoryHardware": "Стройматериалы",
  "storeCategoryPharmacy": "Аптека",
  "storeCategoryOther": "Другое",
  "myStoresEditTitle": "Редактировать магазин",
  "myStoresAddTitle": "Добавить магазин",
  "myStoresNameLabel": "Название *",
  "myStoresCategoryLabel": "Категория *",
  "myStoresPageTitle": "Мои магазины",
  "myStoresEmptyState": "Нет магазинов",
  "myStoresAddButton": "Добавить магазин",
  "myStoresActiveStatus": "Активный",
```

Note `storeCategoryGrocery` etc. are unprefixed-by-screen (just
`storeCategory*`) rather than `myStoresCategory*`, since these are
enum-value labels that plausibly get reused anywhere a store's category
is displayed (product forms, admin-style screens), not something
specific to "my stores." `myStoresAddTitle` and `myStoresAddButton` hold
the same Russian text ("Добавить магазин") but appear in genuinely
different UI roles (a dialog title vs. a button) — per convention, add
an `@myStoresAddButton` description stating it's the same text as
`myStoresAddTitle` used in a different role, OR just reuse
`myStoresAddTitle` for both call sites since the value is identical;
prefer the latter (one key, `myStoresAddTitle`) unless doing so reads
awkwardly at the button call site — use judgment, both are acceptable,
but don't create two keys with truly identical values without a reason.

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

| Find | Replace with |
|---|---|
| `'GROCERY': 'Продукты',` | `'GROCERY': AppLocalizations.of(context)!.storeCategoryGrocery,` (verify this map is built inside a method with `context` in scope — if it's a `static const` field as the surrounding code suggests, it must be converted to a method or getter that takes `BuildContext`; read the file first and adjust the map's declaration accordingly, since a `static const Map` cannot call `AppLocalizations.of(context)`) |
| `'CLOTHING': 'Одежда',` | `'CLOTHING': AppLocalizations.of(context)!.storeCategoryClothing,` |
| `'ELECTRONICS': 'Электроника',` | `'ELECTRONICS': AppLocalizations.of(context)!.storeCategoryElectronics,` |
| `'HARDWARE': 'Стройматериалы',` | `'HARDWARE': AppLocalizations.of(context)!.storeCategoryHardware,` |
| `'PHARMACY': 'Аптека',` | `'PHARMACY': AppLocalizations.of(context)!.storeCategoryPharmacy,` |
| `'OTHER': 'Другое',` | `'OTHER': AppLocalizations.of(context)!.storeCategoryOther,` |
| `isEdit ? 'Редактировать магазин' : 'Добавить магазин',` | `isEdit ? AppLocalizations.of(context)!.myStoresEditTitle : AppLocalizations.of(context)!.myStoresAddTitle,` |
| `labelText: 'Название *',` | `labelText: AppLocalizations.of(context)!.myStoresNameLabel,` |
| `? 'Введите название'` | `? AppLocalizations.of(context)!.createStoreNameRequiredError` |
| `labelText: 'Категория *',` | `labelText: AppLocalizations.of(context)!.myStoresCategoryLabel,` |
| `labelText: 'Адрес',` | `labelText: AppLocalizations.of(context)!.address,` |
| `labelText: 'Телефон',` | `labelText: AppLocalizations.of(context)!.phoneLabel,` |
| `isEdit ? 'Сохранить' : 'Создать',` | `isEdit ? AppLocalizations.of(context)!.save : AppLocalizations.of(context)!.create,` |
| `title: const Text('Мои магазины'),` | `title: Text(AppLocalizations.of(context)!.myStoresPageTitle),` |
| `child: const Text('Повторить'),` | `child: Text(AppLocalizations.of(context)!.retry),` |
| `'Нет магазинов',` | `AppLocalizations.of(context)!.myStoresEmptyState,` |
| `label: const Text('Добавить магазин'),` | `label: Text(AppLocalizations.of(context)!.myStoresAddTitle),` |
| `'Активный',` | `AppLocalizations.of(context)!.myStoresActiveStatus,` |

**Important:** the `_categories` map (lines 61-68) is declared
`static const` in the current file. `AppLocalizations.of(context)` needs
a `BuildContext` and cannot be called in a `static const` initializer.
Read the surrounding code (where `_categories` is consumed —
`DropdownButtonFormField`'s items, most likely) and convert it to a
method (e.g. `Map<String, String> _categoryLabels(BuildContext context)
=> {...}`) called with the local `context` wherever `_categories` is
currently referenced, rather than trying to keep it `const`.

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep my_stores_page` — expect no output.
Run: `flutter analyze` — expect clean.
Run: `flutter test test/presentation/pages/settings/my_stores_page_golden_test.dart --reporter expanded` (confirmed to exist earlier in this session's CI investigation) — expect it still passes.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart lib/presentation/pages/settings/my_stores_page.dart
git commit -m "fix(app): migrate my_stores_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 6: Migrate `settings_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/settings/settings_page.dart`
- Modify: `tool/i18n-allowlist.txt` (add the deliberate exceptions — see Step 1)

Current offenders (all 41, verbatim):
```
145: return 'Тоҷикӣ';
147: return 'Ўзбекча';
150: return 'Русский';
169: return 'Старт';
171: return 'Бизнес';
173: return 'Премиум';
183: title: const Text('Выход'),
184: content: const Text('Вы уверены, что хотите выйти?'),
188: child: const Text('Отмена'),
197: child: const Text('Выйти', style: TextStyle(color: AppColors.error)),
208: title: const Text('Доступно на тарифе PREMIUM'),
210: 'Интеграция с интернет-магазином доступна на тарифе PREMIUM. Перейдите на PREMIUM, чтобы синхронизировать остатки и заказы с вашим сайтом.',
215: child: const Text('Позже'),
222: child: const Text('Перейти к тарифам'),
242: child: Text('Настройки',
321: _buildSectionLabel('Магазин'),
324: _buildTile(Icons.storefront_outlined, 'Мои магазины',
327: _buildTile(Icons.people_outlined, 'Продавцы',
330: _buildTile(Icons.admin_panel_settings_outlined, 'Роли и доступы',
333: _buildTile(Icons.discount_outlined, 'Скидки',
336: _buildTile(Icons.card_giftcard_outlined, 'Программа лояльности',
339: _buildTile(Icons.receipt_long_outlined, 'Шаблоны чеков',
345: _buildSectionLabel('Интеграции'),
348: _buildTile(Icons.send_outlined, 'Telegram-бот',
350: ? (_telegramConnected ? 'Подключён' : 'Не подключён')
357: _buildTile(Icons.point_of_sale_outlined, 'ККМ / Фискализация',
360: _buildTile(Icons.print_outlined, 'Принтер чеков',
363: _buildTile(Icons.qr_code_scanner_outlined, 'Сканер',
375: 'Интернет-магазин',
390: _buildSectionLabel('Приложение'),
393: _buildToggleTile(Icons.notifications_outlined, 'Уведомления',
415: 'Тёмная тема',
427: _buildTile(Icons.language_outlined, 'Язык',
432: _buildTile(Icons.cloud_done_outlined, 'Офлайн-режим',
444: ? 'Синхронизировано'
445: : '$_pendingSyncOps в очереди',
458: _buildSectionLabel('Подписка'),
462: String planTitle = 'Тариф';
466: ? '$planLabel до ${DateFormat('dd.MM.yyyy').format(sub.expiresAt!)}'
471: trailing: const Text('Сменить тариф',
490: child: const Text('Выйти из аккаунта',
```

- [ ] **Step 1: Handle the deliberate exceptions first**

Per the design spec, the language names (lines 145/147/150: "Тоҷикӣ",
"Ўзбекча", "Русский") and tariff brand names (lines 169/171/173:
"Старт", "Бизнес", "Премиум") are proper nouns, not ordinary UI text —
leave them hardcoded. Add these 6 lines to `tool/i18n-allowlist.txt`
directly (not via `--dump-allowlist`, since this needs a comment; append
by hand):

```
# Deliberate exceptions — proper nouns, not translatable UI text (see
# docs/superpowers/specs/2026-09-27-i18n-nine-file-migration-design.md).
# A language's own name doesn't change based on the current UI locale;
# tariff names are product brand names.
lib/presentation/pages/settings/settings_page.dart::'Тоҷикӣ'
lib/presentation/pages/settings/settings_page.dart::'Ўзбекча'
lib/presentation/pages/settings/settings_page.dart::'Русский'
lib/presentation/pages/settings/settings_page.dart::'Старт'
lib/presentation/pages/settings/settings_page.dart::'Бизнес'
lib/presentation/pages/settings/settings_page.dart::'Премиум'
```

(Confirm the exact quoted form each matches via
`dart run tool/check_i18n.dart 2>&1 | grep settings_page.dart` after
Step 5 below, in case the regex captured a slightly different substring
than assumed here — adjust these 6 lines to match exactly if so.)

- [ ] **Step 2: Check for reusable existing keys**

Run: `grep -n '"cancel"\|"darkMode"\|"loyaltySettingsTitle"' lib/l10n/app_ru.arb`
Expected: `cancel` exists (reuse for line 188); `darkMode: "Тёмная тема"`
already exists (reuse for line 415); `loyaltySettingsTitle: "Программа
лояльности"` already exists (reuse for line 336).

- [ ] **Step 3: Add new keys to `app_ru.arb`**

```json
  "settingsLogoutTitle": "Выход",
  "settingsLogoutConfirmBody": "Вы уверены, что хотите выйти?",
  "settingsLogoutConfirm": "Выйти",
  "settingsPremiumGateTitle": "Доступно на тарифе PREMIUM",
  "settingsPremiumGateBody": "Интеграция с интернет-магазином доступна на тарифе PREMIUM. Перейдите на PREMIUM, чтобы синхронизировать остатки и заказы с вашим сайтом.",
  "settingsPremiumGateLater": "Позже",
  "settingsPremiumGateUpgrade": "Перейти к тарифам",
  "settingsPageTitle": "Настройки",
  "settingsSectionStore": "Магазин",
  "settingsTileMyStores": "Мои магазины",
  "settingsTileStaff": "Продавцы",
  "settingsTileRoles": "Роли и доступы",
  "settingsTileDiscounts": "Скидки",
  "settingsTileReceiptTemplates": "Шаблоны чеков",
  "settingsSectionIntegrations": "Интеграции",
  "settingsTileTelegramBot": "Telegram-бот",
  "settingsConnected": "Подключён",
  "settingsNotConnected": "Не подключён",
  "settingsTileKkm": "ККМ / Фискализация",
  "settingsTilePrinter": "Принтер чеков",
  "settingsTileScanner": "Сканер",
  "settingsTileEcommerce": "Интернет-магазин",
  "settingsSectionApp": "Приложение",
  "settingsTileNotifications": "Уведомления",
  "settingsTileLanguage": "Язык",
  "settingsTileOfflineMode": "Офлайн-режим",
  "settingsSynced": "Синхронизировано",
  "settingsPendingSyncOps": "{count} в очереди",
  "settingsSectionSubscription": "Подписка",
  "settingsPlanFallbackLabel": "Тариф",
  "settingsPlanUntilDate": "{plan} до {date}",
  "settingsChangePlan": "Сменить тариф",
  "settingsLogoutButton": "Выйти из аккаунта",
```

Placeholder metadata (both interpolated keys, `String`-typed per
convention — pre-format `count` and `date` at the call site):

```json
  "@settingsPendingSyncOps": {
    "placeholders": {
      "count": { "type": "String" }
    }
  },
  "@settingsPlanUntilDate": {
    "placeholders": {
      "plan": { "type": "String" },
      "date": { "type": "String" }
    }
  },
```

- [ ] **Step 4: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 5: Replace literals**

Read the file first to identify the exact `BuildContext`/`l10n` binding
already in scope at each call site (this file likely already has a
`build(BuildContext context)` — check whether it already declares a
local `l10n` variable before adding a second one). Apply:

| Find | Replace with |
|---|---|
| `title: const Text('Выход'),` | `title: Text(l10n.settingsLogoutTitle),` |
| `content: const Text('Вы уверены, что хотите выйти?'),` | `content: Text(l10n.settingsLogoutConfirmBody),` |
| `child: const Text('Отмена'),` | `child: Text(l10n.cancel),` |
| `child: const Text('Выйти', style: TextStyle(color: AppColors.error)),` | `child: Text(l10n.settingsLogoutConfirm, style: TextStyle(color: AppColors.error)),` |
| `title: const Text('Доступно на тарифе PREMIUM'),` | `title: Text(l10n.settingsPremiumGateTitle),` |
| `'Интеграция с интернет-магазином доступна на тарифе PREMIUM. Перейдите на PREMIUM, чтобы синхронизировать остатки и заказы с вашим сайтом.',` | `l10n.settingsPremiumGateBody,` |
| `child: const Text('Позже'),` | `child: Text(l10n.settingsPremiumGateLater),` |
| `child: const Text('Перейти к тарифам'),` | `child: Text(l10n.settingsPremiumGateUpgrade),` |
| `child: Text('Настройки',` | `child: Text(l10n.settingsPageTitle,` |
| `_buildSectionLabel('Магазин'),` | `_buildSectionLabel(l10n.settingsSectionStore),` |
| `_buildTile(Icons.storefront_outlined, 'Мои магазины',` | `_buildTile(Icons.storefront_outlined, l10n.settingsTileMyStores,` |
| `_buildTile(Icons.people_outlined, 'Продавцы',` | `_buildTile(Icons.people_outlined, l10n.settingsTileStaff,` |
| `_buildTile(Icons.admin_panel_settings_outlined, 'Роли и доступы',` | `_buildTile(Icons.admin_panel_settings_outlined, l10n.settingsTileRoles,` |
| `_buildTile(Icons.discount_outlined, 'Скидки',` | `_buildTile(Icons.discount_outlined, l10n.settingsTileDiscounts,` |
| `_buildTile(Icons.card_giftcard_outlined, 'Программа лояльности',` | `_buildTile(Icons.card_giftcard_outlined, l10n.loyaltySettingsTitle,` |
| `_buildTile(Icons.receipt_long_outlined, 'Шаблоны чеков',` | `_buildTile(Icons.receipt_long_outlined, l10n.settingsTileReceiptTemplates,` |
| `_buildSectionLabel('Интеграции'),` | `_buildSectionLabel(l10n.settingsSectionIntegrations),` |
| `_buildTile(Icons.send_outlined, 'Telegram-бот',` | `_buildTile(Icons.send_outlined, l10n.settingsTileTelegramBot,` |
| `? (_telegramConnected ? 'Подключён' : 'Не подключён')` | `? (_telegramConnected ? l10n.settingsConnected : l10n.settingsNotConnected)` |
| `_buildTile(Icons.point_of_sale_outlined, 'ККМ / Фискализация',` | `_buildTile(Icons.point_of_sale_outlined, l10n.settingsTileKkm,` |
| `_buildTile(Icons.print_outlined, 'Принтер чеков',` | `_buildTile(Icons.print_outlined, l10n.settingsTilePrinter,` |
| `_buildTile(Icons.qr_code_scanner_outlined, 'Сканер',` | `_buildTile(Icons.qr_code_scanner_outlined, l10n.settingsTileScanner,` |
| `'Интернет-магазин',` | `l10n.settingsTileEcommerce,` |
| `_buildSectionLabel('Приложение'),` | `_buildSectionLabel(l10n.settingsSectionApp),` |
| `_buildToggleTile(Icons.notifications_outlined, 'Уведомления',` | `_buildToggleTile(Icons.notifications_outlined, l10n.settingsTileNotifications,` |
| `'Тёмная тема',` | `l10n.darkMode,` |
| `_buildTile(Icons.language_outlined, 'Язык',` | `_buildTile(Icons.language_outlined, l10n.settingsTileLanguage,` |
| `_buildTile(Icons.cloud_done_outlined, 'Офлайн-режим',` | `_buildTile(Icons.cloud_done_outlined, l10n.settingsTileOfflineMode,` |
| `? 'Синхронизировано'` | `? l10n.settingsSynced` |
| `: '$_pendingSyncOps в очереди',` | `: l10n.settingsPendingSyncOps(_pendingSyncOps.toString()),` |
| `_buildSectionLabel('Подписка'),` | `_buildSectionLabel(l10n.settingsSectionSubscription),` |
| `String planTitle = 'Тариф';` | `String planTitle = l10n.settingsPlanFallbackLabel;` |
| `? '$planLabel до ${DateFormat('dd.MM.yyyy').format(sub.expiresAt!)}'` | `? l10n.settingsPlanUntilDate(planLabel, DateFormat('dd.MM.yyyy').format(sub.expiresAt!))` |
| `trailing: const Text('Сменить тариф',` | `trailing: Text(l10n.settingsChangePlan,` |
| `child: const Text('Выйти из аккаунта',` | `child: Text(l10n.settingsLogoutButton,` |

**Note on line 339** (`'Шаблоны чеков'`, receipt templates): this is a
distinct settings destination from Discounts — it has its own key,
`settingsTileReceiptTemplates`, not a reuse of `settingsTileDiscounts`.
Add `"settingsTileReceiptTemplates": "Шаблоны чеков",` to the Step 3 key
list above (it was omitted there — add it now alongside the others).

- [ ] **Step 6: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep settings_page` — expect
only the 6 deliberately-allow-listed proper-noun lines to not appear at
all (they're covered by Step 1's allow-list entries, so truly zero
output is expected, not "6 remaining").
Run: `flutter analyze` — expect clean.

- [ ] **Step 7: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart lib/presentation/pages/settings/settings_page.dart tool/i18n-allowlist.txt
git commit -m "fix(app): migrate settings_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 7: Migrate `payroll_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/payroll/payroll_page.dart`

Current offenders (all 35, verbatim):
```
103: title: const Text('Выплатить всем'),
104: content: const Text('Вы уверены, что хотите выплатить зарплату всем сотрудникам?'),
108: child: const Text('Отмена'),
119: child: const Text('Выплатить', style: TextStyle(color: AppColors.onPrimary)),
130: title: const Text('Удалить корректировку?'),
139: child: const Text('Отмена'),
151: child: const Text('Удалить', style: TextStyle(color: AppColors.onPrimary)),
169: appBar: AppBar(title: const Text('Зарплата')),
193: text: 'Рассчитать',
239: title: 'Расчёт зарплаты',
240: subtitle: 'Выберите месяц и нажмите "Рассчитать" для расчёта зарплаты сотрудников',
255: 'Нет данных по зарплате',
260: 'Выберите месяц и нажмите "Рассчитать"',
307: 'Итого: ${period.totalAmount.toStringAsFixed(2)} TJS',
314: tooltip: 'Добавить корректировку',
349: 'Нет данных по сотрудникам',
365: text: 'Выплатить всем',
396: 'Январь',
397: 'Февраль',
398: 'Март',
399: 'Апрель',
400: 'Май',
401: 'Июнь',
402: 'Июль',
403: 'Август',
404: 'Сентябрь',
405: 'Октябрь',
406: 'Ноябрь',
407: 'Декабрь',
413: return 'Рассчитано';
415: return 'Частично оплачено';
417: return 'Оплачено';
494: 'Итого',
513: 'Выплачено',
533: 'Сотрудники',
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"cancel"\|"delete"\|"calculatePayroll"' lib/l10n/app_ru.arb`
Expected: `cancel` exists (reuse for both "Отмена" occurrences).
`delete` exists but note lines 108/139/151's "Удалить"/"Отмена" belong to
TWO different dialogs (mass-payout confirm vs. delete-adjustment
confirm) — reuse `cancel`/`delete` for both regardless, they're the
same generic action. `calculatePayroll: "Рассчитать зарплату"` already
exists — this is NOT the same text as line 193's bare `'Рассчитать'`
(a compact button label) or line 240/260's embedded `"Рассчитать"`
(quoted inline reference to that same button) — do not force-reuse
`calculatePayroll` for the bare "Рассчитать" button text; mint
`payrollCalculateButton: "Рассчитать"` instead, and for lines
240/260 where "Рассчитать" appears embedded in a longer sentence in
quotes, keep it as part of that sentence's own key (interpolation not
needed — the quotes are literal punctuation in the Russian sentence,
not a reference to a shared key).

Also check the 12 month names against `month_selector.dart`'s identical
list (found during design/spec research) — run:
`grep -n "'Январь'" lib/presentation/widgets/payroll/month_selector.dart`.
That file is NOT in this plan's scope (not one of the 9 files), so do
NOT modify it — but DO mint the new month-name keys as generic,
unprefixed keys (`monthJanuary` etc., not `payrollMonthJanuary`) so a
future task migrating `month_selector.dart` can reuse them instead of
duplicating.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "payrollPayAllTitle": "Выплатить всем",
  "payrollPayAllConfirmBody": "Вы уверены, что хотите выплатить зарплату всем сотрудникам?",
  "payrollPayAllConfirm": "Выплатить",
  "payrollDeleteAdjustmentTitle": "Удалить корректировку?",
  "payrollPageTitle": "Зарплата",
  "payrollCalculateButton": "Рассчитать",
  "payrollCalculateEmptyTitle": "Расчёт зарплаты",
  "payrollCalculateEmptySubtitle": "Выберите месяц и нажмите \"Рассчитать\" для расчёта зарплаты сотрудников",
  "payrollNoDataTitle": "Нет данных по зарплате",
  "payrollNoDataSubtitle": "Выберите месяц и нажмите \"Рассчитать\"",
  "payrollTotalLine": "Итого: {amount} TJS",
  "payrollAddAdjustmentTooltip": "Добавить корректировку",
  "payrollNoStaffData": "Нет данных по сотрудникам",
  "monthJanuary": "Январь",
  "monthFebruary": "Февраль",
  "monthMarch": "Март",
  "monthApril": "Апрель",
  "monthMay": "Май",
  "monthJune": "Июнь",
  "monthJuly": "Июль",
  "monthAugust": "Август",
  "monthSeptember": "Сентябрь",
  "monthOctober": "Октябрь",
  "monthNovember": "Ноябрь",
  "monthDecember": "Декабрь",
  "payrollStatusCalculated": "Рассчитано",
  "payrollStatusPartiallyPaid": "Частично оплачено",
  "payrollStatusPaid": "Оплачено",
  "payrollTotalLabel": "Итого",
  "payrollPaidLabel": "Выплачено",
  "payrollStaffSectionTitle": "Сотрудники",
```

Placeholder metadata:

```json
  "@payrollTotalLine": {
    "placeholders": {
      "amount": { "type": "String" }
    }
  },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

Read the file first to confirm which `BuildContext` is in scope at each
call site — the mass-payout dialog (lines ~103-119) and the
delete-adjustment dialog (lines ~130-151) each have their own dialog
`ctx`, distinct from the main page's `build(context)`, which may already
bind a local `l10n`. Apply:

| Find | Replace with |
|---|---|
| `title: const Text('Выплатить всем'),` | `title: Text(AppLocalizations.of(ctx)!.payrollPayAllTitle),` |
| `content: const Text('Вы уверены, что хотите выплатить зарплату всем сотрудникам?'),` | `content: Text(AppLocalizations.of(ctx)!.payrollPayAllConfirmBody),` |
| `child: const Text('Отмена'),` (mass-payout dialog, ~line 108) | `child: Text(AppLocalizations.of(ctx)!.cancel),` |
| `child: const Text('Выплатить', style: TextStyle(color: AppColors.onPrimary)),` | `child: Text(AppLocalizations.of(ctx)!.payrollPayAllConfirm, style: TextStyle(color: AppColors.onPrimary)),` |
| `title: const Text('Удалить корректировку?'),` | `title: Text(AppLocalizations.of(ctx)!.payrollDeleteAdjustmentTitle),` |
| `child: const Text('Отмена'),` (delete-adjustment dialog, ~line 139) | `child: Text(AppLocalizations.of(ctx)!.cancel),` |
| `child: const Text('Удалить', style: TextStyle(color: AppColors.onPrimary)),` | `child: Text(AppLocalizations.of(ctx)!.delete, style: TextStyle(color: AppColors.onPrimary)),` |
| `appBar: AppBar(title: const Text('Зарплата')),` | `appBar: AppBar(title: Text(l10n.payrollPageTitle)),` |
| `text: 'Рассчитать',` (line 193) | `text: l10n.payrollCalculateButton,` |
| `title: 'Расчёт зарплаты',` | `title: l10n.payrollCalculateEmptyTitle,` |
| `subtitle: 'Выберите месяц и нажмите "Рассчитать" для расчёта зарплаты сотрудников',` | `subtitle: l10n.payrollCalculateEmptySubtitle,` |
| `'Нет данных по зарплате',` | `l10n.payrollNoDataTitle,` |
| `'Выберите месяц и нажмите "Рассчитать"',` | `l10n.payrollNoDataSubtitle,` |
| `'Итого: ${period.totalAmount.toStringAsFixed(2)} TJS',` | `l10n.payrollTotalLine(period.totalAmount.toStringAsFixed(2)),` |
| `tooltip: 'Добавить корректировку',` | `tooltip: l10n.payrollAddAdjustmentTooltip,` |
| `'Нет данных по сотрудникам',` | `l10n.payrollNoStaffData,` |
| `text: 'Выплатить всем',` (line 365 — the FAB/button that opens the mass-payout dialog, distinct from the dialog's own confirm button) | `text: l10n.payrollPayAllTitle,` |
| `return 'Рассчитано';` | `return l10n.payrollStatusCalculated;` (thread `context`/`l10n` into this function's parameters if it doesn't already receive one — read its signature first) |
| `return 'Частично оплачено';` | `return l10n.payrollStatusPartiallyPaid;` |
| `return 'Оплачено';` | `return l10n.payrollStatusPaid;` |
| `'Итого',` (line 494) | `l10n.payrollTotalLabel,` |
| `'Выплачено',` | `l10n.payrollPaidLabel,` |
| `'Сотрудники',` | `l10n.payrollStaffSectionTitle,` |

For the month list (lines 396-407), replace the 12-element list literal
with:

```dart
[l10n.monthJanuary, l10n.monthFebruary, l10n.monthMarch, l10n.monthApril,
 l10n.monthMay, l10n.monthJune, l10n.monthJuly, l10n.monthAugust,
 l10n.monthSeptember, l10n.monthOctober, l10n.monthNovember, l10n.monthDecember]
```

Read the surrounding declaration first — if it's currently a `static
const` or `const` list (the offender list's format suggests it's a
plain literal, possibly already non-const), it must become a
non-`const` list built inside a method that receives `context`, same
pattern as Task 5's category map.

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep payroll_page.dart` — expect no output.
Run: `flutter analyze` — expect clean.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart lib/presentation/pages/payroll/payroll_page.dart
git commit -m "fix(app): migrate payroll_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 8: Migrate `payroll_staff_card.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/widgets/payroll/payroll_staff_card.dart`

Current offenders (all 10, verbatim):
```
26: return 'Владелец';
28: return 'Админ';
30: return 'Кассир';
32: return 'Складовщик';
82: entry.isPaid ? 'Оплачено' : 'Не оплачено',
97: _PayrollItem(label: 'Оклад', value: '${entry.baseSalary.toStringAsFixed(0)} TJS'),
98: _PayrollItem(label: 'Комиссия', value: '${entry.commission.toStringAsFixed(0)} TJS'),
100: label: 'Итого',
135: tooltip: 'Удалить',
155: child: const Text('Выплатить'),
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"warehouse"\|"delete"' lib/l10n/app_ru.arb`
Expected: `warehouse: "Складовщик"` already exists (reuse for line 32).
`delete: "Удалить"` exists (reuse for the tooltip at line 135). Also
check for existing staff-role labels covering "Владелец"/"Админ"/
"Кассир" — run: `grep -n '"owner"\|"admin"\|"cashier"' lib/l10n/app_ru.arb`
and reuse whatever's found instead of the new keys below if an exact
match turns up. `payrollStatusPaid: "Оплачено"` was just added in
Task 7 — reuse it for line 82's true branch instead of minting a
duplicate.

- [ ] **Step 2: Add new keys to `app_ru.arb`**

(Skip any of these where Step 1 found a reusable existing key instead.)

```json
  "roleOwner": "Владелец",
  "roleAdmin": "Админ",
  "roleCashier": "Кассир",
  "payrollStaffCardNotPaid": "Не оплачено",
  "payrollStaffCardSalaryLabel": "Оклад",
  "payrollStaffCardCommissionLabel": "Комиссия",
  "payrollStaffCardTotalLabel": "Итого",
  "payrollStaffCardPayButton": "Выплатить",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

| Find | Replace with |
|---|---|
| `return 'Владелец';` | `return AppLocalizations.of(context)!.roleOwner;` |
| `return 'Админ';` | `return AppLocalizations.of(context)!.roleAdmin;` |
| `return 'Кассир';` | `return AppLocalizations.of(context)!.roleCashier;` |
| `return 'Складовщик';` | `return AppLocalizations.of(context)!.warehouse;` |
| `entry.isPaid ? 'Оплачено' : 'Не оплачено',` | `entry.isPaid ? AppLocalizations.of(context)!.payrollStatusPaid : AppLocalizations.of(context)!.payrollStaffCardNotPaid,` |
| `_PayrollItem(label: 'Оклад', value: '${entry.baseSalary.toStringAsFixed(0)} TJS'),` | `_PayrollItem(label: AppLocalizations.of(context)!.payrollStaffCardSalaryLabel, value: '${entry.baseSalary.toStringAsFixed(0)} TJS'),` |
| `_PayrollItem(label: 'Комиссия', value: '${entry.commission.toStringAsFixed(0)} TJS'),` | `_PayrollItem(label: AppLocalizations.of(context)!.payrollStaffCardCommissionLabel, value: '${entry.commission.toStringAsFixed(0)} TJS'),` |
| `label: 'Итого',` | `label: AppLocalizations.of(context)!.payrollStaffCardTotalLabel,` |
| `tooltip: 'Удалить',` | `tooltip: AppLocalizations.of(context)!.delete,` |
| `child: const Text('Выплатить'),` | `child: Text(AppLocalizations.of(context)!.payrollStaffCardPayButton),` |

The role-name function (lines 26-32) must take a `BuildContext`
parameter if it doesn't already — read the surrounding function
signature first and thread `context` through from its call site if
needed.

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep payroll_staff_card` — expect no output.
Run: `flutter analyze` — expect clean.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart lib/presentation/widgets/payroll/payroll_staff_card.dart
git commit -m "fix(app): migrate payroll_staff_card.dart hardcoded strings to AppLocalizations"
```

---

### Task 9: Migrate `shifts_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/shifts/shifts_page.dart`

Current offenders (all 22, verbatim):
```
49: title: const Text('Закрыть смену'),
55: const Text('Введите сумму наличных в кассе:'),
59: label: 'Сумма наличных',
63: if (v == null || v.isEmpty) return 'Введите сумму';
64: if (double.tryParse(v) == null) return 'Некорректная сумма';
65: if (double.parse(v) < 0) return 'Сумма не может быть отрицательной';
75: child: const Text('Отмена'),
89: child: const Text('Закрыть', style: TextStyle(color: AppColors.onPrimary)),
101: return '$hoursч $minutesм';
118: const Text('Смены',
133: child: const Text('Открыть смену', style: TextStyle(fontSize: 13)),
178: const Text('История смен',
188: title: 'Нет смен',
189: subtitle: 'Откройте смену, чтобы начать приём платежей',
226: const Text('Текущая смена',
235: child: const Text('Активна',
241: Text('Кассир: ${shift.staffName ?? 'Не указан'}',
244: Text('Открыта: ${timeFormat.format(shift.openedAt)}  •  Время работы: ${_formatDuration(shift.openedAt)}',
247: Text('Продаж: ${shift.salesCount}  |  Сумма: ${_formatPrice(shift.salesTotal)}',
259: child: const Text('Закрыть смену', style: TextStyle(fontWeight: FontWeight.w600)),
300: '${timeFormat.format(shift.openedAt)}–${shift.closedAt != null ? timeFormat.format(shift.closedAt!) : '...'}  •  ${shift.salesCount} продаж  •  ${_formatPrice(shift.salesTotal)}',
315: shift.closedAt != null ? 'Сдано' : 'Открыта',
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"cancel"\|"roleCashier"' lib/l10n/app_ru.arb`
Expected: `cancel` exists (reuse for line 75). `roleCashier` was just
added in Task 8 holding "Кассир" — line 241's `'Кассир: ...'` is a
label-plus-value composite, not a bare role name, so it needs its own
interpolated key rather than reusing `roleCashier` directly (see Step 2).

- [ ] **Step 2: Add new keys to `app_ru.arb`**

```json
  "shiftsCloseTitle": "Закрыть смену",
  "shiftsCloseCashPrompt": "Введите сумму наличных в кассе:",
  "shiftsCashAmountLabel": "Сумма наличных",
  "shiftsCashAmountRequired": "Введите сумму",
  "shiftsCashAmountInvalid": "Некорректная сумма",
  "shiftsCashAmountNegative": "Сумма не может быть отрицательной",
  "shiftsCloseConfirm": "Закрыть",
  "shiftsDurationFormat": "{hours}ч {minutes}м",
  "shiftsPageTitle": "Смены",
  "shiftsOpenButton": "Открыть смену",
  "shiftsHistoryTitle": "История смен",
  "shiftsEmptyTitle": "Нет смен",
  "shiftsEmptySubtitle": "Откройте смену, чтобы начать приём платежей",
  "shiftsCurrentTitle": "Текущая смена",
  "shiftsActiveStatus": "Активна",
  "shiftsCashierLine": "Кассир: {name}",
  "shiftsUnknownCashier": "Не указан",
  "shiftsOpenedLine": "Открыта: {time}  •  Время работы: {duration}",
  "shiftsSalesLine": "Продаж: {count}  |  Сумма: {amount}",
  "shiftsCloseButtonLong": "Закрыть смену",
  "shiftsHistoryRowLine": "{openedTime}–{closedTime}  •  {count} продаж  •  {amount}",
  "shiftsClosedStatus": "Сдано",
  "shiftsOpenStatus": "Открыта",
```

Placeholder metadata (all `String`, per convention):

```json
  "@shiftsDurationFormat": {
    "placeholders": {
      "hours": { "type": "String" },
      "minutes": { "type": "String" }
    }
  },
  "@shiftsCashierLine": {
    "placeholders": {
      "name": { "type": "String" }
    }
  },
  "@shiftsOpenedLine": {
    "placeholders": {
      "time": { "type": "String" },
      "duration": { "type": "String" }
    }
  },
  "@shiftsSalesLine": {
    "placeholders": {
      "count": { "type": "String" },
      "amount": { "type": "String" }
    }
  },
  "@shiftsHistoryRowLine": {
    "placeholders": {
      "openedTime": { "type": "String" },
      "closedTime": { "type": "String" },
      "count": { "type": "String" },
      "amount": { "type": "String" }
    }
  },
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace literals**

Read the file first to confirm which `BuildContext` is in scope at each
call site — the close-shift dialog (lines ~49-89) has its own `ctx`,
distinct from the main page's `build(context)`, which may already bind
a local `l10n`. Apply:

| Find | Replace with |
|---|---|
| `title: const Text('Закрыть смену'),` (dialog title, ~line 49) | `title: Text(AppLocalizations.of(ctx)!.shiftsCloseTitle),` |
| `const Text('Введите сумму наличных в кассе:'),` | `Text(AppLocalizations.of(ctx)!.shiftsCloseCashPrompt),` |
| `label: 'Сумма наличных',` | `label: AppLocalizations.of(ctx)!.shiftsCashAmountLabel,` |
| `if (v == null \|\| v.isEmpty) return 'Введите сумму';` | `if (v == null \|\| v.isEmpty) return AppLocalizations.of(ctx)!.shiftsCashAmountRequired;` |
| `if (double.tryParse(v) == null) return 'Некорректная сумма';` | `if (double.tryParse(v) == null) return AppLocalizations.of(ctx)!.shiftsCashAmountInvalid;` |
| `if (double.parse(v) < 0) return 'Сумма не может быть отрицательной';` | `if (double.parse(v) < 0) return AppLocalizations.of(ctx)!.shiftsCashAmountNegative;` |
| `child: const Text('Отмена'),` | `child: Text(AppLocalizations.of(ctx)!.cancel),` |
| `child: const Text('Закрыть', style: TextStyle(color: AppColors.onPrimary)),` | `child: Text(AppLocalizations.of(ctx)!.shiftsCloseConfirm, style: TextStyle(color: AppColors.onPrimary)),` |
| `return '$hoursч $minutesм';` | `return l10n.shiftsDurationFormat(hours.toString(), minutes.toString());` (thread `context`/`l10n` into this helper's parameters if it doesn't already receive one — read its signature first) |
| `const Text('Смены',` | `Text(l10n.shiftsPageTitle,` |
| `child: const Text('Открыть смену', style: TextStyle(fontSize: 13)),` | `child: Text(l10n.shiftsOpenButton, style: TextStyle(fontSize: 13)),` |
| `const Text('История смен',` | `Text(l10n.shiftsHistoryTitle,` |
| `title: 'Нет смен',` | `title: l10n.shiftsEmptyTitle,` |
| `subtitle: 'Откройте смену, чтобы начать приём платежей',` | `subtitle: l10n.shiftsEmptySubtitle,` |
| `const Text('Текущая смена',` | `Text(l10n.shiftsCurrentTitle,` |
| `child: const Text('Активна',` | `child: Text(l10n.shiftsActiveStatus,` |
| `Text('Кассир: ${shift.staffName ?? 'Не указан'}',` | `Text(l10n.shiftsCashierLine(shift.staffName ?? l10n.shiftsUnknownCashier),` |
| `Text('Открыта: ${timeFormat.format(shift.openedAt)}  •  Время работы: ${_formatDuration(shift.openedAt)}',` | `Text(l10n.shiftsOpenedLine(timeFormat.format(shift.openedAt), _formatDuration(shift.openedAt)),` |
| `Text('Продаж: ${shift.salesCount}  \|  Сумма: ${_formatPrice(shift.salesTotal)}',` | `Text(l10n.shiftsSalesLine(shift.salesCount.toString(), _formatPrice(shift.salesTotal)),` |
| `child: const Text('Закрыть смену', style: TextStyle(fontWeight: FontWeight.w600)),` | `child: Text(l10n.shiftsCloseButtonLong, style: TextStyle(fontWeight: FontWeight.w600)),` |
| `'${timeFormat.format(shift.openedAt)}–${shift.closedAt != null ? timeFormat.format(shift.closedAt!) : '...'}  •  ${shift.salesCount} продаж  •  ${_formatPrice(shift.salesTotal)}',` | `l10n.shiftsHistoryRowLine(timeFormat.format(shift.openedAt), shift.closedAt != null ? timeFormat.format(shift.closedAt!) : '...', shift.salesCount.toString(), _formatPrice(shift.salesTotal)),` |
| `shift.closedAt != null ? 'Сдано' : 'Открыта',` | `shift.closedAt != null ? l10n.shiftsClosedStatus : l10n.shiftsOpenStatus,` |

The `'...'` literal (closed-time fallback for a still-open shift in the
history list) is not a Cyrillic string and stays exactly as-is — only
the Cyrillic separators/labels move into `shiftsHistoryRowLine`.

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep shifts_page` — expect no output.
Run: `flutter analyze` — expect clean.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart lib/presentation/pages/shifts/shifts_page.dart
git commit -m "fix(app): migrate shifts_page.dart hardcoded strings to AppLocalizations"
```

---

### Task 10: Migrate `supplier_detail_page.dart`

**Files:**
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/presentation/pages/supplier/supplier_detail_page.dart`

Current offender (the only 1):
```
152: label: 'Изменить',
```

- [ ] **Step 1: Check for reusable existing keys**

Run: `grep -n '"edit"' lib/l10n/app_ru.arb`
If an `edit: "Изменить"` (or equivalent) key already exists, reuse it
and skip Step 2 entirely. If not, proceed to Step 2.

- [ ] **Step 2: Add new key to `app_ru.arb`** (only if Step 1 found no reuse candidate)

```json
  "edit": "Изменить",
```

Unprefixed — "Edit" is about as generic as UI text gets, matching the
existing `cancel`/`delete`/`save`/`create` style of bare action-verb
keys already in the file.

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Replace the literal**

| Find | Replace with |
|---|---|
| `label: 'Изменить',` | `label: AppLocalizations.of(context)!.edit,` (or whatever existing key Step 1 found) |

- [ ] **Step 5: Verify**

Run: `dart run tool/check_i18n.dart 2>&1 | grep supplier_detail_page` — expect no output.
Run: `flutter analyze` — expect clean.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart lib/presentation/pages/supplier/supplier_detail_page.dart
git commit -m "fix(app): migrate supplier_detail_page.dart hardcoded string to AppLocalizations"
```

---

### Task 11: Final allow-list regeneration + full verification

**Files:**
- Modify: `tool/i18n-allowlist.txt`

- [ ] **Step 1: Regenerate the allow-list one last time**

Run: `dart run tool/check_i18n.dart --dump-allowlist`

This captures the final state: the 6 deliberate settings_page.dart
proper-noun exceptions (already hand-added in Task 6, and now confirmed
present in this fresh dump too — if `--dump-allowlist` overwrites the
file and loses the comment header added in Task 6, re-add that comment
block by hand after this command, since `--dump-allowlist` only writes
the raw entries), plus every pre-existing, still-unmigrated string
outside this plan's 9 files (untouched, unrelated to this project).

- [ ] **Step 2: Verify the lint passes clean**

Run: `dart run tool/check_i18n.dart`
Expected: `check_i18n: scanned <N> files, no new hardcoded Cyrillic strings.`, exit 0.

- [ ] **Step 3: Confirm all 9 files are individually clean**

Run each of the following and confirm zero output for all nine:
```bash
dart run tool/check_i18n.dart 2>&1 | grep customer_list_page.dart
dart run tool/check_i18n.dart 2>&1 | grep expense_list_page.dart
dart run tool/check_i18n.dart 2>&1 | grep payroll_page.dart
dart run tool/check_i18n.dart 2>&1 | grep discounts_page.dart
dart run tool/check_i18n.dart 2>&1 | grep my_stores_page.dart
dart run tool/check_i18n.dart 2>&1 | grep settings_page.dart
dart run tool/check_i18n.dart 2>&1 | grep shifts_page.dart
dart run tool/check_i18n.dart 2>&1 | grep supplier_detail_page.dart
dart run tool/check_i18n.dart 2>&1 | grep payroll_staff_card.dart
```

- [ ] **Step 4: Full analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Full test suite**

Run: `flutter test --reporter expanded`
Expected: no NEW failures relative to the pre-existing baseline (the
macOS-only golden-tolerance gap and any other already-known-unrelated
failures may still appear on a local macOS run — cross-check against
what actually runs in real CI on Linux, same as established earlier in
this session, rather than treating a local-only golden mismatch as a
regression from this work).

- [ ] **Step 6: Commit**

```bash
git add tool/i18n-allowlist.txt
git commit -m "fix(app): final allow-list regeneration after 9-file migration"
```

No further commit for this task beyond this — it's the checkpoint
before the final whole-branch review, pushing, and watching real CI go
green, then `superpowers:finishing-a-development-branch`.
