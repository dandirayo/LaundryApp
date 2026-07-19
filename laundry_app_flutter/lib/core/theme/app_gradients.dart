import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppGradients {
  const AppGradients._();

  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryBlue, AppColors.brightBlue],
  );

  static const gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gold, AppColors.brightGold],
  );

  static const softBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomRight,
    colors: [AppColors.surface, AppColors.softBlue, AppColors.lightGold],
    stops: [0, 0.68, 1],
  );
}
