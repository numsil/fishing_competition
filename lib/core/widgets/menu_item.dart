import 'package:flutter/material.dart';
import '../extensions/theme_extensions.dart';
import '../theme/app_colors.dart';

/// 옵션 시트(showAppActionSheet)에서 사용하는 메뉴 항목.
///
/// 디자인: 기본은 iOS 네이티브 액션시트 스타일 — 아이콘 없이 중앙 정렬 텍스트.
/// [showIcon] = true면 왼쪽에 아이콘 + 좌측정렬 텍스트(예: 이미지 소스 선택).
/// 카드/구분선은 [showAppActionSheet]가 그린다.
///
/// 색 규칙(앱 통일):
/// - 일반 항목: 기본 텍스트색 (아이콘 표시 시 아이콘은 accent)
/// - 파괴적 항목(삭제/로그아웃 등): [destructive] = true → 빨강
/// - 특수하게 색을 강제해야 할 때만 [color] 지정
class AppMenuItem extends StatelessWidget {
  const AppMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.showIcon = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  /// true면 아이콘을 왼쪽에 표시(좌측정렬). 기본은 아이콘 없이 중앙정렬.
  final bool showIcon;

  /// 색 강제 지정(거의 불필요). 미지정 시 destructive면 빨강, 아니면 기본 텍스트색.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final Color fg = color ??
        (destructive
            ? AppColors.error
            : (isDark ? AppColors.darkText : AppColors.lightText));

    if (showIcon) {
      final Color iconColor = destructive ? AppColors.error : context.accentColor;
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: fg,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16.5,
            color: fg,
            fontWeight: destructive ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }
}
