import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/deep_link/deep_link_service.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/notification_repository.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    // 진입 시 전체 읽음 처리 + 앱 아이콘 배지 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(notificationRepositoryProvider).markAllRead();
      try {
        await AppBadgePlus.updateBadge(0);
      } catch (_) {/* 배지 미지원 기기 무시 */}
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.isDark ? AppColors.darkBg : Colors.white;
    final sub = context.isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft,
              color: context.isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text('알림',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.isDark ? Colors.white : Colors.black)),
        centerTitle: true,
      ),
      body: ref.watch(notificationListProvider).when(
            skipLoadingOnReload: true,
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.bell,
                          size: 56,
                          color: context.isDark
                              ? const Color(0xFF333333)
                              : const Color(0xFFCCCCCC)),
                      const SizedBox(height: 16),
                      Text('아직 알림이 없습니다',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.isDark ? Colors.white : Colors.black)),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationListProvider),
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final n = items[i];
                    return Slidable(
                      key: ValueKey(n.id),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.22,
                        children: [
                          CustomSlidableAction(
                            onPressed: (_) => ref
                                .read(notificationRepositoryProvider)
                                .deleteNotification(n.id),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_outline, size: 22),
                                SizedBox(height: 4),
                                Text('삭제',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      child: InkWell(
                      onTap: () {
                        final route = routeFromNotification(n.type, n.targetId,
                            actorId: n.actorId);
                        if (route != null) context.push(route);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            UserAvatar(
                              username: n.actorUsername,
                              avatarUrl: n.actorAvatarUrl,
                              radius: 24,
                              isDark: context.isDark,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_label(n.type, n.actorUsername),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text(n.body,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, color: sub)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_formatTime(n.createdAt),
                                style: TextStyle(fontSize: 11, color: sub)),
                          ],
                        ),
                      ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('알림을 불러오지 못했습니다', style: TextStyle(color: sub))),
          ),
    );
  }

  String _label(String type, String actor) {
    switch (type) {
      case 'dm':
        return '$actor님의 메시지';
      case 'comment':
        return '$actor님이 댓글을 남겼습니다';
      case 'follow':
        return '$actor님이 팔로우했습니다';
      default:
        return '알림';
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}
