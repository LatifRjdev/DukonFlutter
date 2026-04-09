import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class AppBottomSheet {
  AppBottomSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    double? height,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (context) => _AppBottomSheetContent<T>(
        title: title,
        height: height,
        child: child,
      ),
    );
  }
}

class _AppBottomSheetContent<T> extends StatelessWidget {
  final String title;
  final Widget child;
  final double? height;

  const _AppBottomSheetContent({
    required this.title,
    required this.child,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    final sheetHeight = height != null && height! < maxHeight ? height : null;

    return Container(
      height: sheetHeight,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: sheetHeight != null ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: AppConstants.spacingSm),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Title row with close button
          Padding(
            padding: const EdgeInsets.only(
              left: AppConstants.spacingMd,
              right: AppConstants.spacingXs,
              top: AppConstants.spacingSm,
              bottom: AppConstants.spacingXs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                  splashRadius: 20,
                  tooltip: 'Пӯшидан',
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // Content
          if (sheetHeight != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                child: child,
              ),
            )
          else
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                child: child,
              ),
            ),

          // Bottom safe area padding
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
        ],
      ),
    );
  }
}
