import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/address_utils.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/league_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../feed/data/feed_repository.dart';
import '../../../feed/data/post_model.dart';
import '../../../feed/presentation/widgets/fullscreen_image_viewer.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/utils/banned_error_handler.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/slide_to_confirm.dart';
import '../../../../core/widgets/stat_widgets.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../../core/widgets/menu_item.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/utils/image_downloader.dart';
import '../../../my_league/data/my_league_repository.dart';
import '../../../ranking/data/score_cache_invalidation.dart';

// ── 라우터에서 extras로 전달할 args ─────────────────────────
class LeagueParticipantArgs {
  const LeagueParticipantArgs({
    required this.entry,
    required this.rule,
    required this.catchLimit,
    required this.rank,
  });
  final LeagueRankEntry entry;
  final String rule;
  final int catchLimit;
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
    required this.catchLimit,
    required this.rank,
  });

  final String leagueId;
  final String userId;
  final LeagueRankEntry entry;
  final String rule;
  final int catchLimit;
  final int rank;

  Color _rankColor(bool isDark) {
    if (rank == 1) return AppColors.gold;
    if (rank == 2) return AppColors.silver;
    if (rank == 3) return AppColors.bronze;
    return isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
  }

  String get _mainValue {
    if (rule == '마릿수') return '${entry.totalCount}마리';
    if (rule == '무게') {
      return entry.totalLength > 0
          ? '${entry.totalLength.toStringAsFixed(0)}g'
          : '-';
    }
    // 길이 계열: catch_limit=1이면 최대어, 초과면 합산
    if (catchLimit == 1) {
      return entry.bestLength != null
          ? '${entry.bestLength!.toStringAsFixed(1)}cm'
          : '-';
    }
    return entry.totalLength > 0
        ? '${entry.totalLength.toStringAsFixed(1)}cm'
        : '-';
  }

  String get _mainLabel {
    if (rule == '마릿수') return '총 마릿수';
    if (rule == '무게') return catchLimit == 1 ? '최대 무게' : '무게 합산';
    if (catchLimit == 1) return '최대어';
    if (catchLimit == 0) return '전체 합산';
    return '합산($catchLimit마리)';
  }

  // 우측 참고 카드: 합산 대회에서 최대어 단독 수치, 마릿수 대회에서도 표시
  bool get _showBestCard =>
      entry.bestLength != null && (catchLimit > 1 || rule == '마릿수');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(leagueUserPostsProvider(leagueId, userId));
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
                        StatBoxTinted(
                          value: _mainValue,
                          label: _mainLabel,
                          isDark: context.isDark,
                          accent: context.accentColor,
                        ),
                        const SizedBox(width: 8),
                        StatBoxTinted(
                          value: '${entry.totalCount}마리',
                          label: '마릿수',
                          isDark: context.isDark,
                          accent: context.accentColor,
                        ),
                        if (_showBestCard) ...[
                          const SizedBox(width: 8),
                          StatBoxTinted(
                            value: rule == '무게'
                                ? '${entry.bestLength!.toStringAsFixed(0)}g'
                                : '${entry.bestLength!.toStringAsFixed(1)}cm',
                            label: rule == '무게' ? '최대 무게' : '최대어',
                            isDark: context.isDark,
                            accent: context.accentColor,
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
                    (context, index) {
                      final post = posts[index];

                      void showActions() {
                        final isDark = context.isDark;
                        final accent = context.accentColor;

                        showAppActionSheet(
                          context,
                          items: [
                            AppMenuItem(
                              icon: LucideIcons.pencil,
                              label: '수정하기',
                              onTap: () {
                                Navigator.pop(context);
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                  ),
                                  builder: (_) => _CatchMemoEditSheet(
                                    post: post,
                                    isDark: isDark,
                                    accent: accent,
                                    onSaved: () {
                                      ref.invalidate(leagueUserPostsProvider(leagueId, userId));
                                      ref.invalidate(leagueRankingProvider(leagueId));
                                      ref.invalidate(feedPostsProvider);
                                    },
                                  ),
                                );
                              },
                            ),
                            AppMenuItem(
                              icon: LucideIcons.share2,
                              label: '피드에 공유',
                              onTap: () async {
                                Navigator.pop(context);
                                try {
                                  await ref.read(feedRepositoryProvider).sharePostToFeed(post);
                                  ref.invalidate(feedPostsProvider);
                                  if (context.mounted) AppSnackBar.success(context, '내 피드에 공유되었습니다.');
                                } catch (e) {
                                  if (context.mounted) AppSnackBar.error(context, '공유 실패: $e');
                                }
                              },
                            ),
                            AppMenuItem(
                              icon: LucideIcons.download,
                              label: '사진 저장',
                              onTap: () async {
                                Navigator.pop(context);
                                try {
                                  await downloadImageToGallery(post.imageUrl);
                                  if (context.mounted) AppSnackBar.success(context, '갤러리에 저장되었습니다');
                                } catch (e) {
                                  if (context.mounted) AppSnackBar.error(context, '저장 실패: $e');
                                }
                              },
                            ),
                            const AppMenuDivider(),
                            AppMenuItem(
                              icon: LucideIcons.trash2,
                              label: '삭제',
                              destructive: true,
                              onTap: () async {
                                Navigator.pop(context);
                                await showDeleteConfirmSheet(
                                  context,
                                  title: '조과 삭제',
                                  content: '이 조과를 삭제하시겠습니까?\n삭제된 조과는 복구할 수 없습니다.',
                                  onConfirmed: () async {
                                    try {
                                      await ref.read(feedRepositoryProvider).deletePost(post.id);
                                      ref.invalidate(leagueUserPostsProvider(leagueId, userId));
                                      ref.invalidate(leagueRankingProvider(leagueId));
                                      ref.invalidate(feedPostsProvider);
                                      ref.invalidate(mySeasonStatsProvider);
                                      invalidateScoreCaches(ref);
                                    } catch (e) {
                                      if (context.mounted) AppSnackBar.error(context, '삭제 실패: $e');
                                    }
                                  },
                                );
                              },
                            ),
                          ],
                        );
                      }

                      return _CatchCard(
                        post: post,
                        isDark: context.isDark,
                        accent: context.accentColor,
                        isMyPost: isMyPost,
                        onMoreTap: isMyPost ? showActions : null,
                      );
                    },
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

// ── 조과 카드 ─────────────────────────────────────────────
class _CatchCard extends StatelessWidget {
  const _CatchCard({
    required this.post,
    required this.isDark,
    required this.accent,
    this.isMyPost = false,
    this.onMoreTap,
  });
  final Post post;
  final bool isDark;
  final Color accent;
  final bool isMyPost;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        radius: 14,
        borderColor: divColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 사진 ───────────────────────────────────
            Stack(
              children: [
                GestureDetector(
                  onTap: post.imageUrl.isEmpty
                      ? null
                      : () => FullscreenImageViewer.open(
                            context,
                            urls: [post.imageUrl],
                            initialIndex: 0,
                          ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                    child: AspectRatio(
                      aspectRatio: (post.aspectRatio ?? (4 / 3)).clamp(0.8, 1.91),
                      child: CachedNetworkImage(
                        imageUrl: post.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
                          child: const Center(
                            child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (isMyPost && post.reviewStatus == 'held')
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('보류',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  )
                else if (isMyPost && post.reviewStatus == 'rejected')
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('거부',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
                // ── ... 메뉴 버튼 ──
                if (isMyPost)
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: onMoreTap,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
              ],
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
                        Text(post.fishType,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
                        if (post.isLunker) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4)),
                            child: const Text('런커',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black)),
                          ),
                        ],
                        if (post.reviewStatus == 'approved') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(LucideIcons.badgeCheck, size: 10, color: Colors.green[700]),
                              const SizedBox(width: 3),
                              Text('인증',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.green[700])),
                            ]),
                          ),
                        ] else if (post.reviewStatus == 'rejected') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(LucideIcons.shieldOff, size: 10, color: AppColors.error),
                              const SizedBox(width: 3),
                              Text('거부',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.error)),
                            ]),
                          ),
                        ],
                      ]),
                      Text(DateFormat('MM.dd HH:mm').format(post.createdAt.toLocal()),
                          style: TextStyle(fontSize: 12, color: sub)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 14, runSpacing: 4, children: [
                    if (post.length != null)
                      _MeasureStat(icon: LucideIcons.ruler, value: '${post.length!.toStringAsFixed(1)}cm', sub: sub),
                    if (post.weight != null)
                      _MeasureStat(icon: LucideIcons.scale, value: '${post.weight!.toStringAsFixed(0)}g', sub: sub),
                    if (post.lureType != null && post.lureType!.isNotEmpty)
                      _MeasureStat(icon: LucideIcons.zap, value: post.lureType!, sub: sub),
                    if (post.location != null && post.location!.isNotEmpty)
                      _MeasureStat(icon: LucideIcons.mapPin, value: dedupeAddress(post.location!), sub: sub),
                  ]),
                  if (post.caption != null && post.caption!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(post.caption!, style: TextStyle(fontSize: 13, color: sub, height: 1.4)),
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

// ── 메모 수정 바텀시트 ────────────────────────────────────
class _CatchMemoEditSheet extends ConsumerStatefulWidget {
  const _CatchMemoEditSheet({
    required this.post,
    required this.isDark,
    required this.accent,
    required this.onSaved,
  });
  final Post post;
  final bool isDark;
  final Color accent;
  final VoidCallback onSaved;

  @override
  ConsumerState<_CatchMemoEditSheet> createState() => _CatchMemoEditSheetState();
}

class _CatchMemoEditSheetState extends ConsumerState<_CatchMemoEditSheet> {
  late final TextEditingController _captionCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _captionCtrl = TextEditingController(text: widget.post.caption ?? '');
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(feedRepositoryProvider).updatePostMeta(
        postId: widget.post.id,
        caption: _captionCtrl.text,
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (await handleIfBanned(e)) return;
      if (mounted) AppSnackBar.error(context, '수정 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = widget.accent;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('수정하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black)),
              const Spacer(),
              _saving
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                  : TextButton(
                      onPressed: _save,
                      child: Text('저장', style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
                    ),
            ]),
            Divider(height: 24, color: divColor),
            Text('메모', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sub)),
            const SizedBox(height: 8),
            TextField(
              controller: _captionCtrl,
              maxLines: 4,
              autofocus: true,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: '조과 상황, 사용한 루어 등을 자유롭게 입력하세요',
                hintStyle: TextStyle(color: sub, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: divColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: divColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accent)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
