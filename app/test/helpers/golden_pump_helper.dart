// app/test/helpers/golden_pump_helper.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/l10n/app_localizations.dart';

/// Wrap [page] in a themed MaterialApp. Pass [wrap] to inject BlocProviders
/// or any other InheritedWidget tree above the page.
Future<void> pumpPageWithTheme(
  WidgetTester tester,
  Widget page, {
  required Brightness brightness,
  Widget Function(Widget child)? wrap,
  Size size = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final content = wrap != null ? wrap(page) : page;
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: content,
    ),
  );
  await tester.pumpAndSettle();
}
