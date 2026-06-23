import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/utils/time_ago.dart' show formatTimeAgo;
import '../../../auth/data/auth_repository.dart';
import '../../../dm/data/dm_repository.dart';
import '../../data/marketplace_model.dart';
import '../../data/marketplace_repository.dart';

class MarketplaceDetailScreen extends ConsumerWidget {
  const MarketplaceDetailScreen({super.key, required this.item});
  final MarketplaceItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final accent = context.accentColor;
    final me = ref.watch(currentUserProvider);
    final isOwner = me?.id == item.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('중고거래'),
        actions: [
          if (isOwner)
            PopupMenuButton<String>(
              icon: const Icon(LucideIcons.moreVertical),
              onSelected: (v) async {
                if (v == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('삭제'),
                      content: const Text('게시글을 삭제할까요?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await ref.read(marketplaceRepositoryProvider).deleteItem(item.id);
                    ref.invalidate(marketplaceItemsProvider);
                    if (context.mounted) context.pop();
                  }
                } else {
                  await ref.read(marketplaceRepositoryProvider).updateStatus(item.id, v);
                  ref.invalidate(marketplaceItemsProvider);
                  if (context.mounted) {
                    AppSnackBar.info(context, '상태가 변경됐습니다.');
                    context.pop();
                  }
                }
              },
              itemBuilder: (_) => [
                if (item.status != 'selling')
                  const PopupMenuItem(value: 'selling', child: Text('판매중으로 변경')),
                if (item.status != 'reserved')
                  const PopupMenuItem(value: 'reserved', child: Text('예약중으로 변경')),
                if (item.status != 'sold')
                  const PopupMenuItem(value: 'sold', child: Text('판매완료로 변경')),
                const PopupMenuItem(value: 'delete', child: Text('삭제', style: TextStyle(color: Colors.red))),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지
            if (item.imageUrls.isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  itemCount: item.imageUrls.length,
                  itemBuilder: (_, i) => Image.network(
                    item.imageUrls[i],
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상태 + 카테고리
                  Row(
                    children: [
                      _Badge(item.statusLabel,
                          color: item.isSelling ? accent : Colors.grey),
                      const SizedBox(width: 8),
                      _Badge(item.category, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 제목
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 시간
                  Text(
                    formatTimeAgo(item.createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // 가격
                  Text(
                    item.formattedPrice,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.neonGreen : AppColors.navy,
                    ),
                  ),

                  if (item.location != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(LucideIcons.mapPin, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(item.location!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ],

                  const Divider(height: 32),

                  // 설명
                  if (item.description != null && item.description!.isNotEmpty)
                    Text(
                      item.description!,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),

                  const Divider(height: 32),

                  // 판매자
                  Row(
                    children: [
                      UserAvatar(username: item.username, avatarUrl: item.avatarUrl, radius: 20),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.username,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '@${item.userKey}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // DM 문의 버튼
                  if (!isOwner)
                    AppButton(
                      label: 'DM으로 문의하기',
                      onPressed: () async {
                        final repo = ref.read(dmRepositoryProvider);
                        final conv = await repo.getOrCreateConversation(item.userId);
                        if (context.mounted) {
                          context.push('/dm/chat', extra: conv);
                        }
                      },
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

class _Badge extends StatelessWidget {
  const _Badge(this.label, {required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
