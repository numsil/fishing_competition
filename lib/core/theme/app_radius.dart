import 'package:flutter/widgets.dart';

/// 모서리 반경 토큰.
class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12; // 기본 (input, button, small card)
  static const double lg = 16; // 카드
  static const double xl = 20; // 바텀시트, 큰 카드
  static const double xxl = 24;
  static const double pill = 9999;

  static final BorderRadius brSm = BorderRadius.circular(sm);
  static final BorderRadius brMd = BorderRadius.circular(md);
  static final BorderRadius brLg = BorderRadius.circular(lg);
  static final BorderRadius brXl = BorderRadius.circular(xl);

  static const BorderRadius brTopXl = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}
