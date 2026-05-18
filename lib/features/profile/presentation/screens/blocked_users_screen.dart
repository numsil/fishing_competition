import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../dm/data/dm_repository.dart';
import '../../../feed/data/feed_repository.dart';

/// 본인이 차단한 사용자 목록 + 해제 화면.
/// Play Store UGC 정책상 사용자가 본인 차단 내역을 직접 확인·해제할 수 있어야 한다.
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  late Future<List<BlockedUser>> _future;
  final Set<String> _unblocking = {};

  @override
  void initState() {
    super.initState();
    _future = ref.read(authRepositoryProvider).getMyBlockedUsers();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ref.read(authRepositoryProvider).getMyBlockedUsers();
    });
    await _future;
  }

  Future<void> _unblock(BlockedUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('차단 해제'),
        content: Text('${u.username} 님의 차단을 해제하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('해제'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _unblocking.add(u.id));
    try {
      await ref.read(authRepositoryProvider).unblockUser(u.id);
      // 피드/DM 즉시 재로딩 — 차단 해제된 유저 콘텐츠 다시 보임
      ref.invalidate(feedPostsProvider);
      ref.invalidate(dmConversationsProvider);
      if (mounted) {
        AppSnackBar.success(context, '차단을 해제했습니다');
        _refresh();
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '해제 실패: $e');
    } finally {
      if (mounted) setState(() => _unblocking.remove(u.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '차단한 사용자',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<BlockedUser>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                const SizedBox(height: 80),
                Center(
                  child: Text('차단 목록을 불러오지 못했습니다',
                      style: TextStyle(color: sub, fontSize: 13)),
                ),
              ]);
            }
            final users = snap.data ?? const [];
            if (users.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 100),
                Center(
                  child: Column(children: [
                    Icon(LucideIcons.ban, size: 48, color: sub),
                    const SizedBox(height: 12),
                    Text('차단한 사용자가 없습니다',
                        style: TextStyle(color: sub, fontSize: 14)),
                  ]),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: users.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark
                    ? const Color(0xFF222222)
                    : const Color(0xFFEEEEEE),
              ),
              itemBuilder: (_, i) {
                final u = users[i];
                final busy = _unblocking.contains(u.id);
                return ListTile(
                  leading: UserAvatar(
                    username: u.username,
                    avatarUrl: u.avatarUrl,
                    radius: 20,
                  ),
                  title: Text(u.username,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('@${u.userKey}',
                      style: TextStyle(color: sub, fontSize: 12)),
                  trailing: TextButton(
                    onPressed: busy ? null : () => _unblock(u),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('해제'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
