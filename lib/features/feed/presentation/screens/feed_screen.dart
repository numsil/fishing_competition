import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/feed_video_player.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/feed_repository.dart';
import '../../data/post_model.dart';
import '../../../../core/widgets/app_snack_bar.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;

    return Scaffold(
      appBar: _FeedAppBar(isDark: isDark, accent: accent),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(feedPostsProvider),
        child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _FavoritesBar(isDark: isDark, accent: accent)),
          SliverToBoxAdapter(
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB),
            ),
          ),
          ref.watch(feedPostsProvider).when(
            data: (posts) {
              if (posts.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text('아직 올라온 조과가 없습니다.\n첫 조과를 자랑해보세요!'),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _InstaPost(
                    post: posts[i],
                    isDark: isDark,
                    accent: accent,
                  ),
                  childCount: posts.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => SliverFillRemaining(
              child: Center(child: Text('피드를 불러오지 못했습니다.')),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// ── AppBar ───────────────────────────────────────────────
class _FeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FeedAppBar({required this.isDark, required this.accent});
  final bool isDark;
  final Color accent;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 44,
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: SvgPicture.asset(
        'assets/images/nakstar.svg',
        height: 26,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(
          Colors.white,
          BlendMode.srcIn,
        ),
      ),
      actions: [
        // 피드 올리기
        GestureDetector(
          onTap: () => context.push(AppRoutes.upload),
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.plus,
              color: isDark ? Colors.black : Colors.white,
              size: 20,
            ),
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(LucideIcons.heart,
              color: isDark ? Colors.white : Colors.black, size: 24),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: () => context.push(AppRoutes.dm),
          icon: Icon(LucideIcons.send,
              color: isDark ? Colors.white : Colors.black, size: 22),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── 즐겨찾기 스토리 바 ──────────────────────────────────
class _FavoritesBar extends StatelessWidget {
  const _FavoritesBar({required this.isDark, required this.accent});
  final bool isDark;
  final Color accent;

  static const _favorites = [
    _Favorite(name: '충주호 리그', type: _FavType.leagueLive, initials: 'L'),
    _Favorite(name: '김민준', type: _FavType.user, initials: '김'),
    _Favorite(name: '소양강 리그', type: _FavType.league, initials: 'L'),
    _Favorite(name: '이서연', type: _FavType.user, initials: '이'),
    _Favorite(name: '박태준', type: _FavType.user, initials: '박'),
    _Favorite(name: '가평 대회', type: _FavType.league, initials: 'L'),
    _Favorite(name: '최현수', type: _FavType.user, initials: '최'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 0, 8),
          child: Row(
            children: [
              Icon(LucideIcons.star, size: 14,
                  color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF888888)),
              const SizedBox(width: 4),
              Text(
                '즐겨찾기',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF888888),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: _favorites.length,
            itemBuilder: (_, i) => _StoryItem(
              fav: _favorites[i],
              isDark: isDark,
              accent: accent,
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

enum _FavType { leagueLive, league, user }

class _Favorite {
  const _Favorite({required this.name, required this.type, required this.initials});
  final String name, initials;
  final _FavType type;
}

class _StoryItem extends StatelessWidget {
  const _StoryItem({required this.fav, required this.isDark, required this.accent});
  final _Favorite fav;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isLive = fav.type == _FavType.leagueLive;
    final isLeague = fav.type == _FavType.league || isLive;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isLive
                      ? const LinearGradient(
                          colors: [AppColors.liveRed, Color(0xFFFF6B6B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : isLeague
                          ? LinearGradient(
                              colors: [accent, accent.withValues(alpha: 0.5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                ),
              ),
              Container(
                width: 59,
                height: 59,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.darkBg : Colors.white,
                ),
              ),
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
                ),
                child: isLeague
                    ? Padding(
                        padding: const EdgeInsets.all(13),
                        child: Icon(
                          LucideIcons.trophy,
                          color: isLive ? AppColors.liveRed : accent,
                          size: 28,
                        ),
                      )
                    : Center(
                        child: Text(
                          fav.initials,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
              ),
              if (isLive)
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.liveRed,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDark ? AppColors.darkBg : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              if (isLeague && !isLive)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(LucideIcons.award, size: 12, color: accent),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 64,
            child: Text(
              fav.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white : const Color(0xFF111111),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 인스타그램 스타일 포스트 ──────────────────────────────
class _InstaPost extends ConsumerStatefulWidget {
  const _InstaPost({required this.post, required this.isDark, required this.accent});
  final Post post;
  final bool isDark;
  final Color accent;

  @override
  ConsumerState<_InstaPost> createState() => _InstaPostState();
}

class _InstaPostState extends ConsumerState<_InstaPost>
    with SingleTickerProviderStateMixin {
  bool _liked = false;
  bool _showHeart = false;
  late AnimationController _heartCtrl;
  late Animation<double> _heartAnim;

  // 댓글 목록 (로컬 상태)
  late List<_Comment> _comments;

  @override
  void initState() {
    super.initState();
    _comments = [];
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heartAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.4), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));
    _heartCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _showHeart = false);
      }
    });
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  void _doubleTapLike() {
    setState(() => _showHeart = true);
    _heartCtrl.forward(from: 0);
    if (!_liked) _toggleLike();
  }

  Future<void> _toggleLike() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final wasLiked = _liked;
    setState(() => _liked = !wasLiked);
    try {
      await ref.read(feedRepositoryProvider).toggleLike(widget.post.id, user.id);
      ref.invalidate(feedPostsProvider);
    } catch (_) {
      if (mounted) setState(() => _liked = wasLiked);
    }
  }

  /// 캡션에서 해시태그(#으로 시작하는 단어)를 제거한 텍스트 반환
  String _stripHashtags(String caption) {
    return caption
        .split(RegExp(r'\s+'))
        .where((w) => !w.startsWith('#'))
        .join(' ')
        .trim();
  }

  /// 캡션에서 해시태그 목록 추출 (예: ['#배스', '#조황'])
  List<String> _extractHashtags(String? caption) {
    if (caption == null || caption.isEmpty) return [];
    return caption
        .split(RegExp(r'\s+'))
        .where((w) => w.startsWith('#') && w.length > 1)
        .toList();
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentSheet(
        post: widget.post,
        isDark: widget.isDark,
        accent: widget.accent,
        comments: _comments,
        onCommentAdded: (c) => setState(() => _comments.add(c)),
      ),
    );
  }

  void _openMoreMenu() {
    final isDark = widget.isDark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MoreMenu(
        isDark: isDark,
        postId: widget.post.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final isDark = widget.isDark;
    final accent = widget.accent;
    final iconColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final bgColor = isDark ? AppColors.darkBg : Colors.white;
    final likeCount = _liked ? p.likesCount + 1 : p.likesCount;
    final commentCount = p.commentsCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 헤더 ──
        Container(
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.push('${AppRoutes.userProfile}/${p.userId}'),
                child: UserAvatar(
                  username: p.username,
                  avatarUrl: p.avatarUrl.isNotEmpty ? p.avatarUrl : null,
                  radius: 16,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('${AppRoutes.userProfile}/${p.userId}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            p.username,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          if (p.isLunker) ...[
                            const SizedBox(width: 4),
                            Icon(LucideIcons.checkCircle, size: 13, color: accent),
                          ],
                        ],
                      ),
                      if (p.location != null)
                        Text(p.location!, style: TextStyle(fontSize: 11, color: subColor)),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: _openMoreMenu,
                icon: Icon(LucideIcons.moreHorizontal, color: iconColor, size: 20),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),

        // ── 어종 정보 칩 ──
        if (p.length != null || p.weight != null || p.catchCount > 1)
          Container(
            color: bgColor,
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
            child: Row(
              children: [
                if (p.length != null) ...[
                  Icon(LucideIcons.ruler, size: 12, color: accent),
                  const SizedBox(width: 4),
                  Text(
                    '${p.length!.toStringAsFixed(1)}cm',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent),
                  ),
                  const SizedBox(width: 12),
                ],
                if (p.weight != null) ...[
                  Icon(LucideIcons.scale, size: 12, color: subColor),
                  const SizedBox(width: 4),
                  Text(
                    '${(p.weight! / 1000).toStringAsFixed(p.weight! >= 1000 ? 2 : 1)}kg',
                    style: TextStyle(fontSize: 13, color: subColor),
                  ),
                  const SizedBox(width: 12),
                ],
                if (p.catchCount > 1) ...[
                  Icon(LucideIcons.fish, size: 12, color: subColor),
                  const SizedBox(width: 4),
                  Text(
                    '${p.catchCount}마리',
                    style: TextStyle(fontSize: 13, color: subColor),
                  ),
                ],
                if (p.isLunker)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.award, size: 10, color: AppColors.gold),
                      const SizedBox(width: 3),
                      const Text('런커', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.gold)),
                    ]),
                  ),
              ],
            ),
          ),

        // ── 미디어 (이미지 or 동영상) ──
        GestureDetector(
          onDoubleTap: p.videoUrl != null ? null : _doubleTapLike,
          child: Container(
            width: double.infinity,
            color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F2),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 이미지 or 동영상 플레이어
                  if (p.videoUrl != null)
                    FeedVideoPlayer(post: p, accent: accent)
                  else
                    Image.network(
                      p.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: accent,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          LucideIcons.image,
                          size: MediaQuery.of(context).size.width * 0.3,
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFA1A1AA),
                        ),
                      ),
                    ),
                  // 리그 태그
                  if (p.leagueId != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.trophy, size: 10, color: AppColors.gold),
                            const SizedBox(width: 5),
                            Text(
                              '리그 게시물',
                              style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 더블탭 하트 (이미지만)
                  if (_showHeart && p.videoUrl == null)
                    Center(
                      child: AnimatedBuilder(
                        animation: _heartAnim,
                        builder: (_, __) => Transform.scale(
                          scale: _heartAnim.value,
                          child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 80),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // ── 액션 버튼 ──
        Container(
          color: bgColor,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: Row(
            children: [
              // 좋아요
              IconButton(
                onPressed: _toggleLike,
                icon: Icon(
                  _liked ? LucideIcons.heart : LucideIcons.heart,
                  color: _liked ? AppColors.error : iconColor,
                  size: 24,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 4),
              // 댓글
              IconButton(
                onPressed: _openComments,
                icon: Icon(LucideIcons.messageCircle, color: iconColor, size: 24),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 4),
              // 링크 복사
              IconButton(
                onPressed: () {
                  final link = 'https://huk.app/p/${p.id}';
                  Clipboard.setData(ClipboardData(text: link));
                                    AppSnackBar.info(context, '링크가 복사되었습니다');
                },
                icon: Icon(LucideIcons.link2, color: iconColor, size: 24),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),

        // ── 좋아요 수 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            '좋아요 $likeCount개',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),

        // ── 캡션 (해시태그 제외한 일반 텍스트만) ──
        if (p.caption != null && p.caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: p.username,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const TextSpan(text: '  '),
                  TextSpan(
                    text: _stripHashtags(p.caption!),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // ── 해시태그 행 ──
        if (_extractHashtags(p.caption).isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 3, 16, 0),
            child: Text(
              _extractHashtags(p.caption).join('  '),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF4A9ECC) : const Color(0xFF00376B),
              ),
            ),
          ),

        // ── 댓글 더보기 ──
        if (commentCount > 0)
          GestureDetector(
            onTap: _openComments,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
              child: Text(
                '댓글 $commentCount개 모두 보기',
                style: TextStyle(fontSize: 13, color: subColor),
              ),
            ),
          ),

        // ── 최신 댓글 1개 미리보기 ──
        if (_comments.isNotEmpty)
          GestureDetector(
            onTap: _openComments,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 3, 16, 0),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _comments.last.user,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: _comments.last.text,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

        // ── 시간 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 5, 16, 12),
          child: Text(
            '${DateTime.now().difference(p.createdAt).inHours}시간 전',
            style: TextStyle(fontSize: 10, color: subColor),
          ),
        ),

        Divider(
          height: 0.5,
          thickness: 0.5,
          color: isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB),
        ),
      ],
    );
  }
}

// ── 더보기 메뉴 (••• 버튼) ────────────────────────────
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.isDark, required this.postId});
  final bool isDark;
  final String postId;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          _MenuItem(
            icon: LucideIcons.link2,
            label: '링크 복사',
            color: textColor,
            onTap: () {
              Navigator.pop(context);
              final link = 'https://huk.app/p/$postId';
              Clipboard.setData(ClipboardData(text: link));
                            AppSnackBar.info(context, '링크가 복사되었습니다');
            },
          ),
          Divider(height: 1, color: divColor),
          _MenuItem(
            icon: LucideIcons.share,
            label: '공유하기',
            color: textColor,
            onTap: () => Navigator.pop(context),
          ),
          Divider(height: 1, color: divColor),
          _MenuItem(
            icon: LucideIcons.userPlus,
            label: '팔로우',
            color: textColor,
            onTap: () => Navigator.pop(context),
          ),
          Divider(height: 1, color: divColor),
          _MenuItem(
            icon: LucideIcons.flag,
            label: '신고하기',
            color: AppColors.error,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── 댓글 시트 ─────────────────────────────────────────
class _CommentSheet extends ConsumerStatefulWidget {
  const _CommentSheet({
    required this.post,
    required this.isDark,
    required this.accent,
    required this.comments,
    required this.onCommentAdded,
  });
  final Post post;
  final bool isDark;
  final Color accent;
  final List<_Comment> comments;
  final ValueChanged<_Comment> onCommentAdded;

  @override
  ConsumerState<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<_CommentSheet> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late List<_Comment> _localComments;
  String? _replyTo;

  @override
  void initState() {
    super.initState();
    _localComments = List.from(widget.comments);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    final username = user?.userMetadata?['username'] as String? ?? '나';

    final comment = _Comment(
      user: username,
      text: _replyTo != null ? '@$_replyTo $text' : text,
      timeAgo: '방금',
      isMe: true,
    );
    setState(() {
      _localComments.add(comment);
      _replyTo = null;
    });
    widget.onCommentAdded(comment);
    _ctrl.clear();

    if (user != null) {
      try {
        await ref.read(feedRepositoryProvider).addComment(
          widget.post.id,
          user.id,
          text,
        );
        ref.invalidate(feedPostsProvider);
      } catch (_) {
        // 로컬 UI는 유지, 서버 저장 실패 무시
      }
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = widget.accent;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final subColor = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // 핸들
              const SizedBox(height: 10),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 제목
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  '댓글',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Divider(height: 1, color: divColor),

              // 댓글 목록
              Expanded(
                child: _localComments.isEmpty
                    ? Center(
                        child: Text(
                          '첫 번째 댓글을 달아보세요',
                          style: TextStyle(color: subColor, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _localComments.length,
                        itemBuilder: (_, i) => _CommentTile(
                          comment: _localComments[i],
                          isDark: isDark,
                          accent: accent,
                          subColor: subColor,
                          onReply: (user) {
                            setState(() => _replyTo = user);
                          },
                        ),
                      ),
              ),

              // 답글 대상 표시
              if (_replyTo != null)
                Container(
                  color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '@$_replyTo 에게 답글 작성 중',
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _replyTo = null),
                        child: Icon(LucideIcons.x, size: 16, color: subColor),
                      ),
                    ],
                  ),
                ),

              Divider(height: 1, color: divColor),

              // 댓글 입력창
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 10,
                    bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
                        ),
                        child: Center(
                          child: Text(
                            '나',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '댓글 달기...',
                            hintStyle: TextStyle(color: subColor, fontSize: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(color: divColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(color: divColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(color: accent),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _submit(),
                          textInputAction: TextInputAction.send,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder(
                        valueListenable: _ctrl,
                        builder: (_, val, __) => GestureDetector(
                          onTap: val.text.trim().isNotEmpty ? _submit : null,
                          child: Text(
                            '게시',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: val.text.trim().isNotEmpty
                                  ? accent
                                  : subColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentTile extends StatefulWidget {
  const _CommentTile({
    required this.comment,
    required this.isDark,
    required this.accent,
    required this.subColor,
    required this.onReply,
  });
  final _Comment comment;
  final bool isDark;
  final Color accent;
  final Color subColor;
  final ValueChanged<String> onReply;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final isDark = widget.isDark;
    final avatarBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아바타
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 32, height: 32,
              color: avatarBg,
              child: Center(
                child: Text(
                  c.user[0],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: c.user,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: c.text,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(c.timeAgo, style: TextStyle(fontSize: 11, color: widget.subColor)),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () => widget.onReply(c.user),
                      child: Text(
                        '답글 달기',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.subColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 댓글 좋아요
          GestureDetector(
            onTap: () => setState(() => _liked = !_liked),
            child: Icon(
              _liked ? LucideIcons.heart : LucideIcons.heart,
              size: 16,
              color: _liked ? AppColors.error : widget.subColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 데이터 모델 ─────────────────────────────────────────
class _Comment {
  const _Comment({
    required this.user,
    required this.text,
    required this.timeAgo,
    this.isMe = false,
  });
  final String user, text, timeAgo;
  final bool isMe;
}
