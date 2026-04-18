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

  static const LinearGradient primaryDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3D4FA8), Color(0xFF4A2D8A)],
  );

  static LinearGradient primaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? primaryDark : primary;
}
