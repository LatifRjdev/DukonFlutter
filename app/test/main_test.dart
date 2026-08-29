// SPEC.md #14 — the language settings screen tells the user "restart to
// apply", but the saved preference was never read back at startup, so the
// promise was a lie. This tests `loadSavedLocale()`, the standalone function
// `main.dart` now awaits before `runApp` to make that promise true.
//
// `loadSavedLocale()` is deliberately a plain SharedPreferences-only
// function (no WidgetsFlutterBinding/Firebase/DI dependency), so it's
// unit-testable directly without pumping a widget tree — the code that
// *calls* it lives in `main()`/`_runApp()`, which runs before
// `WidgetsFlutterBinding.ensureInitialized()` and isn't practically
// unit-testable itself; that startup wiring is covered by manual
// verification (see commit message).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dukonpro/main.dart';

void main() {
  group('loadSavedLocale', () {
    test('defaults to ru when nothing has been saved yet', () async {
      SharedPreferences.setMockInitialValues({});

      final locale = await loadSavedLocale();

      expect(locale, const Locale('ru'));
    });

    test(
      'reads back the language saved by the language settings screen',
      () async {
        // Same key ('app_language') LanguageSettingsPage._save() writes.
        SharedPreferences.setMockInitialValues({'app_language': 'tg'});

        final locale = await loadSavedLocale();

        expect(locale, const Locale('tg'));
      },
    );

    test('applies a saved uz preference the same way', () async {
      SharedPreferences.setMockInitialValues({'app_language': 'uz'});

      final locale = await loadSavedLocale();

      expect(locale, const Locale('uz'));
    });
  });
}
