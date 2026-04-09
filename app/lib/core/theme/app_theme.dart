import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      error: AppColors.error,
      outline: AppColors.lightBorder,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    textTheme: _textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size(double.infinity, AppConstants.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(double.infinity, AppConstants.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        ),
        side: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        borderSide: const BorderSide(color: AppColors.lightBorder, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        borderSide: const BorderSide(color: AppColors.lightBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.inter(color: AppColors.lightTextHint, fontSize: 15),
      labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.lightTextHint,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightBackground,
      selectedColor: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.errorDark,
      outline: AppColors.darkBorder,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    textTheme: _textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size(double.infinity, AppConstants.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        borderSide: const BorderSide(color: AppColors.darkBorder, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        borderSide: const BorderSide(color: AppColors.darkBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        borderSide: const BorderSide(color: AppColors.errorDark, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.inter(color: AppColors.darkTextHint, fontSize: 15),
      labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkBackground,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.darkTextHint,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 1,
    ),
  );

  static TextTheme get _textTheme => TextTheme(
    headlineLarge: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800),
    headlineMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700),
    headlineSmall: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
    titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
    titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
    titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
    bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400),
    labelLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
    labelMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
    labelSmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
  );
}
