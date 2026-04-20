import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';

class OnboardingSlide extends StatelessWidget {
  final String title;
  final String description;
  final String? imagePath;
  final Color? color;

  const OnboardingSlide({
    super.key,
    required this.title,
    required this.description,
    this.imagePath,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final slideColor = color ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          // Image placeholder
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: slideColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: imagePath != null
                ? ClipOval(
                    child: Image.asset(
                      imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildPlaceholderIcon(slideColor),
                    ),
                  )
                : _buildPlaceholderIcon(slideColor),
          ),
          const Spacer(),
          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
              fontFamily: 'Inter',
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          // Description
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: context.textSecondary,
              fontFamily: 'Inter',
              height: 1.5,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildPlaceholderIcon(Color slideColor) {
    return Icon(
      Icons.storefront_rounded,
      size: 120,
      color: slideColor.withValues(alpha: 0.4),
    );
  }
}
