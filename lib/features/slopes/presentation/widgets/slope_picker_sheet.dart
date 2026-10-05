import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/slope_model.dart';
import '../../data/slopes_repository.dart';

/// 슬로프 선택 바텀시트 — 검색 후 하나를 고르면 [Slope]를 반환한다.
/// (오류 신고에서 대상 슬로프 지정용)
Future<Slope?> showSlopePickerSheet(BuildContext context) {
  return showModalBottomSheet<Slope>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SlopePickerSheet(),
  );
}

class _SlopePickerSheet extends ConsumerStatefulWidget {
  const _SlopePickerSheet();

  @override
  ConsumerState<_SlopePickerSheet> createState() => _SlopePickerSheetState();
}

class _SlopePickerSheetState extends ConsumerState<_SlopePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final slopesAsync = ref.watch(slopesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // 핸들
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    Text('슬로프 선택',
                        style:
                            AppTextStyles.heading3.copyWith(color: textColor)),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: AppTextField(
                  controller: _searchController,
                  hint: '이름·지역·수계 검색',
                  autofocus: true,
                  prefixIcon:
                      Icon(LucideIcons.search, size: 18, color: subColor),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: slopesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => EmptyState(
                    icon: LucideIcons.alertCircle,
                    message: '슬로프 정보를 불러오지 못했어요',
                    subColor: subColor,
                  ),
                  data: (slopes) {
                    final q = _query.trim().toLowerCase();
                    final filtered = q.isEmpty
                        ? slopes
                        : slopes.where((s) {
                            return s.name.toLowerCase().contains(q) ||
                                s.address.toLowerCase().contains(q) ||
                                s.waterBody.toLowerCase().contains(q) ||
                                s.sigungu.toLowerCase().contains(q);
                          }).toList();
                    if (filtered.isEmpty) {
                      return EmptyState(
                        icon: LucideIcons.search,
                        message: '검색 결과가 없어요',
                        subColor: subColor,
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0,
                          AppSpacing.xl, AppSpacing.xxxl),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark
                            ? AppColors.darkDivider
                            : AppColors.lightDivider,
                      ),
                      itemBuilder: (context, i) {
                        final s = filtered[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.displayName,
                              style: AppTextStyles.body
                                  .copyWith(color: textColor)),
                          subtitle: Text(s.address,
                              style: AppTextStyles.caption
                                  .copyWith(color: subColor)),
                          onTap: () => Navigator.pop(context, s),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
