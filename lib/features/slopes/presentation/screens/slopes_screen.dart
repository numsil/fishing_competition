import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/menu_item.dart';
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
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 제보 메뉴 — 새 슬로프 제보 / 오류 신고
  Future<void> _openReportMenu() async {
    await showAppActionSheet<void>(
      context,
      items: [
        AppMenuItem(
          icon: LucideIcons.mapPin,
          label: '새 슬로프 제보',
          showIcon: true,
          onTap: () {
            Navigator.pop(context);
            context.push(AppRoutes.slopeReportNew);
          },
        ),
        AppMenuItem(
          icon: LucideIcons.alertTriangle,
          label: '오류 신고',
          showIcon: true,
          onTap: () {
            Navigator.pop(context);
            context.push(AppRoutes.slopeReportError);
          },
        ),
      ],
    );
  }

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
        actions: [
          // 전체 지도 보기
          IconButton(
            onPressed: () => context.push(AppRoutes.slopesMap),
            icon: Icon(LucideIcons.map, color: textColor, size: 22),
            tooltip: '지도로 보기',
          ),
          // 제보 메뉴
          IconButton(
            onPressed: _openReportMenu,
            icon: Icon(LucideIcons.moreVertical, color: textColor, size: 22),
            tooltip: '제보',
          ),
        ],
      ),
      body: slopesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: LucideIcons.alertCircle,
          message: '슬로프 정보를 불러오지 못했어요',
          subColor: subColor,
        ),
        data: (slopes) {
          final searching = _query.trim().isNotEmpty;

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

          // 검색어가 있으면 전체 슬로프 대상으로 검색(칩 필터 무시),
          // 없으면 시도/시군구 칩 필터 적용
          final List<Slope> filtered;
          if (searching) {
            final q = _query.trim().toLowerCase();
            filtered = slopes.where((s) {
              return s.name.toLowerCase().contains(q) ||
                  s.address.toLowerCase().contains(q) ||
                  s.waterBody.toLowerCase().contains(q) ||
                  s.sigungu.toLowerCase().contains(q);
            }).toList();
          } else {
            filtered = _selectedSigungu == '전체'
                ? sidoFiltered
                : sidoFiltered
                    .where((s) => s.sigungu == _selectedSigungu)
                    .toList();
          }

          return Column(
            children: [
              // ── 검색바 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
                child: AppTextField(
                  controller: _searchController,
                  hint: '이름·지역·수계 검색',
                  prefixIcon:
                      Icon(LucideIcons.search, size: 18, color: subColor),
                  suffixIcon: searching
                      ? IconButton(
                          icon: Icon(LucideIcons.x, size: 18, color: subColor),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              // ── 이용 주의 안내 ──
              _noticeBar(isDark),
              // ── 시도 필터 칩 (검색 중엔 숨김) ──
              if (!searching)
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
              if (!searching && sigungus.length > 1)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.xs,
                    ),
                    children: [
                      for (final sgg in sigungus)
                        _sigunguChip(sgg, sigunguCounts[sgg]!, accent, isDark),
                    ],
                  ),
                ),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        icon:
                            searching ? LucideIcons.search : LucideIcons.mapPin,
                        message: searching
                            ? '검색 결과가 없어요'
                            : '해당 지역에 슬로프가 없어요',
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

  /// 슬로프 이용 전 확인 안내 (정보 변동 가능성).
  Widget _noticeBar(bool isDark) {
    final subColor = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.alertTriangle,
              size: 15, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '슬로프 정보는 실제와 다를 수 있습니다. 이용가능여부는 방문 전 반드시 확인하세요.',
              style: AppTextStyles.captionSmall.copyWith(
                color: subColor,
                height: 1.4,
              ),
            ),
          ),
        ],
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
        // 재탭 시 해제 → 시도 전체 목록으로 복귀
        onSelected: (_) => setState(
            () => _selectedSigungu = selected ? '전체' : label),
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

  /// 카드 탭: 앱 내 지도로 이동 (좌표 있는 슬로프).
  /// 좌표가 없는 예외 케이스만 외부 네이버지도 앱으로 폴백.
  /// (지도 화면 안에 "네이버지도 앱에서 열기" 버튼이 별도로 제공됨)
  Future<void> _openMap(BuildContext context) async {
    if (slope.hasCoordinates) {
      context.push(AppRoutes.slopesMap, extra: slope);
      return;
    }
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
      onTap: () => _openMap(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 위성 썸네일 (원격 thumb_url 우선, 없으면 내장 에셋) ──
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: slope.hasRemoteThumb
                ? CachedNetworkImage(
                    imageUrl: slope.thumbUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  )
                : Image.asset(
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
                        slope.displayName,
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
