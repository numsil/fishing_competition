import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/follow_repository.dart';

enum FollowListType { followers, following }

class FollowListScreen extends ConsumerStatefulWidget {
  const FollowListScreen({
    super.key,
    required this.userId,
    required this.type,
    this.username,
  });

  final String userId;
  final FollowListType type;
  final String? username;

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> {
  static const int _pageSize = 50;

  final ScrollController _scroll = ScrollController();
  final List<FollowUser> _items = [];
  final Set<String> _toggling = {};

  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirst();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<List<FollowUser>> _fetch(int offset) {
    final repo = ref.read(followRepositoryProvider);
    return widget.type == FollowListType.followers
        ? repo.getFollowers(widget.userId, limit: _pageSize, offset: offset)
        : repo.getFollowing(widget.userId, limit: _pageSize, offset: offset);
  }

  Future<void> _loadFirst() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      final batch = await _fetch(0);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(batch);
        _hasMore = batch.length == _pageSize;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _initialLoading) return;
    setState(() => _loadingMore = true);
    try {
      final batch = await _fetch(_items.length);
      if (!mounted) return;
      setState(() {
        _items.addAll(batch);
        _hasMore = batch.length == _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      AppSnackBar.error(context, '추가 로딩에 실패했습니다');
    }
  }

  Future<void> _toggle(FollowUser user, int index) async {
    if (_toggling.contains(user.userId)) return;
    final repo = ref.read(followRepositoryProvider);

    if (user.isFollowing) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('언팔로우'),
          content: Text('${user.username}님을 언팔로우 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('언팔로우'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _toggling.add(user.userId));
    try {
      if (user.isFollowing) {
        await repo.unfollow(user.userId);
      } else {
        await repo.follow(user.userId);
      }
      // 카운트 갱신을 위해 프로필 캐시 invalidate
      ref.invalidate(userProfileProvider(widget.userId));
      ref.invalidate(userProfileProvider(user.userId));
      ref.invalidate(myFollowingsForFeedProvider);
      final me = ref.read(currentUserProvider)?.id;
      if (me != null) ref.invalidate(myProfileProvider);

      // 행만 즉시 토글 (전체 리스트 재호출 없이)
      if (!mounted) return;
      setState(() {
        if (index >= 0 && index < _items.length) {
          _items[index] = _items[index].copyWith(isFollowing: !user.isFollowing);
        }
      });
    } catch (_) {
      if (mounted) AppSnackBar.error(context, '요청에 실패했습니다');
    } finally {
      if (mounted) setState(() => _toggling.remove(user.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final sub = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final me = ref.watch(currentUserProvider)?.id;

    final title =
        widget.type == FollowListType.followers ? '팔로워' : '팔로잉';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            if (widget.username != null)
              Text(
                '@${widget.username}',
                style: TextStyle(fontSize: 11, color: sub),
              ),
          ],
        ),
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _buildBody(isDark, sub, me),
    );
  }

  Widget _buildBody(bool isDark, Color sub, String? me) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState(
        icon: LucideIcons.alertCircle,
        message: '불러오지 못했습니다',
        subColor: sub,
      );
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: LucideIcons.users,
        message: widget.type == FollowListType.followers
            ? '아직 팔로워가 없어요'
            : '팔로우한 사용자가 없어요',
        subColor: sub,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final u = _items[i];
          final isMe = me == u.userId;
          final loading = _toggling.contains(u.userId);
          return InkWell(
            onTap: () => context.push('${AppRoutes.userProfile}/${u.userId}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  UserAvatar(
                    username: u.username,
                    avatarUrl: u.avatarUrl,
                    radius: 22,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.username,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${u.userKey}',
                          style: TextStyle(fontSize: 12, color: sub),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!isMe) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 32,
                      child: u.isFollowing
                          ? OutlinedButton(
                              onPressed:
                                  loading ? null : () => _toggle(u, i),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                side: BorderSide(
                                    color: isDark
                                        ? AppColors.darkSurface2
                                        : AppColors.lightDivider),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: loading
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: context.accentColor,
                                      ),
                                    )
                                  : Text(
                                      '팔로잉',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black),
                                    ),
                            )
                          : FilledButton(
                              onPressed:
                                  loading ? null : () => _toggle(u, i),
                              style: FilledButton.styleFrom(
                                backgroundColor: context.accentColor,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: loading
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: isDark
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                    )
                                  : Text(
                                      '팔로우',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.black
                                              : Colors.white),
                                    ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
