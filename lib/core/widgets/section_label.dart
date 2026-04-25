import 'package:flutter/material.dart';

/// 섹션 제목 - 왼쪽 컬러 바 + 텍스트
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    ]);
  }
}
