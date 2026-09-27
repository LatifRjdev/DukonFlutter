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
