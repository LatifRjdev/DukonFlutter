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

  test('every literal on a line is reported, not just the first (ternary siblings)', () async {
    // Regression guard: the scanner used firstMatch, so the second branch of a
    // ternary was invisible. Worse, allow-listing only the first one made the
    // sibling look like a brand-new offender the moment the first was fixed.
    File('${tempDir.path}/lib/presentation/sample.dart').writeAsStringSync(
      "final s = isOpen ? 'Открыта' : 'Закрыта';\n",
    );
    // Allow-list ONLY the first literal; the second must still be reported.
    File('${tempDir.path}/tool/i18n-allowlist.txt')
        .writeAsStringSync("lib/presentation/sample.dart::'Открыта'\n");

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 1, reason: "the ternary's second branch must still be flagged");
  });

  test('a literal made only of extended Cyrillic letters is detected', () async {
    // Regression guard for the character class. The old class was
    // [а-яА-ЯёЁ] (Russian only), which omits the Tajik/Uzbek letters
    // ӯ қ ғ ҳ ҷ ӣ.
    //
    // Note the practical exposure was small: real Tajik words almost always
    // mix in at least one base-range letter, so e.g. 'Пӯшидан' was already
    // caught via its П/ш/и/д/а/н. This uses a literal composed *only* of
    // extended letters, which is the only input that actually distinguishes
    // the two classes — artificial, but it's what pins the behaviour.
    File('${tempDir.path}/lib/presentation/sample.dart')
        .writeAsStringSync("const s = 'ӯғқҳ';\n");
    File('${tempDir.path}/tool/i18n-allowlist.txt').writeAsStringSync('');

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 1, reason: 'extended Cyrillic must be treated as Cyrillic');
  });

  test('a matched string containing a double space (the label  separator  value convention) round-trips through dump and check without truncation', () async {
    // Regression test for a bug caught during implementation: recovering
    // the allow-list key by splitting the offender report string on a
    // double-space separator silently truncated any key whose *content*
    // also contained a double space — which real UI strings do (see
    // .claude/rules/mobile-l10n.md's label+separator+value convention).
    final source = "const text = '5 клиентов  |  Долг: 100 TJS';\n";
    File('${tempDir.path}/lib/presentation/sample.dart')
        .writeAsStringSync(source);
    final allowlistFile = File('${tempDir.path}/tool/i18n-allowlist.txt');
    allowlistFile.writeAsStringSync('');

    await check_i18n.run(['--dump-allowlist'], repoRootOverride: tempDir.path);

    expect(
      allowlistFile.readAsStringSync().trim(),
      "lib/presentation/sample.dart::'5 клиентов  |  Долг: 100 TJS'",
    );

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);
    expect(code, 0);
  });

  test('a hardcoded literal in lib/core is flagged, not just lib/presentation', () async {
    // Regression guard for the scan root. Before this, check_i18n only walked
    // lib/presentation, so every string in lib/core, lib/data and lib/domain
    // was invisible — which is how 71 user-facing literals survived Track 2.
    Directory('${tempDir.path}/lib/core/services').createSync(recursive: true);
    File('${tempDir.path}/lib/core/services/sample_service.dart')
        .writeAsStringSync("const msg = 'Ошибка сервера';\n");
    File('${tempDir.path}/tool/i18n-allowlist.txt').writeAsStringSync('');

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 1, reason: 'lib/core must be in scope');
  });

  test('generated localizations under lib/l10n are not scanned', () async {
    // lib/l10n/app_localizations_ru.dart is entirely Russian by definition;
    // scanning it would produce thousands of false positives.
    Directory('${tempDir.path}/lib/l10n').createSync(recursive: true);
    File('${tempDir.path}/lib/l10n/app_localizations_ru.dart')
        .writeAsStringSync("String get save => 'Сохранить';\n");
    File('${tempDir.path}/tool/i18n-allowlist.txt').writeAsStringSync('');

    final code = await check_i18n.run([], repoRootOverride: tempDir.path);

    expect(code, 0, reason: 'lib/l10n must be excluded');
  });

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
    //
    // What this does NOT prove: the absence of STALE entries. An entry that no
    // longer corresponds to any occurrence is simply never consumed, and an
    // unconsumed permit cannot make the run fail. Only the
    // `--dump-allowlist` entry-line diff (a manual step, not a test) catches
    // that. Do not read a pass here as "the allowlist is exactly the live
    // offender multiset" — it only means "nothing is missing from it".
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
}
