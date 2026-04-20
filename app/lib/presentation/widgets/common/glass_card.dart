import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final bool elevated;
  final Color? accentColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 14,
    this.elevated = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final body = Padding(padding: padding, child: child);

    if (!isDark) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(radius),
              border: accentColor != null
                  ? Border(left: BorderSide(color: accentColor!, width: 3))
                  : null,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: body,
          ),
        ),
      );
    }

    // Dark: glass surface
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: elevated ? AppColors.glassElevated : AppColors.glassBg,
                borderRadius: BorderRadius.circular(radius),
                border: Border(
                  left: accentColor != null
                      ? BorderSide(color: accentColor!, width: 3)
                      : const BorderSide(color: AppColors.glassBorder, width: 1),
                  right: const BorderSide(color: AppColors.glassBorder, width: 1),
                  top: const BorderSide(color: AppColors.glassBorder, width: 1),
                  bottom: const BorderSide(color: AppColors.glassBorder, width: 1),
                ),
              ),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
