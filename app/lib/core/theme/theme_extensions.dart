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
}
