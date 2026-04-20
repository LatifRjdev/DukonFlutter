import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';

class AppLoading extends StatelessWidget {
  final String? message;
  final double size;

  const AppLoading({super.key, this.message, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(color: AppColors.primary),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: TextStyle(color: context.textSecondary)),
          ],
        ],
      ),
    );
  }
}
