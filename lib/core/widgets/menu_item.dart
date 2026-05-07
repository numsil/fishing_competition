import 'package:flutter/material.dart';

/// 옵션 시트 등에서 사용되는 아이콘 + 라벨 메뉴 항목
class AppMenuItem extends StatelessWidget {
  const AppMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
