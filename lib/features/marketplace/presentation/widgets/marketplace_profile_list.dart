import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../data/marketplace_model.dart';
import '../../data/marketplace_repository.dart';

/// 프로필(내/타인)에서 해당 유저가 등록한 중고거래 목록.
/// [userId]가 null이면 내 목록(myMarketplaceItemsProvider),
/// 값이 있으면 해당 유저 목록(userMarketplaceItemsProvider).
/// 상태 태그(판매중/구매중/예약중/완료)를 항상 표시, 탭하면 상세로 이동.
class MarketplaceProfileList extends ConsumerWidget {
  const MarketplaceProfileList({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final sub = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;

    final async = userId == null
        ? ref.watch(myMarketplaceItemsProvider)
        : ref.watch(userMarketplaceItemsProvider(userId!));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('불러오기 실패', style: TextStyle(color: sub))),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.shoppingBag,
                    size: 48,
                    color: isDark
                        ? const Color(0xFF3F3F46)
                        : const Color(0xFFA1A1AA)),
                const SizedBox(height: 12),
                Text('등록한 중고거래 상품이 없어요',
                    style: TextStyle(color: sub, fontSize: 14)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (_, i) => _row(context, items[i], isDark, sub, cardBg),
        );
      },
    );
  }

  Widget _row(BuildContext context, MarketplaceItem item, bool isDark,
      Color sub, Color cardBg) {
    final statusColor = _statusColor(item);
    return GestureDetector(
      onTap: () => context.push('/marketplace/${item.id}', extra: item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: item.imageUrls.isNotEmpty
                    ? Image.network(
                        item.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbPh(isDark, sub),
                      )
                    : _thumbPh(isDark, sub),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    item.price <= 0 ? '가격 미정' : item.formattedPrice,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? AppColors.neonGreen : AppColors.navy),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(item.statusLabel,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPh(bool isDark, Color sub) => Container(
        color: isDark ? AppColors.darkSurface2 : AppColors.lightBg,
        child: Icon(LucideIcons.image, size: 18, color: sub),
      );

  // 판매중 초록 / 구매중 파랑 / 예약중 주황 / 완료 회색
  Color _statusColor(MarketplaceItem item) {
    if (item.isBuy && item.status == 'selling') {
      return const Color(0xFF3B82F6);
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
}
