import 'package:flutter/material.dart';
import '../extensions/theme_extensions.dart';
import '../theme/app_colors.dart';

/// 옵션 시트(showAppActionSheet)에서 사용하는 메뉴 항목.
///
/// 디자인: 아이콘을 둥근사각 틴트 타일에 담아 입체감/고급감을 준다.
///
/// 색 규칙(앱 통일):
/// - 일반 항목: 아이콘·텍스트 = 기본 텍스트색, 타일 = 은은한 중립 틴트
/// - 파괴적 항목(삭제/로그아웃 등): [destructive] = true → 빨강 + 빨강 틴트 타일
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
    final isDark = context.isDark;

    final Color fg = color ??
        (destructive
            ? AppColors.error
            : (isDark ? AppColors.darkText : AppColors.lightText));

    // 아이콘 타일 배경
    final Color tileBg = destructive
        ? AppColors.error.withValues(alpha: isDark ? 0.16 : 0.10)
        : (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.05));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: fg, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15.5,
                  color: fg,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
