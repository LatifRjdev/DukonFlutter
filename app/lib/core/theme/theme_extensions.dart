import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Theme-aware color accessors. Call from widget `build` methods only
/// (requires a valid `Theme.of(context)`).
extension ThemeColors on BuildContext {
  ThemeData get _theme => Theme.of(this);
  bool get _isDark => _theme.brightness == Brightness.dark;

  /// Scaffold background.
  Color get bg => _theme.scaffoldBackgroundColor;

  /// Card / elevated surface.
  Color get surface => _isDark ? AppColors.darkSurface : AppColors.lightSurface;

  /// Secondary muted surface.
  Color get surfaceMuted =>
      _isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;

  /// Divider / border color.
  Color get border => _isDark ? AppColors.darkBorder : AppColors.lightBorder;

  /// Primary body text.
  Color get textPrimary => _theme.colorScheme.onSurface;

  /// Secondary text (captions, sub-labels).
  Color get textSecondary =>
      _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  /// Hint / placeholder text.
  Color get textMuted =>
      _isDark ? AppColors.darkTextHint : AppColors.lightTextHint;

  /// Brand primary (adapted for contrast per theme).
  Color get primary => _theme.colorScheme.primary;

  /// Brand secondary / violet.
  Color get secondary => _theme.colorScheme.secondary;

  /// Semantic success.
  Color get success => _isDark ? AppColors.successDark : AppColors.success;

  /// Semantic danger / error.
  Color get danger => _isDark ? AppColors.errorDark : AppColors.error;

  /// Semantic warning.
  Color get warning => _isDark ? AppColors.warningDark : AppColors.warning;

  /// Semantic info.
  Color get info => _isDark ? AppColors.infoDark : AppColors.info;

  /// Shadow color for elevation. Soft black in light, higher-opacity black in dark.
  Color get shadowColor => _isDark
      ? Colors.black.withValues(alpha: 0.4)
      : Colors.black.withValues(alpha: 0.08);

  /// Foreground on primary-colored surfaces (buttons, filled chips).
  /// White in both themes — brand primary is saturated enough.
  Color get onPrimary => _theme.colorScheme.onPrimary;

  /// Foreground on success-colored surfaces (small check icons, filled success chips).
  Color get onSuccess => Colors.white;

  /// Foreground on danger/error-colored surfaces.
  Color get onDanger => Colors.white;

  /// Foreground on warning-colored surfaces.
  /// Dark text on amber/yellow is the accessibility default (WCAG AA).
  Color get onWarning => Colors.black;

  /// Foreground on info-colored surfaces.
  Color get onInfo => Colors.white;

  /// Tinted success background (for status cards, pills).
  /// Light pastel in light, low-alpha dark green in dark.
  Color get successBg => _isDark
      ? AppColors.successDark.withValues(alpha: 0.15)
      : AppColors.successBg;

  /// Tinted danger/error background.
  Color get dangerBg => _isDark
      ? AppColors.errorDark.withValues(alpha: 0.15)
      : AppColors.errorBg;

  /// Tinted warning background.
  Color get warningBg => _isDark
      ? AppColors.warningDark.withValues(alpha: 0.15)
      : AppColors.warningBg;

  /// Tinted info background.
  Color get infoBg => _isDark
      ? AppColors.infoDark.withValues(alpha: 0.15)
      : AppColors.infoBg;

  /// Small elevation — list items, low-prominence cards.
  List<BoxShadow> get elevationSm => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  /// Medium elevation — floating cards, sticky bars.
  List<BoxShadow> get elevationMd => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  /// Large elevation — modals, popovers, FABs.
  List<BoxShadow> get elevationLg => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];
}
