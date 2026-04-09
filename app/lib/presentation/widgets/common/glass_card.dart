import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? radius;
  final bool elevated;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.radius,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          borderRadius: BorderRadius.circular(radius ?? AppConstants.cardRadius),
          boxShadow: const [
            BoxShadow(color: Color(0x1A667EEA), blurRadius: 16, offset: Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius ?? AppConstants.cardRadius),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(AppConstants.spacingMd),
              child: child,
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? AppConstants.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: elevated ? AppColors.glassElevated : AppColors.glassBg,
            borderRadius: BorderRadius.circular(radius ?? AppConstants.cardRadius),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius ?? AppConstants.cardRadius),
              child: Padding(
                padding: padding ?? const EdgeInsets.all(AppConstants.spacingMd),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
