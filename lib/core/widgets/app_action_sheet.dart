import 'package:flutter/material.dart';
import '../extensions/theme_extensions.dart';
import '../theme/app_colors.dart';

/// 앱 공통 옵션 바텀시트 — iOS 네이티브 액션시트 스타일.
///
/// - [items]에는 [AppMenuItem]들을 넣는다. 그룹을 나눌 땐 사이에
///   [AppMenuDivider]를 넣으면 카드가 분리된다.
/// - 같은 그룹 안의 항목들은 한 카드에 모이고 사이에 얇은 선이 들어간다.
/// - 하단에 분리된 "취소" 버튼이 자동으로 붙는다.
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  required List<Widget> items,
  String? title,
  bool isScrollControlled = false,
}) {
  final isDark = context.isDark;
  final Color cardColor = isDark ? AppColors.darkSurface2 : Colors.white;
  final Color divColor = isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.08);
  final Color cancelColor = isDark ? AppColors.darkText : AppColors.lightText;
  final Color titleColor =
      isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

  // items를 AppMenuDivider 기준으로 그룹(카드) 분할
  final groups = <List<Widget>>[];
  var current = <Widget>[];
  for (final it in items) {
    if (it is AppMenuDivider) {
      if (current.isNotEmpty) {
        groups.add(current);
        current = <Widget>[];
      }
    } else {
      current.add(it);
    }
  }
  if (current.isNotEmpty) groups.add(current);

  Widget buildCard(List<Widget> rows, {Widget? header}) {
    final children = <Widget>[];
    if (header != null) {
      children.add(header);
      children.add(Divider(height: 1, thickness: 1, color: divColor));
    }
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(Divider(height: 1, thickness: 1, color: divColor));
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: cardColor,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var g = 0; g < groups.length; g++) ...[
                if (g == 0 && title != null)
                  buildCard(
                    groups[g],
                    header: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                          color: titleColor,
                        ),
                      ),
                    ),
                  )
                else
                  buildCard(groups[g]),
                const SizedBox(height: 8),
              ],
              // 취소 버튼 (분리된 카드)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Material(
                  color: cardColor,
                  child: InkWell(
                    onTap: () => Navigator.pop(sheetCtx),
                    child: SizedBox(
                      height: 56,
                      child: Center(
                        child: Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: cancelColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 옵션 시트에서 항목 그룹(카드)을 나누는 마커.
/// 실제로는 렌더되지 않고 [showAppActionSheet]가 카드 분리 기준으로만 사용한다.
class AppMenuDivider extends StatelessWidget {
  const AppMenuDivider({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
