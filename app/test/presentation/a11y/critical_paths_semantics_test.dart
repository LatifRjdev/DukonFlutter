// Sprint 5B.2.a — automated semantic-label assertions
//
// Coverage strategy: pump only trivially-hostable widgets (no full-page
// bloc setup required).  Full-page coverage (POS checkout, receipt
// preview, product list) deferred — test-setup cost exceeds value for
// those specific labels; screen-reader QA handles that verification.
//
// Labels must match the Sprint 5B.2.a §3 convention table exactly.
//
// Implementation note: we match Semantics widgets by inspecting the
// widget tree directly (`byWidgetPredicate`) rather than the rendered
// semantics tree (`find.bySemanticsLabel`).  The widget-tree check is
// sufficient for verifying that authors have wired labels in the source,
// and avoids the SemanticsBinding setup cost per test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/widgets/common/app_bottom_nav_bar.dart';

// ---------------------------------------------------------------------------
// Helper: wrap widget in a themed, localised MaterialApp (ru locale)
// ---------------------------------------------------------------------------

Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ru'),
    home: Scaffold(
      bottomNavigationBar: child is AppBottomNavBar ? child : null,
      body: child is AppBottomNavBar ? null : child,
    ),
  );
}

Finder _semanticsWithLabel(String label) {
  return find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  );
}

void main() {
  group('Sprint 5B.2.a critical-path semantic labels', () {
    // ── Bottom nav — label coverage ──────────────────────────────────────

    testWidgets(
        'Bottom nav — all 5 tabs expose Semantics labels (index 0 active)',
        (tester) async {
      await tester.pumpWidget(
        _host(
          AppBottomNavBar(currentIndex: 0, onTap: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in const [
        'Главная',
        'Товары',
        'Касса',
        'Финансы',
        'Ещё',
      ]) {
        expect(
          _semanticsWithLabel(label),
          findsWidgets,
          reason: 'Bottom nav tab "$label" must expose a Semantics label',
        );
      }
    });

    testWidgets('Bottom nav — Касса tab label present when active (index 2)',
        (tester) async {
      await tester.pumpWidget(
        _host(
          AppBottomNavBar(currentIndex: 2, onTap: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _semanticsWithLabel('Касса'),
        findsWidgets,
        reason: 'Касса tab must expose Semantics label when active',
      );
    });

    testWidgets('Bottom nav — Финансы tab label present when active (index 3)',
        (tester) async {
      await tester.pumpWidget(
        _host(
          AppBottomNavBar(currentIndex: 3, onTap: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _semanticsWithLabel('Финансы'),
        findsWidgets,
        reason: 'Финансы tab must expose Semantics label when active',
      );
    });

    // ── Bottom nav — button + selected semantics properties ──────────────

    testWidgets(
        'Bottom nav — active tab Semantics widget has button:true and selected:true',
        (tester) async {
      await tester.pumpWidget(
        _host(
          AppBottomNavBar(currentIndex: 1, onTap: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      final active = tester.widget<Semantics>(_semanticsWithLabel('Товары'));
      expect(active.properties.button, isTrue,
          reason: 'Active tab Semantics widget must have button: true');
      expect(active.properties.selected, isTrue,
          reason: 'Active tab Semantics widget must have selected: true');
    });

    testWidgets(
        'Bottom nav — inactive tab has button:true and selected:false',
        (tester) async {
      await tester.pumpWidget(
        _host(
          AppBottomNavBar(currentIndex: 0, onTap: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      final inactive = tester.widget<Semantics>(_semanticsWithLabel('Финансы'));
      expect(inactive.properties.button, isTrue,
          reason: 'Inactive tab Semantics widget must still have button: true');
      expect(inactive.properties.selected, isFalse,
          reason: 'Inactive tab Semantics widget must have selected: false');
    });

    // ── Bottom nav — onTap callback ───────────────────────────────────────

    testWidgets('Bottom nav — tapping a tab fires onTap with correct index',
        (tester) async {
      int tappedIndex = -1;

      await tester.pumpWidget(
        _host(
          AppBottomNavBar(
            currentIndex: 0,
            onTap: (i) => tappedIndex = i,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the "Ещё" label (index 4) via its Semantics wrapper.
      await tester.tap(_semanticsWithLabel('Ещё'));
      await tester.pumpAndSettle();

      expect(tappedIndex, 4,
          reason: 'Tapping "Ещё" tab must fire onTap(4)');
    });
  });
}
