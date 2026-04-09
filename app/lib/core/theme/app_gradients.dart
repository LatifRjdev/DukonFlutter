import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppGradients {
  AppGradients._();

  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gradientStart, AppColors.gradientEnd],
  );

  static const LinearGradient primaryFull = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
  );

  static const LinearGradient horizontal = LinearGradient(
    colors: [AppColors.gradientStart, AppColors.gradientEnd],
  );
}
