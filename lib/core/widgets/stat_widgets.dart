import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 숫자 + 라벨 (프로필 팔로워/게시물 수 등)
class StatNumber extends StatelessWidget {
  const StatNumber({
    super.key,
    required this.value,
    required this.label,
    required this.subColor,
  });

  final String value;
  final String label;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      Text(label, style: TextStyle(fontSize: 11, color: subColor)),
    ]);
  }
}

/// 아이콘 + 숫자 + 라벨이 있는 bordered 박스 (통계 카드)
class StatBox extends StatelessWidget {
  const StatBox({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.isDark,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
          ),
        ),
        child: Column(children: [
          Icon(icon, size: 18, color: sub),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: accent)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: sub)),
        ]),
      ),
    );
  }
}
