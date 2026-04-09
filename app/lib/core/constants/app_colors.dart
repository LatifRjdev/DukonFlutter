import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Gradient
  static const Color gradientStart = Color(0xFF667EEA);
  static const Color gradientMid = Color(0xFF7C4DFF);
  static const Color gradientEnd = Color(0xFF764BA2);

  // Primary (solid fallback)
  static const Color primary = Color(0xFF667EEA);
  static const Color primaryDark = Color(0xFF5468D4);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Light Theme Surfaces
  static const Color lightBackground = Color(0xFFF4F0FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFEDE7F6);
  static const Color lightBorder = Color(0xFFE8E0F0);

  // Light Theme Text
  static const Color lightTextPrimary = Color(0xFF1E1B4B);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextHint = Color(0xFF94A3B8);

  // Dark Theme Surfaces
  static const Color darkBackground = Color(0xFF0F0A1A);
  static const Color darkSurface = Color(0xFF1A1128);
  static const Color darkSurfaceElevated = Color(0xFF241B36);
  static const Color darkBorder = Color(0xFF2D2640);

  // Dark Theme Text
  static const Color darkTextPrimary = Color(0xFFF0ECF8);
  static const Color darkTextSecondary = Color(0xFFA09CB0);
  static const Color darkTextHint = Color(0xFF7C7A8E);

  // Status Colors
  static const Color success = Color(0xFF00C853);
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color successDark = Color(0xFF69F0AE);
  static const Color warning = Color(0xFFFFAB00);
  static const Color warningBg = Color(0xFFFFF8E1);
  static const Color warningDark = Color(0xFFFFD740);
  static const Color error = Color(0xFFFF1744);
  static const Color errorBg = Color(0xFFFCE4EC);
  static const Color errorDark = Color(0xFFFF5252);
  static const Color info = Color(0xFF2979FF);
  static const Color infoBg = Color(0xFFE3F2FD);
  static const Color infoDark = Color(0xFF82B1FF);

  // Utility
  static const Color disabled = Color(0xFFBDBDBD);
  static const Color overlay = Color(0x80000000);

  // Glassmorphism (dark mode)
  static const Color glassBg = Color(0x0FFFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color glassElevated = Color(0x0AFFFFFF);
}
