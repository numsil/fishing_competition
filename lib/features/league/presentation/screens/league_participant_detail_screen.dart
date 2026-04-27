import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/league_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../feed/data/feed_repository.dart';
import '../../../feed/data/post_model.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/extensions/theme_extensions.dart';

// ── 라우터에서 extras로 전달할 args ─────────────────────────
class LeagueParticipantArgs {
  const LeagueParticipantArgs({
    required this.entry,
    required this.rule,
    required this.rank,
  });
  final LeagueRankEntry entry;
  final String rule;
  final int rank;
}

// ── 참가자 상세 화면 ─────────────────────────────────────────
class LeagueParticipantDetailScreen extends ConsumerWidget {
  const LeagueParticipantDetailScreen({
    super.key,
    required this.leagueId,
    required this.userId,
    required this.entry,
    required this.rule,
    required this.rank,
  });

  final String leagueId;
  final String userId;
  final LeagueRankEntry entry;
  final String rule;
  final int rank;

  Color _rankColor(bool isDark) {
    if (rank == 1) return AppColors.gold;
    if (rank == 2) return AppColors.silver;
    if (rank == 3) return AppColors.bronze;
    return isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
  }

  String get _mainValue {
    switch (rule) {
      case '마릿수':
        return '${entry.totalCount}마리';
      case '무게':
        return entry.totalLength > 0
            ? '${entry.totalLength.toStringAsFixed(0)}g'
            : '-';
      case '합산 길이':
        return entry.totalLength > 0
            ? '${entry.totalLength.toStringAsFixed(1)}cm'
            : '-';
      default: // 최대어
        return entry.bestLength != null ? '${entry.bestLength}cm' : '-';
    }
  }

  String get _mainLabel {
    switch (rule) {
      case '마릿수': return '총 마릿수';
      case '무게': return '무게 합산';
      case '합산 길이': return '합산 길이';
      default: return '최대어';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(leagueUserPostsProvider((leagueId, userId)));
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final isMyPost = currentUserId != null && currentUserId == userId;

    return Scaffold(
      appBar: AppBar(
        title: Text('${entry.username}의 조과'),
        centerTitle: true,
      ),
      body: postsAsync.when(
        data: (posts) => CustomScrollView(
          slivers: [
            // ── 유저 헤더 ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        UserAvatar(
                          username: entry.username,
                          avatarUrl: entry.avatarUrl,
                          radius: 36,
                          isDark: context.isDark,
                        ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: _rankColor(context.isDark),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.isDark ? AppColors.darkBg : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$rank',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          entry.username,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        if (entry.isLunker) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '런커',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── 스탯 카드 ────────────────────────
                    Row(
                      children: [
                        _StatCard(
                          label: _mainLabel,
                          value: _mainValue,
                          accent: context.accentColor,
                          isDark: context.isDark,
                        ),
                        const SizedBox(width: 8),
                        _StatCard(
                          label: '마릿수',
                          value: '${entry.totalCount}마리',
                          accent: context.accentColor,
                          isDark: context.isDark,
                        ),
                        if (entry.bestLength != null) ...[
                          const SizedBox(width: 8),
                          _StatCard(
                            label: rule == '무게' ? '최대 무게' : '최대어',
                            value: rule == '무게'
                                ? '${entry.bestLength!.toStringAsFixed(0)}g'
                                : '${entry.bestLength}cm',
                            accent: context.accentColor,
                            isDark: context.isDark,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── 섹션 타이틀 ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(children: [
                  Icon(LucideIcons.camera, size: 15, color: context.accentColor),
                  const SizedBox(width: 6),
                  Text(
                    '등록 조과 (${posts.length}건)',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ]),
              ),
            ),

            // ── 조과 목록 ─────────────────────────────────
            if (posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.fish,
                          size: 48,
                          color: context.isDark
                              ? AppColors.darkTextSub
                              : AppColors.lightTextSub),
                      const SizedBox(height: 12),
                      Text(
                        '등록된 조과가 없습니다',
                        style: TextStyle(
                            color: context.isDark
                                ? AppColors.darkTextSub
                                : AppColors.lightTextSub),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _CatchCard(
                      post: posts[index],
                      isDark: context.isDark,
                      accent: context.accentColor,
                      onTap: () => context.push('/post', extra: posts[index]),
                      isMyPost: isMyPost,
                      onShareToFeed: isMyPost ? () async {
                        try {
                          await ref.read(feedRepositoryProvider).sharePostToFeed(posts[index]);
                          ref.invalidate(feedPostsProvider);
                          if (context.mounted) {
                                                        AppSnackBar.success(context, '내 피드에 공유되었습니다.');
                          }
                        } catch (e) {
                          if (context.mounted) {
                                                        AppSnackBar.error(context, '공유 실패: $e');
                          }
                        }
                      } : null,
                    ),
                    childCount: posts.length,
                  ),
                ),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 실패: $e')),
      ),
    );
  }
}

// ── 스탯 카드 ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.isDark,
  });
  final String label, value;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: accent)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextSub
                      : AppColors.lightTextSub)),
        ]),
      ),
    );
  }
}

// ── 조과 카드 ─────────────────────────────────────────────
class _CatchCard extends StatelessWidget {
  const _CatchCard({
    required this.post,
    required this.isDark,
    required this.accent,
    required this.onTap,
    this.isMyPost = false,
    this.onShareToFeed,
  });
  final Post post;
  final bool isDark;
  final Color accent;
  final VoidCallback onTap;
  final bool isMyPost;
  final VoidCallback? onShareToFeed;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        radius: 14,
        borderColor: divColor,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 사진 ───────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  post.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: isDark
                        ? AppColors.darkSurface2
                        : AppColors.lightDivider,
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            // ── 조과 정보 ──────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(LucideIcons.fish, size: 13, color: accent),
                        const SizedBox(width: 5),
                        Text(
                          post.fishType,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent),
                        ),
                        if (post.isLunker) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('런커',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black)),
                          ),
                        ],
                      ]),
                      Text(
                        DateFormat('MM.dd HH:mm')
                            .format(post.createdAt.toLocal()),
                        style: TextStyle(fontSize: 12, color: sub),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ── 측정 수치 ─────────────────────────
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      if (post.length != null)
                        _MeasureStat(
                          icon: LucideIcons.ruler,
                          value: '${post.length!.toStringAsFixed(1)}cm',
                          sub: sub,
                        ),
                      if (post.weight != null)
                        _MeasureStat(
                          icon: LucideIcons.scale,
                          value: '${post.weight!.toStringAsFixed(0)}g',
                          sub: sub,
                        ),
                      if (post.lureType != null && post.lureType!.isNotEmpty)
                        _MeasureStat(
                          icon: LucideIcons.zap,
                          value: post.lureType!,
                          sub: sub,
                        ),
                      if (post.location != null && post.location!.isNotEmpty)
                        _MeasureStat(
                          icon: LucideIcons.mapPin,
                          value: post.location!,
                          sub: sub,
                        ),
                    ],
                  ),
                  if (post.caption != null && post.caption!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      post.caption!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: sub, height: 1.4),
                    ),
                  ],
                  if (isMyPost && onShareToFeed != null) ...[
                    const SizedBox(height: 10),
                    Divider(height: 1, color: divColor),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onShareToFeed,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.share2, size: 13, color: accent),
                          const SizedBox(width: 5),
                          Text(
                            '내 피드에 공유',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 측정 수치 위젯 ────────────────────────────────────────
class _MeasureStat extends StatelessWidget {
  const _MeasureStat(
      {required this.icon, required this.value, required this.sub});
  final IconData icon;
  final String value;
  final Color sub;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: sub),
      const SizedBox(width: 4),
      Text(value, style: TextStyle(fontSize: 12, color: sub)),
    ]);
  }
}
