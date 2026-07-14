import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/slope_model.dart';
import '../../data/slopes_repository.dart';

/// 슬로프 찾기: 지역(시도)별 슬로프 목록 + 네이버지도 바로가기 (테스트 버전)
class SlopesScreen extends ConsumerStatefulWidget {
  const SlopesScreen({super.key});

  @override
  ConsumerState<SlopesScreen> createState() => _SlopesScreenState();
}

class _SlopesScreenState extends ConsumerState<SlopesScreen> {
  String _selectedSido = '전체';
  String _selectedSigungu = '전체';

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final slopesAsync = ref.watch(slopesProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          '슬로프 찾기',
          style: AppTextStyles.heading3.copyWith(color: textColor),
        ),
      ),
      body: slopesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: LucideIcons.alertCircle,
          message: '슬로프 정보를 불러오지 못했어요',
          subColor: subColor,
        ),
        data: (slopes) {
          // 시도 카테고리 (데이터 순서 유지 + 개수)
          final sidoCounts = <String, int>{};
          for (final s in slopes) {
            sidoCounts[s.sido] = (sidoCounts[s.sido] ?? 0) + 1;
          }
          final sidos = sidoCounts.keys.toList()..sort();
          final sidoFiltered = _selectedSido == '전체'
              ? slopes
              : slopes.where((s) => s.sido == _selectedSido).toList();

          // 선택된 시도의 시군구 카테고리 (2차 필터)
          final sigunguCounts = <String, int>{};
          if (_selectedSido != '전체') {
            for (final s in sidoFiltered) {
              sigunguCounts[s.sigungu] = (sigunguCounts[s.sigungu] ?? 0) + 1;
            }
          }
          final sigungus = sigunguCounts.keys.toList()..sort();
          final filtered = _selectedSigungu == '전체'
              ? sidoFiltered
              : sidoFiltered
                  .where((s) => s.sigungu == _selectedSigungu)
                  .toList();

          return Column(
            children: [
              // ── 시도 필터 칩 ──
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.sm,
                  ),
                  children: [
                    _sidoChip('전체', slopes.length, accent, isDark),
                    for (final sido in sidos)
                      _sidoChip(sido, sidoCounts[sido]!, accent, isDark),
                  ],
                ),
              ),
              // ── 시군구 필터 칩 (시도 선택 시, 2곳 이상일 때) ──
              if (sigungus.length > 1)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.xs,
                    ),
                    children: [
                      _sigunguChip('전체', sidoFiltered.length, accent, isDark),
                      for (final sgg in sigungus)
                        _sigunguChip(sgg, sigunguCounts[sgg]!, accent, isDark),
                    ],
                  ),
                ),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        icon: LucideIcons.mapPin,
                        message: '해당 지역에 슬로프가 없어요',
                        subColor: subColor,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xxxl),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _SlopeCard(
                          slope: filtered[i],
                          isDark: isDark,
                          accent: accent,
                          textColor: textColor,
                          subColor: subColor,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sidoChip(String label, int count, Color accent, bool isDark) {
    final selected = _selectedSido == label;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: ChoiceChip(
        label: Text('$label $count'),
        selected: selected,
        onSelected: (_) => setState(() {
          _selectedSido = label;
          _selectedSigungu = '전체'; // 시도 변경 시 시군구 초기화
        }),
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: selected
              ? (isDark ? Colors.black : Colors.white)
              : (isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        selectedColor: accent,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        showCheckmark: false,
        side: BorderSide(
          color: selected
              ? accent
              : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _sigunguChip(String label, int count, Color accent, bool isDark) {
    final selected = _selectedSigungu == label;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text('$label $count'),
        selected: selected,
        onSelected: (_) => setState(() => _selectedSigungu = label),
        labelStyle: AppTextStyles.captionSmall.copyWith(
          color: selected
              ? accent
              : (isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        selectedColor: accent.withValues(alpha: isDark ? 0.15 : 0.08),
        backgroundColor: Colors.transparent,
        showCheckmark: false,
        side: BorderSide(
          color: selected
              ? accent
              : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
    );
  }
}

class _SlopeCard extends StatelessWidget {
  const _SlopeCard({
    required this.slope,
    required this.isDark,
    required this.accent,
    required this.textColor,
    required this.subColor,
  });

  final Slope slope;
  final bool isDark;
  final Color accent;
  final Color textColor;
  final Color subColor;

  /// 네이버지도 앱으로 주소 검색 열기. 미설치 시 웹 지도 폴백.
  Future<void> _openNaverMap(BuildContext context) async {
    final query = Uri.encodeComponent(slope.address);
    final appUri = Uri.parse(
        'nmap://search?query=$query&appname=com.glution.nakstar');
    final webUri = Uri.parse('https://map.naver.com/p/search/$query');

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
      return;
    }
    final ok = await launchUrl(webUri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      AppSnackBar.error(context, '지도를 열 수 없어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: EdgeInsets.zero,
      onTap: () => _openNaverMap(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 위성 썸네일 (내장 에셋) ──
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.asset(
              slope.thumbAsset,
              height: 140,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slope.name,
                        style: AppTextStyles.bodyBold.copyWith(color: textColor),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        slope.address,
                        style: AppTextStyles.caption.copyWith(color: subColor),
                      ),
                      if (slope.waterBody.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${slope.sigungu} · ${slope.waterBody}',
                          style:
                              AppTextStyles.captionSmall.copyWith(color: accent),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(LucideIcons.map, color: accent, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
