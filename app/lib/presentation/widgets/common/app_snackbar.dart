import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class AppSnackbar {
  AppSnackbar._();

  static void success(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: AppColors.success,
      icon: Icons.check_circle_rounded,
    );
  }

  static void error(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: AppColors.error,
      icon: Icons.error_rounded,
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: AppColors.info,
      icon: Icons.info_rounded,
    );
  }

  /// Shows a snackbar with an inline action button (e.g. "Undo", "В кассу").
  /// Defaults to `info` styling; override via [backgroundColor] if needed.
  static void withAction(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    Color? backgroundColor,
    IconData icon = Icons.info_rounded,
  }) {
    _show(
      context,
      message: message,
      backgroundColor: backgroundColor ?? AppColors.info,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    // Dismiss any active snackbar before showing a new one.
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: AppConstants.snackbarDuration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm,
        ),
        elevation: 4,
        dismissDirection: DismissDirection.horizontal,
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );

    // Make the toast audible for screen-reader users (TalkBack / VoiceOver).
    // SnackBar on its own does not steal focus, so transient messages are
    // otherwise silent for assistive tech.
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }
}
