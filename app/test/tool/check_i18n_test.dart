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
}
