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

  // Track key and display text as a record pair rather than concatenating
  // them into one string and splitting it back apart later: the matched
  // `content` can itself contain a run of spaces (e.g. the
  // "label + separator + value" strings like
  // "N клиентов  |  Долг: X" this codebase uses — see
  // .claude/rules/mobile-l10n.md), which would collide with any
  // whitespace-based delimiter used to rejoin/re-split key vs. display
  // text.
  final offenders = <({String key, String display})>[];
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
      offenders.add((key: key, display: trimmed));
    }
  }

  // --dump-allowlist writes every offender's key to tool/i18n-allowlist.txt
  // and exits 0. Used once when bootstrapping the allow-list (or
  // resyncing it) so CI can start enforcing the rule for new code.
  if (dumpAllowlist) {
    final locations = offenders.map((o) => o.key).toSet().toList()..sort();
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
    stdout.writeln('  ${o.key}  ${o.display}');
  }
  if (offenders.length > 50) {
    stdout.writeln('  ... and ${offenders.length - 50} more.');
  }
  return 1;
}
