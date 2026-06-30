import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/marketplace_model.dart';
import '../../data/marketplace_repository.dart';

const _categories = ['전체', '낚시대', '릴', '루어/채비', '보팅', '기타'];

/// 중고거래 목록 보기 모드 (false=카드/그리드, true=리스트). 검색창 옆 토글과 공유.
final marketplaceListViewProvider = StateProvider<bool>((ref) => false);

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key, this.searchQuery = ''});
  final String searchQuery;

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  String _selectedCategory = '전체';
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(MarketplaceScreen old) {
    super.didUpdateWidget(old);
    // 공유 검색어 변경 시 디바운스 후 서버 재조회
    if (old.searchQuery != widget.searchQuery) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        ref.read(marketplaceListProvider.notifier).setFilter(
              category: _selectedCategory,
              search: widget.searchQuery,
            );
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      ref.read(marketplaceListProvider.notifier).loadMore();
    }
  }

  void _selectCategory(String cat) {
    setState(() => _selectedCategory = cat);
    ref.read(marketplaceListProvider.notifier).setFilter(
          category: cat,
          search: widget.searchQuery,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.accentColor;
    final items = ref.watch(marketplaceListProvider);
    final isList = ref.watch(marketplaceListViewProvider);

    return Column(
      children: [
        const SizedBox(height: 12),
        // 카테고리 필터
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final selected = cat == _selectedCategory;
              return GestureDetector(
                onTap: () => _selectCategory(cat),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? accent : (isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD)),
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: items.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('불러오기 실패: $e')),
            data: (list) {
              if (list.isEmpty) {
                // 빈 상태에서도 당겨서 새로고침 가능하게 스크롤 가능 영역으로 감쌈
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(marketplaceListProvider.notifier).refresh(),
                  child: LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: c.maxHeight,
                        child: EmptyState(
                          icon: LucideIcons.shoppingBag,
                          message: widget.searchQuery.trim().isNotEmpty
                              ? '검색 결과가 없습니다.'
                              : '등록된 중고거래 상품이 없습니다.',
                          subColor: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(marketplaceListProvider.notifier).refresh(),
                child: isList
                    ? ListView.separated(
                        controller: _scrollCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _MarketplaceListCard(
                          item: list[i],
                          isDark: isDark,
                        ),
                      )
                    : GridView.builder(
                        controller: _scrollCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _MarketplaceCard(
                          item: list[i],
                          isDark: isDark,
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({required this.item, required this.isDark});
  final MarketplaceItem item;
  final bool isDark;

  Color get _statusColor {
    // 삽니다(구매중)는 파랑으로 판매중(초록)과 구분
    if (item.isBuy && item.status == 'selling') {
      return const Color(0xFF3B82F6); // 구매중 - 파랑
    }
    switch (item.status) {
      case 'reserved':
        return const Color(0xFFFF9500); // 예약중 - 주황
      case 'sold':
        return const Color(0xFF8E8E93); // 판매완료/구매완료 - 회색
      default:
        return const Color(0xFF34C759); // 판매중 - 초록
    }
  }

  @override
  Widget build(BuildContext context) {
    final sold = item.status == 'sold';
    final placeholder = Container(
      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
      child: const Icon(LucideIcons.image, color: Colors.grey),
    );
    Widget image = item.imageUrls.isNotEmpty
        ? Image.network(
            item.imageUrls.first,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) => placeholder,
          )
        : placeholder;
    // 판매완료는 흑백 처리
    if (sold) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: image,
      );
    }
    return GestureDetector(
      onTap: () => context.push('/marketplace/${item.id}', extra: item),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 (남는 세로 공간을 채워 비율과 무관하게 오버플로우 방지)
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image,
                    if (sold) Container(color: Colors.black.withValues(alpha: 0.22)),
                    // 판매 상태 배지
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.statusLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.price <= 0 ? '가격 미정' : item.formattedPrice,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.neonGreen : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      UserAvatar(username: item.username, avatarUrl: item.avatarUrl, radius: 8),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드/리스트 공통 상태 색 (판매중 초록 / 구매중 파랑 / 예약중 주황 / 완료 회색)
Color _marketplaceStatusColor(MarketplaceItem item) {
  if (item.isBuy && item.status == 'selling') {
    return const Color(0xFF3B82F6); // 구매중 - 파랑
  }
  switch (item.status) {
    case 'reserved':
      return const Color(0xFFFF9500);
    case 'sold':
      return const Color(0xFF8E8E93);
    default:
      return const Color(0xFF34C759);
  }
}

/// 리스트(가로형) 보기용 카드
class _MarketplaceListCard extends StatelessWidget {
  const _MarketplaceListCard({required this.item, required this.isDark});
  final MarketplaceItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final statusColor = _marketplaceStatusColor(item);
    final placeholder = Container(
      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
      child: const Icon(LucideIcons.image, color: Colors.grey),
    );
    Widget image = item.imageUrls.isNotEmpty
        ? Image.network(
            item.imageUrls.first,
            fit: BoxFit.cover,
            width: 76,
            height: 76,
            errorBuilder: (_, __, ___) => placeholder,
          )
        : SizedBox(width: 76, height: 76, child: placeholder);
    if (item.status == 'sold') {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: image,
      );
    }

    return GestureDetector(
      onTap: () => context.push('/marketplace/${item.id}', extra: item),
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: SizedBox(width: 76, height: 76, child: image),
            ),
            // 가운데: 제목 + 가격
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.price <= 0 ? '가격 미정' : item.formattedPrice,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.neonGreen : AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 우측: 상태 태그 + 판매자 이름
            Padding(
              padding: const EdgeInsets.only(right: 10, left: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.statusLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 84),
                    child: Text(
                      item.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
