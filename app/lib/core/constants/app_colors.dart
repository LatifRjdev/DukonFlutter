import 'package:flutter/material.dart';

class AppColors {
  // Brand gradient (aligned with design spec: indigo-500 → violet-500)
  static const Color gradientStart = Color(0xFF6366F1);
  static const Color gradientMid = Color(0xFF7C6AF0);
  static const Color gradientEnd = Color(0xFF8B5CF6);

  // Primary brand
  static const Color primary = Color(0xFF6366F1);       // indigo-500
  static const Color primaryDark = Color(0xFF818CF8);   // indigo-400 for dark theme
  static const Color onPrimary = Colors.white;

  // Secondary (gradient partner / accents)
  static const Color secondary = Color(0xFF8B5CF6);     // violet-500
  static const Color secondaryDark = Color(0xFFA78BFA); // violet-400

  // Light theme surfaces
  static const Color lightBackground = Color(0xFFF4F0FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF9F5FC);
  static const Color lightBorder = Color(0xFFE8E0F0);
  static const Color lightTextPrimary = Color(0xFF1E1B4B);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextHint = Color(0xFF94A3B8);

  // Dark theme surfaces (not pure black — prevents OLED smear)
  static const Color darkBackground = Color(0xFF0F0A1A);
  static const Color darkSurface = Color(0xFF1A1128);
  static const Color darkSurfaceElevated = Color(0xFF241937);
  static const Color darkBorder = Color(0xFF2D2042);
  static const Color darkTextPrimary = Color(0xFFF0ECF8);
  static const Color darkTextSecondary = Color(0xFFC4B5FD);
  static const Color darkTextHint = Color(0xFFA09CB0);

  // Semantic accents (light theme values; dark variants via context.* extensions)
  static const Color success = Color(0xFF10B981);       // emerald-500
  static const Color successDark = Color(0xFF34D399);   // emerald-400 for dark
  static const Color successBg = Color(0xFFD1FAE5);

  static const Color warning = Color(0xFFF59E0B);       // amber-500
  static const Color warningDark = Color(0xFFFBBF24);   // amber-400 for dark
  static const Color warningBg = Color(0xFFFEF3C7);

  static const Color error = Color(0xFFEF4444);         // red-500
  static const Color errorDark = Color(0xFFF87171);     // red-400 for dark
  static const Color errorBg = Color(0xFFFEE2E2);

  static const Color info = Color(0xFF3B82F6);          // blue-500
  static const Color infoDark = Color(0xFF60A5FA);      // blue-400 for dark
  static const Color infoBg = Color(0xFFDBEAFE);

  // Accent tints for icon backgrounds (light mode)
  static const Color primaryTint = Color(0xFFEDE9FE);   // violet-100
  static const Color successTint = Color(0xFFD1FAE5);
  static const Color dangerTint = Color(0xFFFEE2E2);
  static const Color warningTint = Color(0xFFFEF3C7);
  static const Color infoTint = Color(0xFFDBEAFE);

  // Utility
  static const Color disabled = Color(0xFFCBD5E1);
  static const Color overlay = Color(0x80000000);

  // Glassmorphism (dark theme only)
  static const Color glassBg = Color(0x14B387F5);       // rgba(139,92,246,0.08)
  static const Color glassBorder = Color(0x1FFFFFFF);   // rgba(255,255,255,0.12)
  static const Color glassElevated = Color(0x1FB387F5); // rgba(139,92,246,0.12)
}
