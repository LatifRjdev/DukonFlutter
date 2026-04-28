import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/core/theme/contrast_utils.dart';
import 'package:dukonpro/core/theme/theme_extensions.dart';

const double _aa = 4.5;
const double _aaLarge = 3.0;

Widget _wrap(ThemeData theme, Widget child) => MaterialApp(
      home: Theme(
        data: theme,
        child: Scaffold(body: Builder(builder: (_) => child)),
      ),
    );

Future<Color> _read(
  WidgetTester tester,
  ThemeData theme,
  Color Function(BuildContext) read,
) async {
  late Color result;
  await tester.pumpWidget(_wrap(
    theme,
    Builder(builder: (ctx) {
      result = read(ctx);
      return const SizedBox();
    }),
  ));
  return result;
}

void main() {
  for (final entry in {
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    final themeName = entry.key;
    final theme = entry.value;

    group('ThemeColors WCAG AA contrast ($themeName)', () {
      testWidgets('textPrimary on bg ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.textPrimary);
        final bg = await _read(t, theme, (c) => c.bg);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('textPrimary on surface ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.textPrimary);
        final bg = await _read(t, theme, (c) => c.surface);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('textSecondary on bg ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.textSecondary);
        final bg = await _read(t, theme, (c) => c.bg);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('textSecondary on surface ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.textSecondary);
        final bg = await _read(t, theme, (c) => c.surface);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('textMuted on surface ≥ AA-large (captions only)', (t) async {
        final fg = await _read(t, theme, (c) => c.textMuted);
        final bg = await _read(t, theme, (c) => c.surface);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aaLarge));
      });

      testWidgets('onPrimary on primary ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.onPrimary);
        final bg = await _read(t, theme, (c) => c.primary);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('onSuccess on success ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.onSuccess);
        final bg = await _read(t, theme, (c) => c.success);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('onDanger on danger ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.onDanger);
        final bg = await _read(t, theme, (c) => c.danger);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('onWarning on warning ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.onWarning);
        final bg = await _read(t, theme, (c) => c.warning);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('onInfo on info ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.onInfo);
        final bg = await _read(t, theme, (c) => c.info);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });

      testWidgets('textPrimary on surfaceMuted ≥ AA', (t) async {
        final fg = await _read(t, theme, (c) => c.textPrimary);
        final bg = await _read(t, theme, (c) => c.surfaceMuted);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(_aa));
      });
    });
  }
}
