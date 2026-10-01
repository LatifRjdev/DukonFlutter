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
    // `call.target == null` restricts this to unprefixed invocations. Without
    // it, ANY method named log/print/debugPrint on ANY receiver would exempt
    // its string arguments — so a future `Logger().log('Ошибка')` or
    // `auditLog.log(...)` would silently stop being policed. exceptions.dart's
    // dartdoc notes a logger is expected to arrive under separate tracking,
    // which is exactly the shape that would have opened that hole.
    return call is MethodInvocation &&
        call.target == null &&
        _diagnosticCalls.contains(call.methodName.name);
  }

  /// The allow-list key form of a literal's source.
  ///
  /// Newlines are escaped to `\n` because the allow-list is line-based
  /// (`readAsLinesSync`). A `'''…'''` literal's `toSource()` spans several
  /// physical lines, so emitting it raw made the key unmatchable AND corrupted
  /// the file on `--dump-allowlist`: the dump exited 0 claiming success while
  /// writing a three-line entry plus two phantom ones, and the re-check still
  /// failed. That left multi-line literals detectable but impossible to
  /// grandfather — a capability shipping with no remediation path.
  static String keyFor(StringLiteral node) =>
      node.toSource().replaceAll('\r\n', r'\n').replaceAll('\n', r'\n');

  void _record(StringLiteral node) {
    if (_isDiagnosticArgument(node)) return;
    if (!_cyrillic.hasMatch(node.toSource())) return;
    found.add((source: keyFor(node), offset: node.offset));
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
      found.add((source: keyFor(node), offset: node.offset));
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
