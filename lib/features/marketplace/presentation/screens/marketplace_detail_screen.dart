import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../../core/widgets/menu_item.dart';
import '../../../../core/widgets/slide_to_confirm.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/utils/time_ago.dart' show formatTimeAgo;
import '../../../auth/data/auth_repository.dart';
import '../../../dm/data/dm_repository.dart';
import '../../../report/presentation/widgets/report_reason_sheet.dart';
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

    Future<void> changeStatus(String v) async {
      await ref.read(marketplaceRepositoryProvider).updateStatus(item.id, v);
      ref.read(marketplaceListProvider.notifier).refresh();
      ref.invalidate(myMarketplaceItemsProvider);
      ref.invalidate(userMarketplaceItemsProvider(item.userId));
      if (context.mounted) {
        AppSnackBar.info(context, '상태가 변경됐습니다.');
        context.pop();
      }
    }

    void confirmDelete() {
      showDeleteConfirmSheet(
        context,
        title: '매물 삭제',
        content: '이 매물을 삭제할까요?',
        onConfirmed: () async {
          try {
            await ref.read(marketplaceRepositoryProvider).deleteItem(item.id);
            await ref.read(marketplaceListProvider.notifier).refresh();
            ref.invalidate(myMarketplaceItemsProvider);
            ref.invalidate(userMarketplaceItemsProvider(item.userId));
            if (context.mounted) {
              AppSnackBar.info(context, '삭제됐습니다.');
              context.pop();
            }
          } catch (e) {
            if (context.mounted) AppSnackBar.error(context, '삭제 실패: $e');
          }
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('중고거래'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.moreHorizontal),
            onPressed: () {
              if (isOwner) {
                showAppActionSheet(context, items: [
                  if (item.status != 'selling')
                    AppMenuItem(
                      icon: LucideIcons.tag,
                      label: item.isBuy ? '구매중으로 변경' : '판매중으로 변경',
                      onTap: () {
                        Navigator.pop(context);
                        changeStatus('selling');
                      },
                    ),
                  if (item.status != 'reserved')
                    AppMenuItem(
                      icon: LucideIcons.clock,
                      label: '예약중으로 변경',
                      onTap: () {
                        Navigator.pop(context);
                        changeStatus('reserved');
                      },
                    ),
                  if (item.status != 'sold')
                    AppMenuItem(
                      icon: LucideIcons.checkCircle,
                      label: item.isBuy ? '구매완료로 변경' : '판매완료로 변경',
                      onTap: () {
                        Navigator.pop(context);
                        changeStatus('sold');
                      },
                    ),
                  const AppMenuDivider(),
                  AppMenuItem(
                    icon: LucideIcons.trash2,
                    label: '삭제',
                    destructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      confirmDelete();
                    },
                  ),
                ]);
              } else {
                showAppActionSheet(context, items: [
                  AppMenuItem(
                    icon: LucideIcons.flag,
                    label: '신고하기',
                    destructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      ReportReasonSheet.showForMarketplace(context, item.id);
                    },
                  ),
                ]);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지
            if (item.imageUrls.isNotEmpty)
              _ImageCarousel(images: item.imageUrls),

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

                  // 제목 + 등록자
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatTimeAgo(item.createdAt),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 등록자 (탭 → 프로필 보기)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.push('/user/${item.userId}'),
                        child: SizedBox(
                          width: 64,
                          child: Column(
                            children: [
                              UserAvatar(
                                username: item.username,
                                avatarUrl: item.avatarUrl,
                                radius: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 가격 (삽니다·희망가 미입력이면 '가격 미정')
                  Text(
                    item.price <= 0
                        ? '가격 미정'
                        : (item.isBuy ? '희망가 ${item.formattedPrice}' : item.formattedPrice),
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

                  // 개인 간 거래 면책 안내 (판매글·구매글 공통)
                  const SizedBox(height: 24),
                  _TradeDisclaimer(isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
      // 문의하기: 스크롤과 무관하게 항상 보이는 하단 고정 바 (타인 글만)
      bottomNavigationBar: isOwner
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AppButton(
                label: '문의하기',
                onPressed: () async {
                  try {
                    final conversationId = await ref
                        .read(dmRepositoryProvider)
                        .getOrCreateConversation(item.userId);
                    if (context.mounted) {
                      context.push(
                        '/dm/chat',
                        extra: DmConversation(
                          id: conversationId,
                          otherUserId: item.userId,
                          otherUsername: item.username,
                          otherAvatarUrl: item.avatarUrl,
                          lastMessageAt: DateTime.now(),
                          hasUnread: false,
                        ),
                      );
                    }
                  } on DmBlockedException {
                    if (context.mounted) {
                      AppSnackBar.error(context, '차단된 사용자입니다');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppSnackBar.error(context, '메시지를 시작할 수 없습니다');
                    }
                  }
                },
              ),
            ),
    );
  }
}

/// 중고거래 상세 하단 면책 안내
class _TradeDisclaimer extends StatelessWidget {
  const _TradeDisclaimer({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final fg = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF777777);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.shieldAlert, size: 15, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '개인 간 거래로 발생한 분쟁·사기·피해에 대해 낚스타는 책임지지 않습니다. 거래 시 주의하세요.',
              style: TextStyle(fontSize: 12, height: 1.5, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 상세 이미지 캐러셀 (카운터 + 좌우 화살표 + 탭하면 전체화면) ──
class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel({required this.images});
  final List<String> images;

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  final PageController _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int index) => _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final multi = images.length > 1;
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: images.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => _FullScreenGallery(
                    images: images,
                    initialIndex: i,
                  ),
                ),
              ),
              child: Image.network(
                images[i],
                fit: BoxFit.cover,
                width: double.infinity,
                height: 300,
              ),
            ),
          ),
          if (multi) ...[
            // 장수 카운터
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_current + 1} / ${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // 왼쪽 화살표
            if (_current > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _ArrowButton(
                    icon: LucideIcons.chevronLeft,
                    onTap: () => _go(_current - 1),
                  ),
                ),
              ),
            // 오른쪽 화살표
            if (_current < images.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _ArrowButton(
                    icon: LucideIcons.chevronRight,
                    onTap: () => _go(_current + 1),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery({required this.images, required this.initialIndex});
  final List<String> images;
  final int initialIndex;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _current = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: widget.images.length > 1
            ? Text('${_current + 1} / ${widget.images.length}',
                style: const TextStyle(fontSize: 14, color: Colors.white))
            : null,
      ),
      body: PageView.builder(
        controller: _controller,
        onPageChanged: (i) => setState(() => _current = i),
        itemCount: widget.images.length,
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.network(widget.images[i], fit: BoxFit.contain),
          ),
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
