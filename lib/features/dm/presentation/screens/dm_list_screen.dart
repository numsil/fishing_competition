import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/slide_to_confirm.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/dm_repository.dart';
import '../../../../core/extensions/theme_extensions.dart';

class DmListScreen extends ConsumerWidget {
  const DmListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: Text(
          '메시지',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: ref.watch(dmConversationsProvider).when(
        skipLoadingOnReload: true,
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.messageCircle,
                    size: 56,
                    color: context.isDark ? const Color(0xFF333333) : const Color(0xFFCCCCCC),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '아직 대화가 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '낚시 친구에게 메시지를 보내보세요',
                    style: TextStyle(fontSize: 13, color: sub),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dmConversationsProvider),
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, i) {
                final conv = conversations[i];
                final dividerColor = context.isDark
                    ? const Color(0xFF222222)
                    : const Color(0xFFEEEEEE);

                return Slidable(
                  key: ValueKey(conv.id),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.22,
                    children: [
                      CustomSlidableAction(
                        onPressed: (ctx) async {
                          await showDeleteConfirmSheet(
                            ctx,
                            title: '대화방 삭제',
                            content: '${conv.otherUsername}와의 대화를 삭제할까요?\n상대방이 새 메시지를 보내면 다시 나타납니다.',
                            onConfirmed: () {
                              ref.read(dmRepositoryProvider).hideConversation(conv.id);
                              ref.invalidate(dmConversationsProvider);
                            },
                          );
                        },
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline, size: 22),
                            SizedBox(height: 4),
                            Text('삭제', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () =>
                            context.push(AppRoutes.dmChat, extra: conv),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  UserAvatar(
                                    username: conv.otherUsername,
                                    avatarUrl: conv.otherAvatarUrl,
                                    radius: 26,
                                    isDark: context.isDark,
                                  ),
                                  if (conv.hasUnread)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0084FF),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: context.isDark
                                                ? AppColors.darkBg
                                                : Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      conv.otherUsername,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      conv.lastMessage ?? '대화를 시작해보세요',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: conv.lastMessage != null
                                            ? (context.isDark
                                                ? const Color(0xFFAAAAAA)
                                                : const Color(0xFF888888))
                                            : sub,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(conv.lastMessageAt),
                                style: TextStyle(fontSize: 11, color: sub),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i < conversations.length - 1)
                        Divider(
                          height: 0.5,
                          thickness: 0.5,
                          indent: 76,
                          color: dividerColor,
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('메시지를 불러오지 못했습니다',
              style: TextStyle(color: sub)),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}
