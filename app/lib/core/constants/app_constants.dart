class AppConstants {
  AppConstants._();

  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Border radii — 4-based scale
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 24.0;
  static const double radiusRound = 100.0;

  // Button
  static const double buttonHeight = 56.0;
  static const double buttonHeightSmall = 40.0;
  static const double buttonRadius = 14.0;

  // Card
  static const double cardRadius = 16.0;
  static const double cardElevation = 2.0;

  // Motion durations
  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionMedium = Duration(milliseconds: 250);
  static const Duration motionSlow = Duration(milliseconds: 400);

  // Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration snackbarDuration = Duration(seconds: 3);

  // Pagination
  static const int defaultPageSize = 20;

  // Sync
  static const Duration syncInterval = Duration(minutes: 5);
  static const int maxRetryAttempts = 3;

  // Phone
  static const String phonePrefix = '+992';
  static const int phoneLength = 9;
}
