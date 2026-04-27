import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

extension ThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get accentColor => isDark ? AppColors.neonGreen : AppColors.navy;
}
