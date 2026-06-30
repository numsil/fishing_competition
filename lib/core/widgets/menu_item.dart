import 'package:flutter/material.dart';
import '../extensions/theme_extensions.dart';
import '../theme/app_colors.dart';

/// 옵션 시트(showAppActionSheet)에서 사용하는 아이콘 + 라벨 메뉴 항목.
///
/// 색 규칙(앱 통일):
/// - 일반 항목: 아이콘·텍스트 모두 기본 텍스트색
/// - 파괴적 항목(삭제/로그아웃 등): [destructive] = true → 빨강
/// - 특수하게 색을 강제해야 할 때만 [color] 지정
class AppMenuItem extends StatelessWidget {
  const AppMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  /// 색 강제 지정(거의 불필요). 미지정 시 destructive면 빨강, 아니면 기본 텍스트색.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color fg = color ??
        (destructive
            ? AppColors.error
            : (context.isDark ? AppColors.darkText : AppColors.lightText));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 21),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.5,
                color: fg,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
