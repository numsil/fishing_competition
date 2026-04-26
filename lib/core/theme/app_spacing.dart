import 'package:flutter/widgets.dart';

/// 4pt 그리드 기반 스페이싱 토큰.
/// `EdgeInsets`, `SizedBox`, `Padding` 등에서 매직 넘버 대신 사용.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 20;
  static const double xxxl = 24;
  static const double huge = 32;
  static const double mega = 40;

  // 자주 쓰는 EdgeInsets 프리셋
  static const EdgeInsets allXs = EdgeInsets.all(xs);
  static const EdgeInsets allSm = EdgeInsets.all(sm);
  static const EdgeInsets allMd = EdgeInsets.all(md);
  static const EdgeInsets allLg = EdgeInsets.all(lg);
  static const EdgeInsets allXl = EdgeInsets.all(xl);

  // 화면 좌우 기본 패딩 (16)
  static const EdgeInsets pageHorizontal =
      EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets pageAll = EdgeInsets.all(xl);

  // 카드 / 리스트 아이템 패딩
  static const EdgeInsets card = EdgeInsets.all(14);
  static const EdgeInsets listItem =
      EdgeInsets.symmetric(horizontal: xl, vertical: lg);

  // 자주 쓰는 SizedBox 갭 (Row/Column에서 사용)
  static const SizedBox gapH4 = SizedBox(height: xs);
  static const SizedBox gapH8 = SizedBox(height: md);
  static const SizedBox gapH12 = SizedBox(height: lg);
  static const SizedBox gapH16 = SizedBox(height: xl);
  static const SizedBox gapH20 = SizedBox(height: xxl);
  static const SizedBox gapH24 = SizedBox(height: xxxl);

  static const SizedBox gapW4 = SizedBox(width: xs);
  static const SizedBox gapW6 = SizedBox(width: sm);
  static const SizedBox gapW8 = SizedBox(width: md);
  static const SizedBox gapW10 = SizedBox(width: 10);
  static const SizedBox gapW12 = SizedBox(width: lg);
}
