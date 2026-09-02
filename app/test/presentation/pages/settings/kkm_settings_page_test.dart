// Behavioral coverage for SPEC.md #37 — the "Автопечать при продаже" toggle
// used to be pure in-memory state (setState only), so it silently reset to
// off on every app restart even though the user believed they'd turned it
// on. These tests prove the toggle now round-trips through SharedPreferences:
// it reads a previously-saved value on load, and writes through on change —
// the golden test alone can't prove this, since it only checks pixel output
// for the always-empty-prefs default state.
import 'package:dukonpro/presentation/pages/settings/kkm_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/golden_pump_helper.dart';

void main() {
  Widget page() => const KkmSettingsPage();

  group('KkmSettingsPage auto-print persistence (SPEC.md #37)', () {
    testWidgets('defaults to off when no value has ever been saved',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);

      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isFalse);
    });

    testWidgets('a previously-saved true value is loaded and shown as on',
        (tester) async {
      SharedPreferences.setMockInitialValues({'kkm_auto_print': true});

      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);

      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isTrue);
    });

    testWidgets('toggling the switch on writes true through to SharedPreferences',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final toggleAfter = tester.widget<Switch>(find.byType(Switch));
      expect(toggleAfter.value, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('kkm_auto_print'), isTrue);
    });

    testWidgets('toggling an on switch back off writes false through',
        (tester) async {
      SharedPreferences.setMockInitialValues({'kkm_auto_print': true});

      await pumpPageWithTheme(tester, page(), brightness: Brightness.light);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final toggleAfter = tester.widget<Switch>(find.byType(Switch));
      expect(toggleAfter.value, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('kkm_auto_print'), isFalse);
    });
  });
}
