import 'package:flutter/material.dart';

/// 그림자 / Elevation 토큰.
class AppElevation {
  AppElevation._();

  /// 작은 떠 있는 요소 (snack bar, floating chip)
  static List<BoxShadow> sm(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.18),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// 중간 (top banner, hover)
  static List<BoxShadow> md(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// 큰 (modal, bottom sheet)
  static List<BoxShadow> lg(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.25),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
