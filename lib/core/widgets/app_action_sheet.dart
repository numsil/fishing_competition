import 'package:flutter/material.dart';
import '../extensions/theme_extensions.dart';
import '../theme/app_colors.dart';

/// 앱 공통 옵션 바텀시트.
///
/// 둥근 상단 + 그랩 핸들 + SafeArea를 자동 적용한다.
/// [items]에는 보통 [AppMenuItem]들을 넣고, 그룹을 나눌 때만
/// 사이에 [AppMenuDivider]를 넣는다. (매 항목 구분선은 넣지 않음)
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  required List<Widget> items,
  String? title,
  bool isScrollControlled = false,
}) {
  final isDark = context.isDark;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          // 그랩 핸들
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color:
                    isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
          ],
          const SizedBox(height: 8),
          ...items,
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// 옵션 시트 항목 그룹 구분선(은은한 1px + 위아래 여백).
/// 계정/약관/파괴적 액션처럼 의미가 다른 그룹 사이에만 사용한다.
class AppMenuDivider extends StatelessWidget {
  const AppMenuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final color =
        context.isDark ? AppColors.darkDivider : AppColors.lightDivider;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Divider(
        height: 1,
        thickness: 1,
        indent: 20,
        endIndent: 20,
        color: color,
      ),
    );
  }
}
