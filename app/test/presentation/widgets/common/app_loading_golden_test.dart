import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/widgets/common/app_loading.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: const Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                child: AppLoading(message: 'Loading...'),
              ),
            ),
          ),
        ),
      ),
    );
    // Use pump instead of pumpAndSettle — CircularProgressIndicator never settles.
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('AppLoading goldens', () {
    testWidgets('light theme', (tester) async {
      await pump(tester, Brightness.light);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/app_loading_light.png'),
      );
    });

    testWidgets('dark theme', (tester) async {
      await pump(tester, Brightness.dark);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/app_loading_dark.png'),
      );
    });
  });
}
