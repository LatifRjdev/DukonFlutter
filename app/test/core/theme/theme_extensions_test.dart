import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/core/constants/app_colors.dart';
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/core/theme/theme_extensions.dart';

Widget _wrap(ThemeData theme, Widget child) => MaterialApp(
      home: Theme(
        data: theme,
        child: Scaffold(body: Builder(builder: (_) => child)),
      ),
    );

void main() {
  group('ThemeColors extension', () {
    testWidgets('context.bg returns scaffoldBackgroundColor (light)', (tester) async {
      late Color bg;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { bg = ctx.bg; return const SizedBox(); }),
      ));
      expect(bg, AppColors.lightBackground);
    });

    testWidgets('context.bg returns darkBackground (dark)', (tester) async {
      late Color bg;
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { bg = ctx.bg; return const SizedBox(); }),
      ));
      expect(bg, AppColors.darkBackground);
    });

    testWidgets('context.success differs between themes', (tester) async {
      late Color lightSuccess;
      late Color darkSuccess;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { lightSuccess = ctx.success; return const SizedBox(); }),
      ));
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { darkSuccess = ctx.success; return const SizedBox(); }),
      ));
      expect(lightSuccess, AppColors.success);
      expect(darkSuccess, AppColors.successDark);
      expect(lightSuccess, isNot(darkSuccess));
    });

    testWidgets('context.textPrimary uses colorScheme.onSurface', (tester) async {
      late Color t;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { t = ctx.textPrimary; return const SizedBox(); }),
      ));
      expect(t, AppColors.lightTextPrimary);
    });
  });
}
