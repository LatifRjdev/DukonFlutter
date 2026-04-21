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

  group('shadowColor', () {
    testWidgets('should have low alpha in light theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { c = ctx.shadowColor; return const SizedBox(); }),
      ));
      expect(c.a, closeTo(0.08, 0.01));
    });

    testWidgets('should have higher alpha in dark theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { c = ctx.shadowColor; return const SizedBox(); }),
      ));
      expect(c.a, closeTo(0.4, 0.01));
    });

    testWidgets('should differ between light and dark', (tester) async {
      late Color light;
      late Color dark;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { light = ctx.shadowColor; return const SizedBox(); }),
      ));
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { dark = ctx.shadowColor; return const SizedBox(); }),
      ));
      expect(light, isNot(dark));
    });
  });

  group('onPrimary', () {
    testWidgets('should equal Colors.white in light theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { c = ctx.onPrimary; return const SizedBox(); }),
      ));
      expect(c, Colors.white);
    });

    testWidgets('should equal Colors.white in dark theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { c = ctx.onPrimary; return const SizedBox(); }),
      ));
      expect(c, Colors.white);
    });
  });

  group('onSuccess', () {
    testWidgets('should equal Colors.white in light theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { c = ctx.onSuccess; return const SizedBox(); }),
      ));
      expect(c, Colors.white);
    });

    testWidgets('should equal Colors.white in dark theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { c = ctx.onSuccess; return const SizedBox(); }),
      ));
      expect(c, Colors.white);
    });
  });

  group('onDanger', () {
    testWidgets('should equal Colors.white in light theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { c = ctx.onDanger; return const SizedBox(); }),
      ));
      expect(c, Colors.white);
    });

    testWidgets('should equal Colors.white in dark theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { c = ctx.onDanger; return const SizedBox(); }),
      ));
      expect(c, Colors.white);
    });
  });

  group('onWarning', () {
    testWidgets('should equal Colors.black in light theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { c = ctx.onWarning; return const SizedBox(); }),
      ));
      expect(c, Colors.black);
    });

    testWidgets('should equal Colors.black in dark theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { c = ctx.onWarning; return const SizedBox(); }),
      ));
      expect(c, Colors.black);
    });
  });

  group('onInfo', () {
    testWidgets('should equal Colors.white in light theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { c = ctx.onInfo; return const SizedBox(); }),
      ));
      expect(c, Colors.white);
    });

    testWidgets('should equal Colors.white in dark theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { c = ctx.onInfo; return const SizedBox(); }),
      ));
      expect(c, Colors.white);
    });
  });

  group('successBg', () {
    testWidgets('should return AppColors.successBg in light theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { c = ctx.successBg; return const SizedBox(); }),
      ));
      expect(c, AppColors.successBg);
    });

    testWidgets('should return low-alpha dark variant in dark theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { c = ctx.successBg; return const SizedBox(); }),
      ));
      expect(c.a, closeTo(0.15, 0.01));
    });

    testWidgets('should differ between light and dark', (tester) async {
      late Color light;
      late Color dark;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { light = ctx.successBg; return const SizedBox(); }),
      ));
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { dark = ctx.successBg; return const SizedBox(); }),
      ));
      expect(light, isNot(dark));
    });
  });

  group('dangerBg', () {
    testWidgets('should return AppColors.errorBg in light theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { c = ctx.dangerBg; return const SizedBox(); }),
      ));
      expect(c, AppColors.errorBg);
    });

    testWidgets('should return low-alpha dark variant in dark theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { c = ctx.dangerBg; return const SizedBox(); }),
      ));
      expect(c.a, closeTo(0.15, 0.01));
    });

    testWidgets('should differ between light and dark', (tester) async {
      late Color light;
      late Color dark;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { light = ctx.dangerBg; return const SizedBox(); }),
      ));
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { dark = ctx.dangerBg; return const SizedBox(); }),
      ));
      expect(light, isNot(dark));
    });
  });

  group('warningBg', () {
    testWidgets('should return AppColors.warningBg in light theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { c = ctx.warningBg; return const SizedBox(); }),
      ));
      expect(c, AppColors.warningBg);
    });

    testWidgets('should return low-alpha dark variant in dark theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { c = ctx.warningBg; return const SizedBox(); }),
      ));
      expect(c.a, closeTo(0.15, 0.01));
    });

    testWidgets('should differ between light and dark', (tester) async {
      late Color light;
      late Color dark;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { light = ctx.warningBg; return const SizedBox(); }),
      ));
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { dark = ctx.warningBg; return const SizedBox(); }),
      ));
      expect(light, isNot(dark));
    });
  });

  group('infoBg', () {
    testWidgets('should return AppColors.infoBg in light theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { c = ctx.infoBg; return const SizedBox(); }),
      ));
      expect(c, AppColors.infoBg);
    });

    testWidgets('should return low-alpha dark variant in dark theme', (tester) async {
      late Color c;
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { c = ctx.infoBg; return const SizedBox(); }),
      ));
      expect(c.a, closeTo(0.15, 0.01));
    });

    testWidgets('should differ between light and dark', (tester) async {
      late Color light;
      late Color dark;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { light = ctx.infoBg; return const SizedBox(); }),
      ));
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { dark = ctx.infoBg; return const SizedBox(); }),
      ));
      expect(light, isNot(dark));
    });
  });

  group('elevation tokens', () {
    testWidgets('elevationSm returns single shadow with blur 4 and offset (0,2)', (tester) async {
      List<BoxShadow>? val;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { val = ctx.elevationSm; return const SizedBox(); }),
      ));
      expect(val, isNotNull);
      expect(val!.length, 1);
      expect(val!.first.blurRadius, 4);
      expect(val!.first.offset, const Offset(0, 2));
    });

    testWidgets('elevationMd returns single shadow with blur 8 and offset (0,4)', (tester) async {
      List<BoxShadow>? val;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { val = ctx.elevationMd; return const SizedBox(); }),
      ));
      expect(val, isNotNull);
      expect(val!.length, 1);
      expect(val!.first.blurRadius, 8);
      expect(val!.first.offset, const Offset(0, 4));
    });

    testWidgets('elevationLg returns single shadow with blur 16 and offset (0,8)', (tester) async {
      List<BoxShadow>? val;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { val = ctx.elevationLg; return const SizedBox(); }),
      ));
      expect(val, isNotNull);
      expect(val!.length, 1);
      expect(val!.first.blurRadius, 16);
      expect(val!.first.offset, const Offset(0, 8));
    });
  });
}
