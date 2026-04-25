import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  // 제목
  static const TextStyle heading1 = TextStyle(fontSize: 20, fontWeight: FontWeight.w800);
  static const TextStyle heading2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w800);
  static const TextStyle heading3 = TextStyle(fontSize: 16, fontWeight: FontWeight.w800);
  static const TextStyle heading4 = TextStyle(fontSize: 15, fontWeight: FontWeight.w800);

  // 본문
  static const TextStyle bodyBold = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
  static const TextStyle body = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
  static const TextStyle bodySmall = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);

  // 캡션
  static const TextStyle caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
  static const TextStyle captionBold = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
  static const TextStyle captionSmall = TextStyle(fontSize: 11, fontWeight: FontWeight.w500);

  // 배지/칩
  static const TextStyle badge = TextStyle(fontSize: 10, fontWeight: FontWeight.w800);
}
