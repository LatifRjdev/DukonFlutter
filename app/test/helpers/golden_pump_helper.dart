// app/test/helpers/golden_pump_helper.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

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

/// Wraps a standalone widget in a Scaffold for golden coverage.
/// Use for any widget that does NOT have its own Scaffold (most shared components).
Future<void> pumpWidgetWithTheme(
  WidgetTester tester,
  Widget widget, {
  required Brightness brightness,
  Widget Function(Widget child)? wrap,
  Size size = const Size(390, 844),
  EdgeInsets padding = const EdgeInsets.all(16),
  Alignment alignment = Alignment.center,
}) async {
  final hosted = Scaffold(
    body: SafeArea(
      child: Padding(
        padding: padding,
        child: Align(alignment: alignment, child: widget),
      ),
    ),
  );
  await pumpPageWithTheme(
    tester,
    hosted,
    brightness: brightness,
    wrap: wrap,
    size: size,
  );
}
