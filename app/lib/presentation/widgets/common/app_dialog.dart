import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class AppDialog {
  AppDialog._();

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Тасдиқ',
    String cancelText = 'Бекор',
    VoidCallback? onConfirm,
    bool isDanger = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => _AppDialogContent(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        isDanger: isDanger,
      ),
    );
  }
}

class _AppDialogContent extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final bool isDanger;

  const _AppDialogContent({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    this.onConfirm,
    required this.isDanger,
  });

  @override
  Widget build(BuildContext context) {
    final confirmColor = isDanger ? AppColors.error : AppColors.primary;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
      elevation: AppConstants.cardElevation,
      backgroundColor: AppColors.lightSurface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingXl,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                color: AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),

            // Message
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
                color: AppColors.lightTextSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppConstants.buttonHeightSmall,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.lightTextSecondary,
                        side: const BorderSide(color: AppColors.lightBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.buttonRadius,
                          ),
                        ),
                      ),
                      child: Text(
                        cancelText,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: SizedBox(
                    height: AppConstants.buttonHeightSmall,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                        onConfirm?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.buttonRadius,
                          ),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
