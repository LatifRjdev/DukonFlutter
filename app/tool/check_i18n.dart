// Very small lint script: fail if any .dart file under lib/presentation/
// contains a Cyrillic string literal that is NOT wrapped in
// AppLocalizations.of(context).<key>, Text.rich, debugLabel, log calls,
// or inside an existing allow-list.
//
// Intentionally regex-based (no AST) so we can run it as a `dart run`
// pre-commit / CI step without pulling extra packages. False positives
// are added to tool/i18n-allowlist.txt to keep the signal clean during
// the incremental migration described in docs/adr/0002-i18n-rollout-plan.md.

import 'dart:io';

Future<void> main(List<String> args) async {
  // `main()` itself must stay `void`/non-int here: Dart only auto-applies a
  // returned int to the process exit code for a *synchronous* `int main()`.
  // For `Future<int> main() async`, the returned value is silently dropped
  // and the process always exits 0 regardless of what the script found.
  // Route the real logic through `_run` and set `exitCode` explicitly so
  // CI actually observes failures.
  exitCode = await _run(args);
}

Future<int> _run(List<String> args) async {
  final repoRoot = Directory.current.path;
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
      if (!cyrillicInString.hasMatch(line)) continue;
      final key = '$rel:${i + 1}';
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

  // --dump-allowlist writes every offender location (path:line) to
  // tool/i18n-allowlist.txt and exits 0. Used once when bootstrapping the
  // allow-list so CI can start enforcing the rule for new code.
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
