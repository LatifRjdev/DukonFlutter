import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/core/constants/app_colors.dart';
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/presentation/widgets/common/glass_card.dart';

Widget _host(ThemeData theme, Widget child) => MaterialApp(
      theme: theme,
      home: Scaffold(body: Theme(data: theme, child: child)),
    );

void main() {
  group('GlassCard', () {
    testWidgets('light theme renders opaque white surface', (tester) async {
      await tester.pumpWidget(_host(
        AppTheme.light,
        const GlassCard(child: Text('hello')),
      ));
      expect(find.text('hello'), findsOneWidget);
      final containers = tester.widgetList<Container>(
        find.descendant(of: find.byType(GlassCard), matching: find.byType(Container)),
      );
      // At least one Container has lightSurface background
      expect(
        containers.any((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == AppColors.lightSurface),
        isTrue,
      );
    });

    testWidgets('dark theme renders glass background via BackdropFilter', (tester) async {
      await tester.pumpWidget(_host(
        AppTheme.dark,
        const GlassCard(child: Text('hello')),
      ));
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('accentColor adds left border in light theme', (tester) async {
      await tester.pumpWidget(_host(
        AppTheme.light,
        GlassCard(accentColor: AppColors.primary, child: const Text('x')),
      ));
      final containers = tester.widgetList<Container>(
        find.descendant(of: find.byType(GlassCard), matching: find.byType(Container)),
      );
      // Find the container that has our border configured
      final decorated = containers
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere(
            (d) => d.border is Border && (d.border as Border).left.color == AppColors.primary,
            orElse: () => const BoxDecoration(),
          );
      expect(decorated.border, isA<Border>());
      final border = decorated.border as Border;
      expect(border.left.color, AppColors.primary);
      expect(border.left.width, 3);
    });
  });
}
