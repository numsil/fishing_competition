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

const _categories = ['전체', '낚시대', '릴', '루어', '소품', '기타'];

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
                return EmptyState(
                  icon: LucideIcons.shoppingBag,
                  message: widget.searchQuery.trim().isNotEmpty
                      ? '검색 결과가 없습니다.'
                      : '등록된 중고거래 상품이 없습니다.',
                  subColor: Colors.grey,
                );
              }

              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(marketplaceListProvider.notifier).refresh(),
                child: GridView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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

  @override
  Widget build(BuildContext context) {
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
                child: item.imageUrls.isNotEmpty
                    ? Image.network(
                        item.imageUrls.first,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                          child: const Icon(LucideIcons.image, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                        child: const Icon(LucideIcons.image, color: Colors.grey),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상태 배지
                  if (!item.isSelling)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.statusLabel,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
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
                    item.formattedPrice,
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
